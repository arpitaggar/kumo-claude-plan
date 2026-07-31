// Supabase Edge Function: send-message-push
//
// Sends a push notification (FCM HTTP v1 API) to every other member of a
// trip when a chat message is sent. Invoked directly by the client right
// after a successful `messages` insert (see
// ChatRemoteDataSourceImpl.sendMessage) — best-effort, the message itself
// has already landed regardless of whether this succeeds.
//
// Android tokens get a data-only payload (no top-level FCM "notification"
// field) so the Flutter app has full, consistent control over how the
// notification is displayed via flutter_local_notifications — see
// lib/core/notifications/push_message_handler.dart.
//
// iOS tokens get a real `apns.payload.aps.alert` block instead. Apple gives
// silent/data-only background pushes no delivery guarantee — in particular
// they are not delivered once the user force-quits the app — so relying on
// the app to render its own notification the way Android does would mean
// iOS chat pushes silently stop working after a force-quit. An alert
// payload is displayed by the OS directly and doesn't have that problem.
// Tap handling for it lives in lib/core/notifications/push_message_handler.dart
// (handleIosPushTap) since flutter_local_notifications is never involved.
//
// Required secret (set once):
//   supabase secrets set FIREBASE_SERVICE_ACCOUNT_KEY='{"type":"service_account",...}'
//
// Deploy:
//   supabase functions deploy send-message-push

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ServiceAccount {
  project_id: string
  client_email: string
  private_key: string
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

    // ── Parse request & load the message ─────────────────────────────────────
    const { message_id } = await req.json() as { message_id: string }
    if (!message_id) {
      return json({ error: 'message_id is required' }, 400)
    }

    const { data: message, error: msgErr } = await supabase
      .from('messages')
      .select('id, itinerary_id, sender_id, sender_name, content')
      .eq('id', message_id)
      .single()
    if (msgErr || !message) {
      return json({ error: 'Message not found' }, 404)
    }
    // The caller must be the message's own sender — prevents spoofing a push
    // on someone else's behalf.
    if (message.sender_id !== user.id) {
      return json({ error: 'Forbidden' }, 403)
    }

    const { data: itinerary, error: itinErr } = await supabase
      .from('itineraries')
      .select('title, owner_id, members')
      .eq('id', message.itinerary_id)
      .single()
    if (itinErr || !itinerary) {
      return json({ error: 'Itinerary not found' }, 404)
    }

    const { data: attachments } = await supabase
      .from('message_attachments')
      .select('kind')
      .eq('message_id', message_id)

    // ── Recipients: itinerary owner + members, excluding the sender ─────────
    // The members JSONB array mixes key casing depending on how the entry was
    // written: the `handle_new_user` trigger uses `userId`, the Flutter
    // client's invite flow uses `user_id` (see stage11/stage13 migrations) —
    // both must be checked or client-invited members silently get no push.
    const memberIds: string[] = (itinerary.members ?? [])
      .map((m: { userId?: string; user_id?: string }) => m.userId ?? m.user_id)
      .filter((id: string | undefined): id is string => !!id)
    const recipientIds = [...new Set([itinerary.owner_id, ...memberIds])]
      .filter((id) => id !== message.sender_id)

    if (recipientIds.length === 0) {
      return json({ sent: 0, recipients: 0 })
    }

    // ── Filter by the chat_messages push preference (default enabled) ───────
    const { data: prefs } = await supabase
      .from('notification_preferences')
      .select('user_id, enabled')
      .in('user_id', recipientIds)
      .eq('channel', 'push')
      .eq('category', 'chat_messages')
    const disabled = new Set(
      (prefs ?? []).filter((p) => !p.enabled).map((p) => p.user_id),
    )
    const enabledRecipients = recipientIds.filter((id) => !disabled.has(id))
    if (enabledRecipients.length === 0) {
      return json({ sent: 0, recipients: 0 })
    }

    // ── Per-recipient preview preference (default shown) ─────────────────────
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, push_message_preview_enabled')
      .in('id', enabledRecipients)
    const previewByUser = new Map(
      (profiles ?? []).map((p) => [
        p.id,
        (p.push_message_preview_enabled as boolean | null) ?? true,
      ]),
    )

    // ── Device tokens (Android + iOS) ─────────────────────────────────────────
    const { data: tokenRows } = await supabase
      .from('push_tokens')
      .select('user_id, token, platform')
      .in('user_id', enabledRecipients)
      .in('platform', ['android', 'ios'])
    if (!tokenRows || tokenRows.length === 0) {
      return json({ sent: 0, recipients: enabledRecipients.length })
    }

    // ── Build the notification body once per preview setting ────────────────
    const hasImage = (attachments ?? []).some((a) => a.kind === 'image')
    const hasFile = (attachments ?? []).some((a) => a.kind === 'file')
    const previewBody = message.content?.trim()
      ? message.content
      : hasImage
        ? '📷 Photo'
        : hasFile
          ? '📎 Attachment'
          : 'New message';
    const bodyFor = (userId: string) =>
      (previewByUser.get(userId) ?? true) ? previewBody : 'New message'

    // ── FCM send ──────────────────────────────────────────────────────────────
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
      const data = {
        tripId: message.itinerary_id,
        tripTitle: itinerary.title ?? '',
        senderName: message.sender_name ?? '',
        body: bodyFor(row.user_id),
      }
      const fcmMessage = row.platform === 'ios'
        ? {
          token: row.token,
          data,
          apns: {
            headers: { 'apns-priority': '10' },
            payload: {
              aps: {
                alert: { title: data.tripTitle ? `${data.senderName} · ${data.tripTitle}` : data.senderName, body: data.body },
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
    return json({ error: String(e) }, 500)
  }
})

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

// ── Google service-account OAuth2 (RS256-signed JWT bearer assertion) ───────
// Standard server-to-server auth flow, implemented with Deno's native Web
// Crypto so no third-party JWT dependency is needed.

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
