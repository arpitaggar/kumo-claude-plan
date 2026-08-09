// Supabase Edge Function: inbound-trip-email
//
// Receives mail sent to a trip's masked email alias (see stage27's
// migration and public.trip_email_aliases) from an inbound-email provider,
// and re-sends it to every member of that trip via Resend — the alias
// behaves like a distribution list with no inbox of its own; nothing here
// is ever persisted beyond a metadata-only audit log (trip_email_forward_log).
//
// ── One-time setup this function depends on (none of it is code) ──────────
//   1. A domain (or subdomain, e.g. trips.kumo.app) you control DNS for.
//   2. An inbound-email provider with MX records pointed at that domain,
//      configured to POST each received message here as JSON:
//        { "to": "trip-x7k2m9qz@trips.kumo.app", "from": "...",
//          "subject": "...", "text": "...", "html": "..." }
//      `to`/`from` may also be "Display Name <addr@host>" — both forms are
//      parsed below. Cloudflare Email Routing (free, via a small Email
//      Worker that normalises its message into this shape) or Postmark/
//      Mailgun inbound parsing both work; as of this writing Resend does
//      not offer inbound receiving, only sending, so it can't be both ends.
//      If your provider's native webhook payload differs from the shape
//      above, transform it before it reaches this endpoint rather than
//      teaching this function every provider's format.
//   3. supabase secrets set INBOUND_WEBHOOK_SECRET=... — and configure your
//      provider to send it back (e.g. as a bearer token or query param on
//      the webhook URL), so this endpoint isn't an open relay anyone can
//      POST to and have it spam every trip's members.
//   4. supabase secrets set RESEND_API_KEY=re_... RESEND_FROM="Kumo Trips
//      <trips@yourdomain.com>" — same secret invite-email already uses.
//   5. update public.app_config set value = 'trips.yourdomain.com' where
//      key = 'trip_email_domain'; once the domain above is live, so the
//      address shown in-app matches what actually receives mail.
//
// Deploy:
//   supabase functions deploy inbound-trip-email --no-verify-jwt
//   (--no-verify-jwt: the caller is an email provider, not a Supabase user,
//   so it can't send a Supabase JWT — INBOUND_WEBHOOK_SECRET is the guard.)

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': Deno.env.get('ALLOWED_ORIGIN') ?? 'https://kumo.app',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Hard cap on forwards per trip per hour — a masked address that leaks (or
// gets targeted) shouldn't be able to spam every member indefinitely.
const MAX_FORWARDS_PER_HOUR = 20

// Plain `!==` short-circuits on the first differing byte, so an attacker
// timing many requests could in principle narrow down INBOUND_WEBHOOK_SECRET
// character-by-character. Always walks the full (max) length of both inputs
// regardless of where — or whether — they diverge, so comparison time
// doesn't leak how much of the guess was correct.
function timingSafeEqual(a: string, b: string): boolean {
  const aBytes = new TextEncoder().encode(a)
  const bBytes = new TextEncoder().encode(b)
  const length = Math.max(aBytes.length, bBytes.length)
  let diff = aBytes.length === bBytes.length ? 0 : 1
  for (let i = 0; i < length; i++) {
    diff |= (aBytes[i] ?? 0) ^ (bBytes[i] ?? 0)
  }
  return diff === 0
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS })
  }

  try {
    const expectedSecret = Deno.env.get('INBOUND_WEBHOOK_SECRET')
    const providedSecret = req.headers.get('Authorization')?.replace('Bearer ', '')
    if (!expectedSecret || !providedSecret || !timingSafeEqual(providedSecret, expectedSecret)) {
      return json({ error: 'Unauthorized' }, 401)
    }

    const body = await req.json() as {
      to?: string
      from?: string
      subject?: string
      text?: string
      html?: string
    }

    const localPart = extractLocalPart(body.to)
    const fromAddress = extractAddress(body.from) ?? body.from ?? 'unknown sender'
    if (!localPart) {
      return json({ error: 'Could not parse a recipient alias from "to"' }, 400)
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } },
    )

    // ── Look up the trip this alias belongs to ───────────────────────────────
    const { data: aliasRow } = await supabaseAdmin
      .from('trip_email_aliases')
      .select('itinerary_id, itineraries(title, owner_id, members)')
      .eq('local_part', localPart)
      .maybeSingle()

    if (!aliasRow?.itineraries) {
      // Not one of ours (wrong address, stale/deleted trip) — don't leak
      // which addresses are valid via the response.
      return json({ received: true, forwarded: false })
    }

    const itineraryId = aliasRow.itinerary_id as string
    const trip = aliasRow.itineraries as {
      title: string
      owner_id: string
      members: Array<{ userId?: string; user_id?: string }>
    }

    // ── Rate limit ────────────────────────────────────────────────────────
    const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000).toISOString()
    const { count } = await supabaseAdmin
      .from('trip_email_forward_log')
      .select('id', { count: 'exact', head: true })
      .eq('itinerary_id', itineraryId)
      .gte('created_at', oneHourAgo)

    if ((count ?? 0) >= MAX_FORWARDS_PER_HOUR) {
      return json({ received: true, forwarded: false, reason: 'rate_limited' }, 429)
    }

    // ── Resolve member emails ─────────────────────────────────────────────
    const memberIds = [
      trip.owner_id,
      ...trip.members.map((m) => m.userId ?? m.user_id).filter((id): id is string => !!id),
    ]
    const uniqueMemberIds = [...new Set(memberIds)]

    const { data: profiles } = await supabaseAdmin
      .from('profiles')
      .select('email')
      .in('id', uniqueMemberIds)

    const recipients = [...new Set(
      (profiles ?? []).map((p) => p.email as string).filter(Boolean),
    )]

    if (recipients.length === 0) {
      return json({ received: true, forwarded: false, reason: 'no_recipients' })
    }

    // ── Forward via Resend ────────────────────────────────────────────────
    const resendKey = Deno.env.get('RESEND_API_KEY')
    if (!resendKey) {
      console.error('RESEND_API_KEY not configured — cannot forward inbound trip email')
      return json({ error: 'Email forwarding not configured' }, 500)
    }

    const subject = `[${trip.title}] ${body.subject ?? '(no subject)'}`
    const from = Deno.env.get('RESEND_FROM') ?? 'Kumo Trips <trips@example.com>'

    const res = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        from,
        // All recipients see each other — this is meant to behave like a
        // distribution list, not a bcc blast, and every recipient here is
        // already a member of the same trip.
        to: recipients,
        // So a reply goes back to the airline/hotel/organiser, not into
        // this alias (which has no inbox to receive it).
        reply_to: fromAddress,
        subject,
        html: body.html ?? `<pre style="white-space:pre-wrap">${escapeHtml(body.text ?? '')}</pre>`,
        text: body.text,
      }),
    })

    if (!res.ok) {
      const err = await res.text()
      console.error('Resend error:', err)
      return json({ received: true, forwarded: false, error: err }, 502)
    }

    await supabaseAdmin.from('trip_email_forward_log').insert({
      itinerary_id: itineraryId,
      from_address: fromAddress,
      subject: body.subject ?? null,
      forwarded_to: recipients.length,
    })

    return json({ received: true, forwarded: true, recipients: recipients.length })
  } catch (e) {
    console.error('Unexpected error:', e)
    return json({ error: 'Internal server error' }, 500)
  }
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  })
}

// Accepts a bare address ("a@b.com") or "Display Name <a@b.com>".
function extractAddress(raw: string | undefined): string | null {
  if (!raw) return null
  const angleMatch = raw.match(/<([^>]+)>/)
  return (angleMatch?.[1] ?? raw).trim()
}

function extractLocalPart(rawTo: string | undefined): string | null {
  const address = extractAddress(rawTo)
  if (!address || !address.includes('@')) return null
  return address.split('@')[0]!.trim().toLowerCase()
}

function escapeHtml(s: string) {
  return s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
}
