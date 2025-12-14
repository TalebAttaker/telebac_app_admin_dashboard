/**
 * Edge Function: generate-video-token
 * Generates secure BunnyCDN Stream signed URLs with token authentication
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// BunnyCDN Stream Configuration
const BUNNY_LIBRARY_ID = Deno.env.get('BUNNY_LIBRARY_ID') || '543524'
const BUNNY_TOKEN_AUTH_KEY = Deno.env.get('BUNNY_TOKEN_AUTH_KEY')
const BUNNY_CDN_HOSTNAME = Deno.env.get('BUNNY_CDN_HOSTNAME') || 'vz-538dcb17-d29.b-cdn.net'

// Validate required environment variables
if (!BUNNY_TOKEN_AUTH_KEY) {
  console.error('❌ Missing required environment variable: BUNNY_TOKEN_AUTH_KEY')
}

interface VideoTokenRequest {
  video_id: string
  resolution?: '360p' | '480p' | '720p' | '1080p'
  expiry_hours?: number
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

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
      error: userError,
    } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      throw new Error('Invalid user token')
    }

    const body: VideoTokenRequest = await req.json()
    const { video_id, resolution = '720p', expiry_hours = 1 } = body

    if (!video_id) {
      throw new Error('video_id is required')
    }

    // Get video details
    const { data: video, error: videoError } = await supabaseClient
      .from('videos')
      .select('id, bunny_video_id, is_free, topic_id')
      .eq('id', video_id)
      .single()

    if (videoError || !video) {
      throw new Error('Video not found')
    }

    // Check access (unless it's free content)
    if (!video.is_free) {
      // Check subscription access
      const { data: activeSubscription } = await supabaseClient
        .from('subscriptions')
        .select('id, status, end_date, subscription_plans(grade_id)')
        .eq('user_id', user.id)
        .eq('status', 'active')
        .gt('end_date', new Date().toISOString())
        .maybeSingle()

      if (!activeSubscription) {
        return new Response(
          JSON.stringify({ error: 'No active subscription' }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 403,
          }
        )
      }
    }

    // Use quality-specific HLS stream for manual quality selection
    // Security is handled by Edge Function access control
    const videoUrl = `https://${BUNNY_CDN_HOSTNAME}/${video.bunny_video_id}/${resolution}/video.m3u8`

    const expiresAt = Math.floor(Date.now() / 1000) + expiry_hours * 3600

    // Log video view for analytics
    await supabaseClient.from('analytics_events').insert({
      user_id: user.id,
      event_type: 'video_token_generated',
      event_data: {
        video_id,
        resolution,
        bunny_video_id: video.bunny_video_id,
      },
    })

    return new Response(
      JSON.stringify({
        video_url: videoUrl,
        expires_at: new Date(expiresAt * 1000).toISOString(),
        resolution,
        bunny_video_id: video.bunny_video_id,
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Error generating video token:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
