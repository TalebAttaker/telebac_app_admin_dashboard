/**
 * Edge Function: subscription-webhook
 * Handles subscription webhooks from payment providers (Stripe, Apple, Google)
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type, stripe-signature',
}

interface SubscriptionEvent {
  provider: 'stripe' | 'apple' | 'google'
  event_type: 'subscription.created' | 'subscription.updated' | 'subscription.cancelled' | 'payment.succeeded' | 'payment.failed'
  user_id: string
  subscription_id?: string
  plan_type: 'monthly' | 'quarterly' | 'yearly' | 'lifetime'
  amount?: number
  currency?: string
  transaction_id: string
  start_date?: string
  end_date?: string
  status: 'active' | 'expired' | 'cancelled' | 'pending'
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify webhook signature (simplified - implement proper verification for production)
    const webhookSecret = Deno.env.get('WEBHOOK_SECRET') ?? ''
    const signature = req.headers.get('X-Webhook-Signature') || req.headers.get('stripe-signature')

    // TODO: Implement proper signature verification for each provider

    const body: SubscriptionEvent = await req.json()
    const { provider, event_type, user_id, plan_type, transaction_id, status, start_date, end_date, amount, currency } = body

    // Create Supabase admin client (service role)
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Verify user exists
    const { data: user } = await supabaseClient
      .from('profiles')
      .select('id')
      .eq('id', user_id)
      .single()

    if (!user) {
      throw new Error('User not found')
    }

    // Handle different event types
    switch (event_type) {
      case 'subscription.created':
      case 'payment.succeeded': {
        // Calculate end date based on plan type
        const startDateObj = start_date ? new Date(start_date) : new Date()
        let endDateObj: Date

        switch (plan_type) {
          case 'monthly':
            endDateObj = new Date(startDateObj)
            endDateObj.setMonth(endDateObj.getMonth() + 1)
            break
          case 'quarterly':
            endDateObj = new Date(startDateObj)
            endDateObj.setMonth(endDateObj.getMonth() + 3)
            break
          case 'yearly':
            endDateObj = new Date(startDateObj)
            endDateObj.setFullYear(endDateObj.getFullYear() + 1)
            break
          case 'lifetime':
            endDateObj = new Date('2099-12-31') // Far future date
            break
          default:
            throw new Error('Invalid plan type')
        }

        // Create or update subscription
        const { data: subscription, error: subError } = await supabaseClient
          .from('subscriptions')
          .upsert({
            user_id,
            plan_type,
            status: 'active',
            start_date: startDateObj.toISOString(),
            end_date: endDateObj.toISOString(),
            payment_provider: provider,
            payment_transaction_id: transaction_id,
            amount,
            currency: currency || 'MRU',
            auto_renew: true,
          })
          .select()
          .single()

        if (subError) {
          throw new Error(`Failed to create subscription: ${subError.message}`)
        }

        // Grant access to all grades (full platform access)
        // In production, you might want granular access based on plan
        const { data: grades } = await supabaseClient
          .from('grades')
          .select('id')

        if (grades && grades.length > 0) {
          await supabaseClient
            .from('subscription_access')
            .upsert(
              grades.map(grade => ({
                subscription_id: subscription.id,
                grade_id: grade.id,
              }))
            )
        }

        // Send notification
        await supabaseClient.from('notifications').insert({
          user_id,
          title: 'Subscription Activated',
          message: `Your ${plan_type} subscription is now active!`,
          notification_type: 'subscription',
        })

        break
      }

      case 'subscription.cancelled': {
        // Mark subscription as cancelled
        await supabaseClient
          .from('subscriptions')
          .update({ status: 'cancelled', auto_renew: false })
          .eq('user_id', user_id)
          .eq('payment_transaction_id', transaction_id)

        // Send notification
        await supabaseClient.from('notifications').insert({
          user_id,
          title: 'Subscription Cancelled',
          message: 'Your subscription has been cancelled. You can still access content until the end of your billing period.',
          notification_type: 'subscription',
        })

        break
      }

      case 'payment.failed': {
        // Mark subscription as pending
        await supabaseClient
          .from('subscriptions')
          .update({ status: 'pending' })
          .eq('user_id', user_id)
          .eq('payment_transaction_id', transaction_id)

        // Send notification
        await supabaseClient.from('notifications').insert({
          user_id,
          title: 'Payment Failed',
          message: 'Your payment failed. Please update your payment method.',
          notification_type: 'subscription',
        })

        break
      }
    }

    return new Response(
      JSON.stringify({ success: true, event_type }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )
  } catch (error) {
    console.error('Webhook error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})
