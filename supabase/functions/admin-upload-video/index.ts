import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

// SECURITY: Restricted CORS - Only allow specific origins
const allowedOrigins = [
  'https://mauritania-edu-dashbsk.netlify.app',  // Admin dashboard (CORRECT URL)
  'https://admin.mauritania-edu.com',            // Production admin dashboard
  'http://localhost:8080',                       // Local development
  'http://localhost:3000',                       // Alternative dev port
]

function getCorsHeaders(origin: string | null): HeadersInit {
  const isAllowedOrigin = origin && allowedOrigins.includes(origin)

  return {
    'Access-Control-Allow-Origin': isAllowedOrigin ? origin : '',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    // Security headers
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'X-XSS-Protection': '1; mode=block',
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains',
    'Content-Type': 'application/json',
  }
}

interface UploadVideoRequest {
  bunny_video_id: string
  title?: string
  title_ar?: string
  title_fr?: string
  description?: string
  description_ar?: string
  description_fr?: string
  topic_id?: string
  lesson_id?: string
  duration_seconds: number
  thumbnail_url?: string
  encryption_key_id: string
  is_free?: boolean
  is_downloadable?: boolean
  display_order?: number
  url_360p?: string
  url_480p?: string
  url_720p?: string
  url_1080p?: string
}

serve(async (req) => {
  const origin = req.headers.get('origin')
  const corsHeaders = getCorsHeaders(origin)

  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders })
  }

  try {
    // Create Supabase client with SERVICE_ROLE_KEY for admin operations
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false
        }
      }
    )

    // Verify admin authentication
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(
        JSON.stringify({ error: 'Missing authorization header' }),
        { status: 401, headers: corsHeaders }
      )
    }

    const token = authHeader.replace('Bearer ', '')
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    )

    const { data: { user }, error: authError } = await supabaseUser.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: corsHeaders }
      )
    }

    // SERVER-SIDE ADMIN VERIFICATION
    const { data: adminProfile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('role, is_active')
      .eq('id', user.id)
      .single()

    if (profileError || !adminProfile) {
      return new Response(
        JSON.stringify({ error: 'Admin profile not found' }),
        { status: 403, headers: corsHeaders }
      )
    }

    if (adminProfile.role !== 'admin' || !adminProfile.is_active) {
      console.warn(`Unauthorized video upload attempt by user ${user.id}`)
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Admin access required' }),
        { status: 403, headers: corsHeaders }
      )
    }

    // Parse and validate request body
    const requestBody: UploadVideoRequest = await req.json()
    const {
      bunny_video_id,
      title,
      title_ar,
      title_fr,
      description,
      description_ar,
      description_fr,
      topic_id,
      lesson_id,
      duration_seconds,
      thumbnail_url,
      encryption_key_id,
      is_free,
      is_downloadable,
      display_order,
      url_360p,
      url_480p,
      url_720p,
      url_1080p
    } = requestBody

    // Input validation
    if (!bunny_video_id || typeof bunny_video_id !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Invalid bunny_video_id' }),
        { status: 400, headers: corsHeaders }
      )
    }

    if (!duration_seconds || typeof duration_seconds !== 'number' || duration_seconds <= 0) {
      return new Response(
        JSON.stringify({ error: 'Invalid duration_seconds - must be a positive number' }),
        { status: 400, headers: corsHeaders }
      )
    }

    if (!encryption_key_id || typeof encryption_key_id !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Invalid encryption_key_id' }),
        { status: 400, headers: corsHeaders }
      )
    }

    // At least one of topic_id or lesson_id should be provided
    if (!topic_id && !lesson_id) {
      return new Response(
        JSON.stringify({ error: 'Either topic_id or lesson_id must be provided' }),
        { status: 400, headers: corsHeaders }
      )
    }

    // Verify topic exists if provided
    if (topic_id) {
      const { data: topic, error: topicError } = await supabaseAdmin
        .from('topics')
        .select('id')
        .eq('id', topic_id)
        .single()

      if (topicError || !topic) {
        return new Response(
          JSON.stringify({ error: 'Topic not found' }),
          { status: 404, headers: corsHeaders }
        )
      }
    }

    // Verify lesson exists if provided
    if (lesson_id) {
      const { data: lesson, error: lessonError } = await supabaseAdmin
        .from('lessons')
        .select('id')
        .eq('id', lesson_id)
        .single()

      if (lessonError || !lesson) {
        return new Response(
          JSON.stringify({ error: 'Lesson not found' }),
          { status: 404, headers: corsHeaders }
        )
      }
    }

    // Check if video with this bunny_video_id already exists
    const { data: existingVideo } = await supabaseAdmin
      .from('videos')
      .select('id')
      .eq('bunny_video_id', bunny_video_id)
      .single()

    if (existingVideo) {
      return new Response(
        JSON.stringify({ error: 'Video with this bunny_video_id already exists' }),
        { status: 409, headers: corsHeaders }
      )
    }

    // Prepare video data
    const videoData: any = {
      bunny_video_id,
      duration_seconds,
      encryption_key_id,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      views_count: 0,
    }

    // Add optional fields if provided
    if (title) videoData.title = title
    if (title_ar) videoData.title_ar = title_ar
    if (title_fr) videoData.title_fr = title_fr
    if (description) videoData.description = description
    if (description_ar) videoData.description_ar = description_ar
    if (description_fr) videoData.description_fr = description_fr
    if (topic_id) videoData.topic_id = topic_id
    if (lesson_id) videoData.lesson_id = lesson_id
    if (thumbnail_url) videoData.thumbnail_url = thumbnail_url
    if (is_free !== undefined) videoData.is_free = is_free
    if (is_downloadable !== undefined) videoData.is_downloadable = is_downloadable
    if (display_order !== undefined) videoData.display_order = display_order
    if (url_360p) videoData.url_360p = url_360p
    if (url_480p) videoData.url_480p = url_480p
    if (url_720p) videoData.url_720p = url_720p
    if (url_1080p) videoData.url_1080p = url_1080p

    // Insert video record
    const { data: newVideo, error: insertError } = await supabaseAdmin
      .from('videos')
      .insert(videoData)
      .select()
      .single()

    if (insertError) {
      console.error('Error inserting video:', insertError)
      return new Response(
        JSON.stringify({
          error: 'Failed to create video record',
          details: 'Operation failed. Please try again.'
        }),
        { status: 500, headers: corsHeaders }
      )
    }

    // SECURITY: Audit logging - Track all admin actions
    const clientIp = req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown'
    const userAgent = req.headers.get('user-agent') || 'unknown'

    await supabaseAdmin.from('admin_audit_log').insert({
      admin_id: user.id,
      action_type: 'upload_video',
      target_id: newVideo.id,
      target_type: 'video',
      old_values: null,
      new_values: {
        bunny_video_id: bunny_video_id,
        title: title_ar || title || 'Untitled',
        topic_id: topic_id || null,
        lesson_id: lesson_id || null,
        duration_seconds: duration_seconds,
        is_free: is_free || false
      },
      ip_address: clientIp,
      user_agent: userAgent,
      notes: `Uploaded video: ${title_ar || title || bunny_video_id}`,
    })

    // Log admin action for monitoring
    console.log(`Admin ${user.id} uploaded video ${bunny_video_id} (ID: ${newVideo.id}) - Title: ${title_ar || title || 'Untitled'}`)

    return new Response(
      JSON.stringify({
        success: true,
        data: newVideo,
        message: 'Video uploaded successfully'
      }),
      {
        status: 201,
        headers: corsHeaders
      }
    )

  } catch (error) {
    console.error('Unexpected error:', error)
    return new Response(
      JSON.stringify({
        error: 'Internal server error',
        details: 'Operation failed. Please try again.'
      }),
      { status: 500, headers: getCorsHeaders(req.headers.get('origin')) }
    )
  }
})
