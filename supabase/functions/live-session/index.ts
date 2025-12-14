/**
 * Edge Function: live-session
 * Manages Jitsi live session creation and JWT token generation
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { create } from 'https://deno.land/x/djwt@v2.8/mod.ts'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface CreateSessionRequest {
  lesson_id?: string
  title: string
  description?: string
  scheduled_start: string
  scheduled_end: string
}

interface JoinSessionRequest {
  session_id: string
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

    const url = new URL(req.url)
    const action = url.searchParams.get('action') || 'join'

    // CREATE SESSION (Admin/Teacher only)
    if (action === 'create') {
      const body: CreateSessionRequest = await req.json()
      const { lesson_id, title, description, scheduled_start, scheduled_end } = body

      // Check if user is teacher or admin
      const { data: profile } = await supabaseClient
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single()

      if (!profile || !['teacher', 'admin'].includes(profile.role)) {
        throw new Error('Only teachers and admins can create live sessions')
      }

      // Generate unique room name
      const roomName = `edu_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`

      // Create session
      const { data: session, error: sessionError } = await supabaseClient
        .from('live_sessions')
        .insert({
          lesson_id,
          teacher_id: user.id,
          title,
          description,
          scheduled_start,
          scheduled_end,
          jitsi_room_name: roomName,
          status: 'scheduled',
        })
        .select()
        .single()

      if (sessionError) {
        throw new Error(`Failed to create session: ${sessionError.message}`)
      }

      return new Response(
        JSON.stringify({
          session_id: session.id,
          room_name: roomName,
          scheduled_start,
          scheduled_end,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    // JOIN SESSION
    if (action === 'join') {
      const body: JoinSessionRequest = await req.json()
      const { session_id } = body

      // Get session details
      const { data: session, error: sessionError } = await supabaseClient
        .from('live_sessions')
        .select('*')
        .eq('id', session_id)
        .single()

      if (sessionError || !session) {
        throw new Error('Session not found')
      }

      // Check if session is live or scheduled
      if (session.status === 'cancelled') {
        throw new Error('Session has been cancelled')
      }

      if (session.status === 'ended') {
        throw new Error('Session has ended')
      }

      // Get user profile
      const { data: profile } = await supabaseClient
        .from('profiles')
        .select('full_name, role')
        .eq('id', user.id)
        .single()

      // Update session status to live if it's the teacher joining
      if (session.teacher_id === user.id && session.status === 'scheduled') {
        await supabaseClient
          .from('live_sessions')
          .update({ status: 'live', actual_start: new Date().toISOString() })
          .eq('id', session_id)
      }

      // Record attendance
      await supabaseClient
        .from('live_session_attendance')
        .upsert({
          session_id,
          user_id: user.id,
          joined_at: new Date().toISOString(),
        })

      // Generate Jitsi JWT token (simplified - implement full JWT for production)
      const jitsiAppId = Deno.env.get('JITSI_APP_ID') ?? 'mauritania-edu'
      const jitsiSecret = Deno.env.get('JITSI_SECRET') ?? 'your-secret-key'

      const payload = {
        aud: jitsiAppId,
        iss: jitsiAppId,
        sub: Deno.env.get('JITSI_DOMAIN') ?? 'meet.jit.si',
        room: session.jitsi_room_name,
        context: {
          user: {
            id: user.id,
            name: profile?.full_name || 'Student',
            email: user.email,
            moderator: session.teacher_id === user.id,
          },
        },
        moderator: session.teacher_id === user.id,
      }

      const key = await crypto.subtle.importKey(
        'raw',
        new TextEncoder().encode(jitsiSecret),
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign']
      )

      const token = await create({ alg: 'HS256', typ: 'JWT' }, payload, key)

      return new Response(
        JSON.stringify({
          room_name: session.jitsi_room_name,
          jwt_token: token,
          is_moderator: session.teacher_id === user.id,
          session_title: session.title,
          jitsi_url: `https://${Deno.env.get('JITSI_DOMAIN') ?? 'meet.jit.si'}/${session.jitsi_room_name}?jwt=${token}`,
        }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    throw new Error('Invalid action')
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
