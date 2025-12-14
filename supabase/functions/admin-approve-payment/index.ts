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

interface ApprovePaymentRequest {
  payment_proof_id: string
  action: 'approve' | 'reject'
  admin_notes?: string
  rejection_reason?: string
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

    // Create client with user's JWT for auth verification
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

    // Verify user authentication
    const { data: { user }, error: authError } = await supabaseUser.auth.getUser(token)

    if (authError || !user) {
      return new Response(
        JSON.stringify({ error: 'Invalid or expired token' }),
        { status: 401, headers: corsHeaders }
      )
    }

    // SERVER-SIDE ADMIN VERIFICATION (CRITICAL SECURITY CHECK)
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
      console.warn(`Unauthorized access attempt by user ${user.id} - role: ${profile.role}, active: ${profile.is_active}`)
      return new Response(
        JSON.stringify({ error: 'Unauthorized: Admin access required' }),
        { status: 403, headers: corsHeaders }
      )
    }

    // Parse and validate request body
    const requestBody: ApprovePaymentRequest = await req.json()
    const { payment_proof_id, action, admin_notes, rejection_reason } = requestBody

    // Input validation
    if (!payment_proof_id || typeof payment_proof_id !== 'string') {
      return new Response(
        JSON.stringify({ error: 'Invalid payment_proof_id' }),
        { status: 400, headers: corsHeaders }
      )
    }

    if (!action || !['approve', 'reject'].includes(action)) {
      return new Response(
        JSON.stringify({ error: 'Invalid action. Must be "approve" or "reject"' }),
        { status: 400, headers: corsHeaders }
      )
    }

    if (action === 'reject' && !rejection_reason) {
      return new Response(
        JSON.stringify({ error: 'rejection_reason is required when rejecting a payment' }),
        { status: 400, headers: corsHeaders }
      )
    }

    // Check if payment proof exists
    const { data: existingProof, error: fetchError } = await supabaseAdmin
      .from('payment_proofs')
      .select('id, status, user_id')
      .eq('id', payment_proof_id)
      .single()

    if (fetchError || !existingProof) {
      return new Response(
        JSON.stringify({ error: 'Payment proof not found' }),
        { status: 404, headers: corsHeaders }
      )
    }

    // Update payment proof status
    const newStatus = action === 'approve' ? 'approved' : 'rejected'
    const updateData: any = {
      status: newStatus,
      reviewed_by: user.id,
      reviewed_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    }

    if (admin_notes) {
      updateData.admin_notes = admin_notes
    }

    if (action === 'reject' && rejection_reason) {
      updateData.rejection_reason = rejection_reason
    }

    const { data: updatedProof, error: updateError } = await supabaseAdmin
      .from('payment_proofs')
      .update(updateData)
      .eq('id', payment_proof_id)
      .select()
      .single()

    if (updateError) {
      console.error('Error updating payment proof:', updateError)
      return new Response(
        JSON.stringify({ error: 'Failed to update payment proof. Please try again.' }),
        { status: 500, headers: corsHeaders }
      )
    }

    // If approved, activate the associated subscription
    if (action === 'approve') {
      const { data: subscription } = await supabaseAdmin
        .from('payment_proofs')
        .select('subscription_id')
        .eq('id', payment_proof_id)
        .single()

      if (subscription?.subscription_id) {
        await supabaseAdmin
          .from('subscriptions')
          .update({
            status: 'active',
            updated_at: new Date().toISOString()
          })
          .eq('id', subscription.subscription_id)
      }
    }

    // SECURITY: Audit logging - Track all admin actions
    const clientIp = req.headers.get('x-forwarded-for') || req.headers.get('x-real-ip') || 'unknown'
    const userAgent = req.headers.get('user-agent') || 'unknown'

    await supabaseAdmin.from('admin_audit_log').insert({
      admin_id: user.id,
      action_type: action === 'approve' ? 'approve_payment' : 'reject_payment',
      target_id: payment_proof_id,
      target_type: 'payment_proof',
      old_values: { status: existingProof.status },
      new_values: {
        status: newStatus,
        rejection_reason: rejection_reason || null,
        admin_notes: admin_notes || null
      },
      ip_address: clientIp,
      user_agent: userAgent,
      notes: rejection_reason || admin_notes || null,
    })

    // Log admin action for monitoring
    console.log(`Admin ${user.id} ${action}d payment proof ${payment_proof_id} for user ${existingProof.user_id}`)

    return new Response(
      JSON.stringify({
        success: true,
        data: updatedProof,
        message: `Payment ${action}d successfully`
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
