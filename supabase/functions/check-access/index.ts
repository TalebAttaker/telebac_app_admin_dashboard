/**
 * Edge Function: check-access
 * Validates if a user has access to specific content based on their subscription
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AccessCheckRequest {
  lesson_id?: string
  subject_id?: string
  grade_id?: string
}

Deno.serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get authorization header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader },
        },
      }
    )

    // Get user
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser()

    if (userError || !user) {
      throw new Error('Invalid user token')
    }

    // Parse request body
    const body: AccessCheckRequest = await req.json()
    const { lesson_id, subject_id, grade_id } = body

    // Check if lesson is free
    if (lesson_id) {
      const { data: lesson } = await supabaseClient
        .from('lessons')
        .select('is_free, topic_id, topics(subject_id, subjects(grade_id))')
        .eq('id', lesson_id)
        .single()

      if (lesson?.is_free) {
        return new Response(
          JSON.stringify({ has_access: true, reason: 'free_content' }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          }
        )
      }
    }

    // Check active subscription
    const { data: activeSubscription } = await supabaseClient
      .from('subscriptions')
      .select('id, status, end_date, subscription_plans(id, grade_id)')
      .eq('user_id', user.id)
      .eq('status', 'active')
      .gt('end_date', new Date().toISOString())
      .maybeSingle()

    if (!activeSubscription) {
      return new Response(
        JSON.stringify({ has_access: false, reason: 'no_active_subscription' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 200,
        }
      )
    }

    // Get plan details
    const plan = activeSubscription.subscription_plans

    // If checking grade access
    if (grade_id && plan?.grade_id) {
      if (plan.grade_id === grade_id) {
        return new Response(
          JSON.stringify({ has_access: true, reason: 'subscription_valid' }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          }
        )
      }
    }

    // If checking subject access - get subject's grade and compare
    if (subject_id) {
      const { data: subject } = await supabaseClient
        .from('subjects')
        .select('grade_id')
        .eq('id', subject_id)
        .single()

      if (subject && plan?.grade_id === subject.grade_id) {
        return new Response(
          JSON.stringify({ has_access: true, reason: 'subscription_valid' }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          }
        )
      }
    }

    // If checking lesson access - get lesson's topic's subject's grade
    if (lesson_id) {
      const { data: lesson } = await supabaseClient
        .from('lessons')
        .select('topic_id, topics(subject_id, subjects(grade_id))')
        .eq('id', lesson_id)
        .single()

      const lessonGradeId = lesson?.topics?.subjects?.grade_id
      if (lessonGradeId && plan?.grade_id === lessonGradeId) {
        return new Response(
          JSON.stringify({ has_access: true, reason: 'subscription_valid' }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          }
        )
      }
    }

    // User has subscription but it doesn't cover this content
    return new Response(
      JSON.stringify({ has_access: false, reason: 'subscription_does_not_cover_content' }),
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
