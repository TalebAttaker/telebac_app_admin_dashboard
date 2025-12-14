/**
 * Edge Function: analytics-track
 * Tracks analytics events from the mobile app
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AnalyticsEvent {
  event_type: string
  event_data?: Record<string, any>
  device_info?: {
    platform?: string
    os_version?: string
    app_version?: string
    device_model?: string
  }
  session_id?: string
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')

    // Analytics can work without auth for anonymous events
    let userId: string | null = null

    if (authHeader) {
      const supabaseClient = createClient(
        Deno.env.get('SUPABASE_URL') ?? '',
        Deno.env.get('SUPABASE_ANON_KEY') ?? '',
        {
          global: {
            headers: { Authorization: authHeader },
          },
        }
      )

      const {
        data: { user },
      } = await supabaseClient.auth.getUser()

      if (user) {
        userId = user.id
      }
    }

    // Support batch tracking
    const body = await req.json()
    const events: AnalyticsEvent[] = Array.isArray(body) ? body : [body]

    // Use service role for inserting analytics
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const analyticsRecords = events.map(event => ({
      user_id: userId,
      event_type: event.event_type,
      event_data: event.event_data || {},
      device_info: event.device_info || {},
      session_id: event.session_id,
      created_at: new Date().toISOString(),
    }))

    const { error } = await supabaseClient
      .from('analytics_events')
      .insert(analyticsRecords)

    if (error) {
      throw new Error(`Failed to track analytics: ${error.message}`)
    }

    return new Response(
      JSON.stringify({
        success: true,
        events_tracked: analyticsRecords.length,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
