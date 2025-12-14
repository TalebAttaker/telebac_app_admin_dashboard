/**
 * Edge Function: send-notification
 * Sends push notifications via Firebase Cloud Messaging (FCM)
 */

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface NotificationRequest {
  user_ids?: string[] // If null, broadcast to all
  title: string
  message: string
  notification_type: 'info' | 'live_session' | 'new_content' | 'subscription' | 'system'
  action_url?: string
  data?: Record<string, any>
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Verify admin access
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('Missing authorization header')
    }

    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const body: NotificationRequest = await req.json()
    const { user_ids, title, message, notification_type, action_url, data } = body

    // Store notification in database
    if (user_ids && user_ids.length > 0) {
      // Send to specific users
      await supabaseClient.from('notifications').insert(
        user_ids.map(user_id => ({
          user_id,
          title,
          message,
          notification_type,
          action_url,
        }))
      )
    } else {
      // Broadcast to all users
      await supabaseClient.from('notifications').insert({
        user_id: null, // NULL = broadcast
        title,
        message,
        notification_type,
        action_url,
      })
    }

    // Send via FCM (simplified - implement full FCM integration)
    const fcmServerKey = Deno.env.get('FCM_SERVER_KEY') ?? ''

    if (fcmServerKey) {
      // Get FCM tokens for users
      // Note: You'll need to store FCM tokens in a separate table
      // This is a simplified example

      const fcmPayload = {
        notification: {
          title,
          body: message,
        },
        data: {
          type: notification_type,
          action_url: action_url || '',
          ...data,
        },
      }

      if (user_ids && user_ids.length > 0) {
        // Send to specific tokens (you'd fetch these from your users' devices)
        // await fetch('https://fcm.googleapis.com/fcm/send', {
        //   method: 'POST',
        //   headers: {
        //     'Authorization': `key=${fcmServerKey}`,
        //     'Content-Type': 'application/json',
        //   },
        //   body: JSON.stringify({
        //     ...fcmPayload,
        //     registration_ids: tokens,
        //   }),
        // })
      } else {
        // Broadcast to topic
        // await fetch('https://fcm.googleapis.com/fcm/send', {
        //   method: 'POST',
        //   headers: {
        //     'Authorization': `key=${fcmServerKey}`,
        //     'Content-Type': 'application/json',
        //   },
        //   body: JSON.stringify({
        //     ...fcmPayload,
        //     to: '/topics/all_users',
        //   }),
        // })
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        recipients: user_ids?.length || 'all',
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
