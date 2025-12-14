/**
 * Edge Function: admin-operations
 * Handles admin-specific operations like content management, user management, etc.
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
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
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Get user and verify admin role
    const {
      data: { user },
      error: userError,
    } = await supabaseClient.auth.getUser(authHeader.replace('Bearer ', ''))

    if (userError || !user) {
      throw new Error('Invalid user token')
    }

    const { data: profile } = await supabaseClient
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single()

    if (!profile || profile.role !== 'admin') {
      return new Response(
        JSON.stringify({ error: 'Admin access required' }),
        {
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          status: 403,
        }
      )
    }

    const url = new URL(req.url)
    const operation = url.searchParams.get('operation')

    switch (operation) {
      case 'stats': {
        // Get platform statistics
        const [
          { count: totalUsers },
          { count: activeSubscriptions },
          { count: totalLessons },
          { count: totalVideos },
        ] = await Promise.all([
          supabaseClient.from('profiles').select('*', { count: 'exact', head: true }),
          supabaseClient.from('subscriptions').select('*', { count: 'exact', head: true }).eq('status', 'active'),
          supabaseClient.from('lessons').select('*', { count: 'exact', head: true }),
          supabaseClient.from('videos').select('*', { count: 'exact', head: true }),
        ])

        // Get recent activity
        const { data: recentActivity } = await supabaseClient
          .from('analytics_events')
          .select('event_type, created_at')
          .order('created_at', { ascending: false })
          .limit(100)

        return new Response(
          JSON.stringify({
            stats: {
              total_users: totalUsers || 0,
              active_subscriptions: activeSubscriptions || 0,
              total_lessons: totalLessons || 0,
              total_videos: totalVideos || 0,
            },
            recent_activity: recentActivity,
          }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          }
        )
      }

      case 'users': {
        // Get all users with pagination
        const page = parseInt(url.searchParams.get('page') || '1')
        const limit = parseInt(url.searchParams.get('limit') || '20')
        const offset = (page - 1) * limit

        const { data: users, count } = await supabaseClient
          .from('profiles')
          .select(`
            id,
            email,
            full_name,
            role,
            is_active,
            created_at,
            subscriptions(plan_type, status, end_date)
          `, { count: 'exact' })
          .range(offset, offset + limit - 1)
          .order('created_at', { ascending: false })

        return new Response(
          JSON.stringify({
            users,
            pagination: {
              page,
              limit,
              total: count || 0,
              pages: Math.ceil((count || 0) / limit),
            },
          }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          }
        )
      }

      case 'toggle-user': {
        // Activate/deactivate user
        const body = await req.json()
        const { user_id, is_active } = body

        await supabaseClient
          .from('profiles')
          .update({ is_active })
          .eq('id', user_id)

        return new Response(
          JSON.stringify({ success: true }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          }
        )
      }

      case 'content-stats': {
        // Get content statistics
        const { data: gradeStats } = await supabaseClient
          .from('grades')
          .select(`
            id,
            name,
            subjects(count),
            subjects(topics(count)),
            subjects(topics(lessons(count)))
          `)

        return new Response(
          JSON.stringify({ grade_stats: gradeStats }),
          {
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            status: 200,
          }
        )
      }

      default:
        throw new Error('Invalid operation')
    }
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
