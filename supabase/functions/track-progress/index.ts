/**
 * Edge Function: track-progress
 * Tracks and updates user progress through lessons and videos
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ProgressUpdate {
  lesson_id: string
  video_id?: string
  watched_duration_seconds: number
  last_watched_position_seconds: number
  total_duration_seconds: number
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

    const body: ProgressUpdate = await req.json()
    const {
      lesson_id,
      video_id,
      watched_duration_seconds,
      last_watched_position_seconds,
      total_duration_seconds,
    } = body

    // Calculate completion percentage
    const completion_percentage = total_duration_seconds > 0
      ? Math.min((watched_duration_seconds / total_duration_seconds) * 100, 100)
      : 0

    const is_completed = completion_percentage >= 90 // Consider complete if >90% watched

    // Upsert progress
    const progressData: any = {
      user_id: user.id,
      lesson_id,
      video_id,
      watched_duration_seconds,
      total_duration_seconds,
      completion_percentage: parseFloat(completion_percentage.toFixed(2)),
      is_completed,
      last_watched_position_seconds,
      last_watched_at: new Date().toISOString(),
    }

    if (is_completed && !progressData.completed_at) {
      progressData.completed_at = new Date().toISOString()
    }

    const { data: progress, error: progressError } = await supabaseClient
      .from('user_progress')
      .upsert(progressData)
      .select()
      .single()

    if (progressError) {
      throw new Error(`Failed to update progress: ${progressError.message}`)
    }

    // Track analytics event
    await supabaseClient.from('analytics_events').insert({
      user_id: user.id,
      event_type: 'video_progress',
      event_data: {
        lesson_id,
        video_id,
        completion_percentage,
        is_completed,
      },
    })

    // If lesson just completed, check if we should send a congratulations notification
    if (is_completed) {
      // Get lesson details
      const { data: lesson } = await supabaseClient
        .from('lessons')
        .select('title')
        .eq('id', lesson_id)
        .single()

      if (lesson) {
        await supabaseClient.from('notifications').insert({
          user_id: user.id,
          title: 'Lesson Completed! 🎉',
          message: `Congratulations! You completed: ${lesson.title}`,
          notification_type: 'info',
        })
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        progress: {
          completion_percentage,
          is_completed,
          watched_duration_seconds,
        },
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
