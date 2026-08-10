// Supabase Edge Function: send-social-push
//
// Sends a push notification (FCM HTTP v1 API) for a social-feed event —
// someone liked your post, someone followed you, or someone you follow
// published a new trip. Invoked directly by the client right after the
// underlying insert succeeds (SocialRemoteDataSourceImpl.toggleLike /
// toggleFollow / publishItinerary) — best-effort, the like/follow/post
// itself has already landed regardless of whether this succeeds. Mirrors
// send-message-push's structure; see that function for the fuller
// Android-data-only-vs-iOS-alert rationale, unrepeated here.
//
// The data payload's `kind: 'social'` + `actorId` fields let the shared
// client-side handler (lib/core/notifications/push_message_handler.dart)
// tell this apart from send-message-push's chat payloads and route a tap to
// `/u/:actorId` instead of a trip's chat.
//
// This function does NOT read from `public.notifications` — it re-derives
// the recipient(s) itself from the same source tables the DB triggers in
// stage37_social_notifications.sql read (itinerary_posts/post_likes/
// follows), the same "never trust the client, re-derive server-side"
// posture send-message-push already uses for its recipient list.
//
// Required secret (set once, shared with send-message-push):
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY='{"type":"service_account",...}'
//
// Deploy:
//   supabase functions deploy send-social-push

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? 'https://kumo.app',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ServiceAccount {
  project_id: string
  client_email: string
  private_key: string
}

interface Recipient {
  id: string
  title: string
  body: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS })
  }

  try {
    // ── Auth ────────────────────────────────────────────────────────────────
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return json({ error: 'Missing Authorization header' }, 401)
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } },
    )
    const { data: { user }, error: authErr } = await supabase.auth.getUser(
      authHeader.replace('Bearer ', ''),
    )
    if (authErr || !user) {
      return json({ error: 'Unauthorized' }, 401)
    }

    // ── Parse request ─────────────────────────────────────────────────────
    const body = await req.json() as {
      type?: 'like' | 'follow' | 'new_post' | 'comment'
      post_id?: string
      followee_id?: string
    }
    const validTypes = ['like', 'follow', 'new_post', 'comment']
    if (!body.type || !validTypes.includes(body.type)) {
      return json({ error: `type must be one of: ${validTypes.join(', ')}` }, 400)
    }

    const { data: actorProfile } = await supabase
      .from('profiles')
      .select('display_name')
      .eq('id', user.id)
      .single()
    const actorName = actorProfile?.display_name || 'Someone'

    // ── Resolve recipient(s), re-deriving everything server-side ───────────
    let recipients: Recipient[] = []

    if (body.type === 'like') {
      if (!body.post_id) {
        return json({ error: 'post_id is required' }, 400)
      }
      // Confirms the caller actually liked this post (not just claiming to)
      // — same "caller must be the real actor" check send-message-push does
      // against message.sender_id.
      const { data: like } = await supabase
        .from('post_likes')
        .select('post_id')
        .eq('post_id', body.post_id)
        .eq('user_id', user.id)
        .maybeSingle()
      if (!like) {
        return json({ error: 'Forbidden' }, 403)
      }
      const { data: post } = await supabase
        .from('itinerary_posts')
        .select('author_id, title')
        .eq('id', body.post_id)
        .single()
      if (post && post.author_id !== user.id) {
        recipients = [{
          id: post.author_id,
          title: `${actorName} liked your trip`,
          body: post.title ?? '',
        }]
      }
    } else if (body.type === 'follow') {
      if (!body.followee_id) {
        return json({ error: 'followee_id is required' }, 400)
      }
      const { data: follow } = await supabase
        .from('follows')
        .select('followee_id')
        .eq('follower_id', user.id)
        .eq('followee_id', body.followee_id)
        .maybeSingle()
      if (!follow) {
        return json({ error: 'Forbidden' }, 403)
      }
      recipients = [{
        id: body.followee_id,
        title: `${actorName} started following you`,
        body: 'Tap to view their profile.',
      }]
    } else if (body.type === 'new_post') {
      if (!body.post_id) {
        return json({ error: 'post_id is required' }, 400)
      }
      const { data: post } = await supabase
        .from('itinerary_posts')
        .select('author_id, title')
        .eq('id', body.post_id)
        .single()
      if (!post || post.author_id !== user.id) {
        return json({ error: 'Forbidden' }, 403)
      }
      // Capped at 1000 most-recently-followed, same bound the DB trigger
      // (notify_on_new_post) and fetchFeed's follower-list read both use —
      // see stage37_social_notifications.sql's comment for why.
      const { data: followers } = await supabase
        .from('follows')
        .select('follower_id')
        .eq('followee_id', user.id)
        .order('created_at', { ascending: false })
        .limit(1000)
      recipients = (followers ?? []).map((f) => ({
        id: f.follower_id as string,
        title: `${actorName} published a new trip`,
        body: post.title ?? '',
      }))
    } else {
      // comment
      if (!body.post_id) {
        return json({ error: 'post_id is required' }, 400)
      }
      // Confirms the caller actually left a comment on this post recently —
      // same "caller must be the real actor" posture as the like branch
      // above. Scoped to the last minute rather than an exact row match,
      // since (unlike post_likes) there's no natural unique key to look up
      // a specific comment by without the client passing its id.
      const { data: comment } = await supabase
        .from('post_comments')
        .select('post_id')
        .eq('post_id', body.post_id)
        .eq('author_id', user.id)
        .gte('created_at', new Date(Date.now() - 60_000).toISOString())
        .order('created_at', { ascending: false })
        .limit(1)
        .maybeSingle()
      if (!comment) {
        return json({ error: 'Forbidden' }, 403)
      }
      const { data: post } = await supabase
        .from('itinerary_posts')
        .select('author_id, title')
        .eq('id', body.post_id)
        .single()
      if (post && post.author_id !== user.id) {
        recipients = [{
          id: post.author_id,
          title: `${actorName} commented on your trip`,
          body: post.title ?? '',
        }]
      }
    }

    if (recipients.length === 0) {
      return json({ sent: 0, recipients: 0 })
    }

    // ── Filter by the social_activity push preference (default enabled) ────
    const recipientIds = recipients.map((r) => r.id)
    const { data: prefs } = await supabase
      .from('notification_preferences')
      .select('user_id, enabled')
      .in('user_id', recipientIds)
      .eq('channel', 'push')
      .eq('category', 'social_activity')
    const disabled = new Set(
      (prefs ?? []).filter((p) => !p.enabled).map((p) => p.user_id),
    )
    const enabledRecipients = recipients.filter((r) => !disabled.has(r.id))
    if (enabledRecipients.length === 0) {
      return json({ sent: 0, recipients: 0 })
    }

    // ── Device tokens (Android + iOS) ─────────────────────────────────────
    const { data: tokenRows } = await supabase
      .from('push_tokens')
      .select('user_id, token, platform')
      .in('user_id', enabledRecipients.map((r) => r.id))
      .in('platform', ['android', 'ios'])
    if (!tokenRows || tokenRows.length === 0) {
      return json({ sent: 0, recipients: enabledRecipients.length })
    }
    const recipientById = new Map(enabledRecipients.map((r) => [r.id, r]))

    // ── FCM send ──────────────────────────────────────────────────────────
    const serviceAccount = JSON.parse(
      Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY') ?? '{}',
    ) as ServiceAccount
    if (!serviceAccount.project_id) {
      return json({ error: 'FIREBASE_SERVICE_ACCOUNT_KEY not configured' }, 500)
    }
    const accessToken = await getGoogleAccessToken(serviceAccount)

    const staleTokens: string[] = []
    let sent = 0

    await Promise.all(tokenRows.map(async (row) => {
      const recipient = recipientById.get(row.user_id)
      if (!recipient) {
        return
      }
      const data = {
        kind: 'social',
        actorId: user.id,
        title: recipient.title,
        body: recipient.body,
      }
      const fcmMessage = row.platform === 'ios'
        ? {
          token: row.token,
          data,
          apns: {
            headers: { 'apns-priority': '10' },
            payload: {
              aps: {
                alert: { title: recipient.title, body: recipient.body },
                sound: 'default',
              },
            },
          },
        }
        : {
          token: row.token,
          data,
          android: { priority: 'high' },
        }

      const res = await fetch(
        `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({ message: fcmMessage }),
        },
      )
      if (res.ok) {
        sent += 1
        return
      }
      const errBody = await res.json().catch(() => null)
      const status = errBody?.error?.status
      if (status === 'UNREGISTERED' || status === 'NOT_FOUND' || status === 'INVALID_ARGUMENT') {
        staleTokens.push(row.token)
      }
    }))

    if (staleTokens.length > 0) {
      await supabase.from('push_tokens').delete().in('token', staleTokens)
    }

    return json({ sent, recipients: enabledRecipients.length })
  } catch (e) {
    console.error('Unexpected error:', e)
    return json({ error: 'Internal server error' }, 500)
  }
})

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

// ── Google service-account OAuth2 (RS256-signed JWT bearer assertion) ───────
// Identical to send-message-push's copy — kept duplicated rather than
// shared, matching how this repo's other Edge Functions are each
// self-contained with no shared-code directory between them.

async function getGoogleAccessToken(account: ServiceAccount): Promise<string> {
  const header = { alg: 'RS256', typ: 'JWT' }
  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: account.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }

  const encode = (obj: unknown) =>
    base64url(new TextEncoder().encode(JSON.stringify(obj)))
  const unsigned = `${encode(header)}.${encode(claims)}`

  const key = await importPrivateKey(account.private_key)
  const signature = await crypto.subtle.sign(
    { name: 'RSASSA-PKCS1-v1_5' },
    key,
    new TextEncoder().encode(unsigned),
  )
  const jwt = `${unsigned}.${base64url(new Uint8Array(signature))}`

  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  })
  if (!res.ok) {
    throw new Error(`Google token exchange failed: ${await res.text()}`)
  }
  const { access_token } = await res.json() as { access_token: string }
  return access_token
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const contents = pem
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  const der = Uint8Array.from(atob(contents), (c) => c.charCodeAt(0))
  return crypto.subtle.importKey(
    'pkcs8',
    der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

function base64url(bytes: Uint8Array): string {
  let str = ''
  for (const b of bytes) {
    str += String.fromCharCode(b)
  }
  return btoa(str).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}
