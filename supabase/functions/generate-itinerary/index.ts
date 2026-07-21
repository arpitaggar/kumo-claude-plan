// Supabase Edge Function: generate-itinerary
//
// Calls Anthropic Claude on the server side so the API key never reaches
// the client app binary.
//
// Required secret (set once):
//   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//
// Deploy:
//   supabase functions deploy generate-itinerary

import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const MODEL = 'claude-haiku-4-5-20251001'

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

    // ── Parse request ────────────────────────────────────────────────────────
    const {
      destination,
      trip_days,
      travel_style,
      interests,
      start_date,
      end_date,
    } = await req.json() as {
      destination: string
      trip_days: number
      travel_style: string
      interests?: string
      start_date: string
      end_date: string
    }

    if (!destination || !trip_days || !travel_style || !start_date || !end_date) {
      return json({ error: 'Missing required fields' }, 400)
    }

    // ── Build prompt (mirrors the Flutter prompt exactly) ────────────────────
    const interestLine = interests ? `\nSpecific interests: ${interests}` : ''
    const prompt = `Generate a ${trip_days}-day travel itinerary for ${destination}.
Travel style: ${travel_style}${interestLine}
Trip dates: ${start_date} to ${end_date}

Return ONLY a valid JSON array — no markdown, no explanation. Each element must have exactly these fields:
{
  "item_type": "activity" | "flight" | "hotel" | "restaurant" | "transport",
  "title": "string",
  "start_time": "ISO 8601 datetime in UTC, e.g. 2026-06-10T09:00:00Z",
  "end_time": "ISO 8601 datetime in UTC or null",
  "location": "string or null"
}

Schedule 3-5 items per day, spread across realistic times. Use the actual trip dates.
`

    // ── Call Anthropic ───────────────────────────────────────────────────────
    const apiKey = Deno.env.get('ANTHROPIC_API_KEY')
    if (!apiKey) {
      return json({ error: 'ANTHROPIC_API_KEY secret not set' }, 500)
    }

    const anthropicRes = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        model: MODEL,
        max_tokens: 2048,
        messages: [{ role: 'user', content: prompt }],
      }),
    })

    if (!anthropicRes.ok) {
      const err = await anthropicRes.json().catch(() => ({}))
      const msg = (err as { error?: { message?: string } }).error?.message ?? anthropicRes.statusText
      console.error('Anthropic error:', msg)
      return json({ error: `AI request failed: ${msg}` }, 502)
    }

    const anthropicData = await anthropicRes.json() as {
      content?: Array<{ text?: string }>
    }
    const rawText = anthropicData.content?.[0]?.text ?? ''

    // ── Parse JSON array from AI response ────────────────────────────────────
    const items = parseItems(rawText)
    if (items === null) {
      console.error('Failed to parse AI response:', rawText.slice(0, 200))
      return json({ error: 'Could not parse AI response as JSON' }, 502)
    }

    return json({ items })
  } catch (e) {
    console.error('Unexpected error:', e)
    return json({ error: String(e) }, 500)
  }
})

function parseItems(text: string): unknown[] | null {
  const cleaned = text
    .replace(/```json\s*/g, '')
    .replace(/```\s*/g, '')
    .trim()

  try {
    const parsed = JSON.parse(cleaned)
    if (Array.isArray(parsed)) return parsed
  } catch (_) {
    // fallback: extract first [...] block
    const match = /\[[\s\S]*\]/.exec(cleaned)
    if (match) {
      try {
        const parsed = JSON.parse(match[0])
        if (Array.isArray(parsed)) return parsed
      } catch (_) { /* ignore */ }
    }
  }
  return null
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS },
  })
}
