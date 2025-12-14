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

interface ManageUserRequest {
  target_user_id: string
  action: 'activate' | 'deactivate' | 'update_role'
  new_role?: 'student' | 'teacher' | 'admin'
  reason?: string
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
      console.warn(`Unauthorized user management attempt by user ${user.id}`)
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Admin access required' }),
        { status: 403, headers: corsHeaders }
      )
    }

    // Parse and validate request body
    const requestBody: ManageUserRequest = await req.json()
    const { target_user_id, action, new_role, reason } = requestBody

    // Input validation
    if (!target_user_id || typeof target_user_id !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Invalid target_user_id' }),
        { status: 400, headers: corsHeaders }
      )
    }

    if (!action || !['activate', 'deactivate', 'update_role'].includes(action)) {
      return new Response(
        JSON.stringify({ error: 'Invalid action. Must be "activate", "deactivate", or "update_role"' }),
        { status: 400, headers: corsHeaders }
      )
    }

    if (action === 'update_role' && (!new_role || !['student', 'teacher', 'admin'].includes(new_role))) {
      return new Response(
        JSON.stringify({ error: 'Invalid new_role. Must be "student", "teacher", or "admin"' }),
        { status: 400, headers: corsHeaders }
      )
    }

    // Prevent self-modification for security
    if (target_user_id === user.id) {
      return new Response(
        JSON.stringify({ error: 'Forbidden: Cannot modify your own account through this endpoint' }),
        { status: 403, headers: corsHeaders }
      )
    }

    // Get target user current state
    const { data: targetUser, error: targetUserError } = await supabaseAdmin
      .from('profiles')
      .select('id, role, is_active, full_name, email')
      .eq('id', target_user_id)
      .single()

    if (targetUserError || !targetUser) {
      return new Response(
        JSON.stringify({ error: 'Target user not found' }),
        { status: 404, headers: corsHeaders }
      )
    }

    // Prepare update data based on action
    let updateData: any = {
      updated_at: new Date().toISOString()
    }

    let actionDescription = ''

    switch (action) {
      case 'activate':
        updateData.is_active = true
        actionDescription = `activated user ${targetUser.full_name || targetUser.email}`
        break

      case 'deactivate':
        updateData.is_active = false
        actionDescription = `deactivated user ${targetUser.full_name || targetUser.email}`
        break

      case 'update_role':
        updateData.role = new_role
        actionDescription = `changed role of ${targetUser.full_name || targetUser.email} from ${targetUser.role} to ${new_role}`
        break
    }

    // Perform the update using SERVICE_ROLE_KEY to bypass RLS
    const { data: updatedUser, error: updateError } = await supabaseAdmin
      .from('profiles')
      .update(updateData)
      .eq('id', target_user_id)
      .select()
      .single()

    if (updateError) {
      console.error('Error updating user:', updateError)
      return new Response(
        JSON.stringify({
          error: 'Failed to update user',
          details: 'Operation failed. Please try again.'
        }),
        { status: 500, headers: corsHeaders }
      )
    }

    // SECURITY: Audit logging - Track all admin actions
    const clientIp = req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown'
    const userAgent = req.headers.get('user-agent') || 'unknown'

    // Build old and new values based on action
    const oldValues: any = {}
    const newValues: any = {}

    switch (action) {
      case 'activate':
      case 'deactivate':
        oldValues.is_active = targetUser.is_active
        newValues.is_active = updateData.is_active
        break
      case 'update_role':
        oldValues.role = targetUser.role
        newValues.role = new_role
        break
    }

    await supabaseAdmin.from('admin_audit_log').insert({
      admin_id: user.id,
      action_type: action === 'activate' ? 'activate_user' : action === 'deactivate' ? 'deactivate_user' : 'update_user_role',
      target_id: target_user_id,
      target_type: 'user',
      old_values: oldValues,
      new_values: newValues,
      ip_address: clientIp,
      user_agent: userAgent,
      notes: reason || actionDescription,
    })

    // Log admin action for monitoring
    console.log(`Admin ${user.id} ${actionDescription}. Reason: ${reason || 'Not provided'}`)

    return new Response(
      JSON.stringify({
        success: true,
        data: {
          user: updatedUser,
          action_performed: actionDescription
        },
        message: 'User updated successfully'
      }),
      {
        status: 200,
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
