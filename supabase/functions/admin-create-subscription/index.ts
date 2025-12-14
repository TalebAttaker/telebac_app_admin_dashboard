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

interface CreateSubscriptionRequest {
  user_id: string
  plan_id: string
  start_date?: string
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
    const { data: profile, error: profileError } = await supabaseAdmin
      .from('profiles')
      .select('role, is_active')
      .eq('id', user.id)
      .single()

    if (profileError || !profile) {
      return new Response(
        JSON.stringify({ error: 'User profile not found' }),
        { status: 403, headers: corsHeaders }
      )
    }

    if (profile.role !== 'admin' || !profile.is_active) {
      console.warn(`Unauthorized subscription creation attempt by user ${user.id}`)
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Admin access required' }),
        { status: 403, headers: corsHeaders }
      )
    }

    // Parse and validate request body
    const requestBody: CreateSubscriptionRequest = await req.json()
    const { user_id, plan_id, start_date } = requestBody

    // Input validation
    if (!user_id || typeof user_id !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Invalid user_id' }),
        { status: 400, headers: corsHeaders }
      )
    }

    if (!plan_id || typeof plan_id !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Invalid plan_id' }),
        { status: 400, headers: corsHeaders }
      )
    }

    // Verify user exists
    const { data: targetUser, error: userError } = await supabaseAdmin
      .from('profiles')
      .select('id')
      .eq('id', user_id)
      .single()

    if (userError || !targetUser) {
      return new Response(
        JSON.stringify({ error: 'Target user not found' }),
        { status: 404, headers: corsHeaders }
      )
    }

    // Verify subscription plan exists and get duration
    const { data: plan, error: planError } = await supabaseAdmin
      .from('subscription_plans')
      .select('id, duration_type, is_active')
      .eq('id', plan_id)
      .single()

    if (planError || !plan) {
      return new Response(
        JSON.stringify({ error: 'Subscription plan not found' }),
        { status: 404, headers: corsHeaders }
      )
    }

    if (!plan.is_active) {
      return new Response(
        JSON.stringify({ error: 'Subscription plan is not active' }),
        { status: 400, headers: corsHeaders }
      )
    }

    // Calculate subscription dates
    const subscriptionStartDate = start_date ? new Date(start_date) : new Date()
    const subscriptionEndDate = new Date(subscriptionStartDate)

    // Add duration based on duration_type
    switch (plan.duration_type) {
      case 'monthly':
        subscriptionEndDate.setMonth(subscriptionEndDate.getMonth() + 1)
        break
      case 'quarterly':
        subscriptionEndDate.setMonth(subscriptionEndDate.getMonth() + 3)
        break
      case 'semester':
        subscriptionEndDate.setMonth(subscriptionEndDate.getMonth() + 6)
        break
      case 'yearly':
        subscriptionEndDate.setFullYear(subscriptionEndDate.getFullYear() + 1)
        break
      default:
        // Default to monthly if duration_type is unknown
        subscriptionEndDate.setMonth(subscriptionEndDate.getMonth() + 1)
    }

    // Check if user already has an active subscription
    const { data: existingSubscriptions } = await supabaseAdmin
      .from('subscriptions')
      .select('id, status, end_date')
      .eq('user_id', user_id)
      .eq('status', 'active')

    if (existingSubscriptions && existingSubscriptions.length > 0) {
      // User has active subscription - we could either reject or extend
      // For now, let's allow creating a new subscription (admin decision)
      console.log(`User ${user_id} already has ${existingSubscriptions.length} active subscription(s)`)
    }

    // Create new subscription
    const { data: newSubscription, error: createError } = await supabaseAdmin
      .from('subscriptions')
      .insert({
        user_id: user_id,
        plan_id: plan_id,
        status: 'active',
        start_date: subscriptionStartDate.toISOString(),
        end_date: subscriptionEndDate.toISOString(),
        approved_by: user.id,
        approved_at: new Date().toISOString(),
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select()
      .single()

    if (createError) {
      console.error('Error creating subscription:', createError)
      return new Response(
        JSON.stringify({
          error: 'Failed to create subscription',
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
      action_type: 'create_subscription',
      target_id: newSubscription.id,
      target_type: 'subscription',
      old_values: null,
      new_values: {
        user_id: user_id,
        plan_id: plan_id,
        start_date: subscriptionStartDate.toISOString(),
        end_date: subscriptionEndDate.toISOString(),
        status: 'active'
      },
      ip_address: clientIp,
      user_agent: userAgent,
      notes: `Created ${plan.duration_type} subscription for user ${user_id}`,
    })

    // Log admin action for monitoring
    console.log(`Admin ${user.id} created subscription ${newSubscription.id} for user ${user_id} with plan ${plan_id}`)

    return new Response(
      JSON.stringify({
        success: true,
        data: newSubscription,
        message: 'Subscription created successfully'
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
