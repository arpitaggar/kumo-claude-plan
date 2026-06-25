// Supabase Edge Function: invite-email
//
// Sends a trip invitation email when a pending_invitations row is created.
//
// Email strategy (in order of preference):
//   1. Resend  — if RESEND_API_KEY secret is set  → branded Kumo email
//   2. Supabase Auth inviteUserByEmail             → built-in email, no setup needed
//
// Required for Resend (optional):
//   supabase secrets set RESEND_API_KEY=re_... RESEND_FROM="Kumo <invites@yourdomain.com>"
//
// Deploy:
//   supabase functions deploy invite-email

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      { auth: { autoRefreshToken: false, persistSession: false } },
    )

    // Verify the caller is a real authenticated user
    const { data: { user }, error: userErr } = await supabaseAdmin.auth.getUser(
      authHeader.replace('Bearer ', ''),
    )
    if (userErr || !user) {
      return json({ error: 'Unauthorized' }, 401)
    }

    // ── Parse body ───────────────────────────────────────────────────────────
    const { itinerary_id, invited_email, role } = await req.json() as {
      itinerary_id: string
      invited_email: string
      role: string
    }

    if (!itinerary_id || !invited_email) {
      return json({ error: 'itinerary_id and invited_email are required' }, 400)
    }

    // ── Fetch trip + inviter ─────────────────────────────────────────────────
    const [{ data: trip }, { data: inviter }] = await Promise.all([
      supabaseAdmin.from('itineraries')
        .select('title, start_date, end_date')
        .eq('id', itinerary_id)
        .single(),
      supabaseAdmin.from('profiles')
        .select('display_name, email')
        .eq('id', user.id)
        .single(),
    ])

    if (!trip) {
      return json({ error: 'Trip not found' }, 404)
    }

    const inviterName = inviter?.display_name || inviter?.email || 'A Kumo traveller'
    const fmt = (d: string) =>
      new Date(d).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' })
    const startDate = fmt(trip.start_date)
    const endDate   = fmt(trip.end_date)
    const tripTitle = trip.title

    // ── Send email ───────────────────────────────────────────────────────────
    const resendKey = Deno.env.get('RESEND_API_KEY')

    if (resendKey) {
      // ── Option 1: Resend (branded) ─────────────────────────────────────────
      const from = Deno.env.get('RESEND_FROM') ?? 'Kumo <invites@example.com>'
      const res = await fetch('https://api.resend.com/emails', {
        method: 'POST',
        headers: { Authorization: `Bearer ${resendKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          from,
          to: [invited_email],
          subject: `${inviterName} invited you to "${tripTitle}" on Kumo`,
          html: buildHtml({ inviterName, tripTitle, startDate, endDate }),
          text: buildText({ inviterName, tripTitle, startDate, endDate }),
        }),
      })

      if (!res.ok) {
        const err = await res.text()
        console.error('Resend error:', err)
        return json({ sent: false, method: 'resend', error: err }, 502)
      }

      return json({ sent: true, method: 'resend' })
    }

    // ── Option 2: Supabase built-in invite email (no setup needed) ─────────
    // Creates a magic-link invite. When the recipient signs up via the link,
    // handle_new_user fires and auto-joins them from pending_invitations.
    const { error: inviteErr } = await supabaseAdmin.auth.admin.inviteUserByEmail(
      invited_email,
      {
        data: {
          invited_to_trip: itinerary_id,
          invited_by_name: inviterName,
          trip_title: tripTitle,
        },
      },
    )

    if (inviteErr) {
      // "User already registered" is not a real error for our purposes —
      // the DB pending_invitations row is already saved and the trigger
      // will add them next time they log in.
      if (inviteErr.message?.includes('already registered')) {
        console.log('User already registered, invite saved for next login.')
        return json({ sent: false, method: 'supabase_invite', reason: 'already_registered' })
      }
      console.error('Supabase invite error:', inviteErr)
      return json({ sent: false, method: 'supabase_invite', error: inviteErr.message }, 502)
    }

    return json({ sent: true, method: 'supabase_invite' })
  } catch (e) {
    console.error('Unexpected error:', e)
    return json({ error: String(e) }, 500)
  }
})

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  })
}

interface Vars { inviterName: string; tripTitle: string; startDate: string; endDate: string }

function buildHtml(v: Vars) {
  return `<!DOCTYPE html>
<html>
<body style="font-family:sans-serif;background:#F5F2EB;margin:0;padding:32px">
  <div style="max-width:480px;margin:0 auto;background:#fff;border-radius:16px;padding:32px">
    <h1 style="font-size:24px;color:#2C1E1C;margin:0 0 8px">✈️ You're invited!</h1>
    <p style="color:#5D4B46;margin:0 0 24px">
      <strong>${v.inviterName}</strong> has invited you to join a trip on Kumo.
    </p>
    <div style="background:#FDF5F6;border-radius:12px;padding:20px;margin-bottom:24px">
      <p style="font-size:18px;font-weight:700;color:#2C1E1C;margin:0 0 4px">${v.tripTitle}</p>
      <p style="color:#5D4B46;margin:0">${v.startDate} – ${v.endDate}</p>
    </div>
    <p style="color:#5D4B46;font-size:14px">
      Download Kumo and sign up with this email address to automatically join the trip.
    </p>
  </div>
</body>
</html>`
}

function buildText(v: Vars) {
  return `${v.inviterName} invited you to "${v.tripTitle}" (${v.startDate} – ${v.endDate}) on Kumo. Download Kumo and sign up with this email to join automatically.`
}
