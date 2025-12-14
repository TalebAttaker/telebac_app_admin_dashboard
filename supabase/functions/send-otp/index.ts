// Supabase Edge Function: Send OTP via Hypersender WhatsApp
// This function acts as a secure proxy to send OTP codes

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from "../_shared/cors.ts"

interface SendOTPRequest {
  phoneNumber: string
  userName: string
}

interface SendOTPResponse {
  success: boolean
  otp?: string
  message?: string
  error?: string
}

// Hypersender Configuration (from environment variables for security)
const HYPERSENDER_API_KEY = Deno.env.get('HYPERSENDER_API_KEY')
const HYPERSENDER_INSTANCE_ID = Deno.env.get('HYPERSENDER_INSTANCE_ID')
const HYPERSENDER_BASE_URL = 'https://hypersender.com/api/v2'

// Validate required environment variables
if (!HYPERSENDER_API_KEY || !HYPERSENDER_INSTANCE_ID) {
  console.error('❌ Missing required environment variables: HYPERSENDER_API_KEY or HYPERSENDER_INSTANCE_ID')
}

// Generate 6-digit OTP
function generateOTP(): string {
  const otp = Math.floor(100000 + Math.random() * 900000)
  return otp.toString()
}

// Format phone number: ensure it starts with 222
function formatPhoneNumber(phone: string): string {
  let formatted = phone.replace(/[\s\-\(\)\+]/g, '')

  if (!formatted.startsWith('222')) {
    formatted = '222' + formatted
  }

  return formatted
}

// Send OTP via Hypersender WhatsApp API
async function sendOTPViaHypersender(phoneNumber: string, userName: string, otp: string): Promise<{ success: boolean; error?: string }> {
  const formattedPhone = formatPhoneNumber(phoneNumber)

  const message = `مرحبا ${userName}! 🎓
رمز التحقق الخاص بك في المعين هو: *${otp}*

Bonjour ${userName}! 🎓
Votre code de vérification El-Mouein est: *${otp}*

✨ هذا الرمز صالح لمدة 10 دقائق
✨ Ce code est valable 10 minutes

🔒 لا تشارك هذا الرمز مع أي شخص
🔒 Ne partagez ce code avec personne`

  const url = `${HYPERSENDER_BASE_URL}/instances/${HYPERSENDER_INSTANCE_ID}/messages/send`

  console.log('📱 Sending OTP to:', formattedPhone)
  console.log('🔗 API URL:', url)

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${HYPERSENDER_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: formattedPhone,
        text: message,
      }),
    })

    const responseData = await response.json()

    console.log('📡 Hypersender Response Status:', response.status)
    console.log('📡 Hypersender Response:', JSON.stringify(responseData))

    if (response.ok) {
      if (responseData.success === true || responseData.status === 'success') {
        console.log('✅ OTP sent successfully')
        return { success: true }
      } else {
        const errorMsg = responseData.message || 'Unknown error'
        console.log('❌ Hypersender returned error:', errorMsg)
        return { success: false, error: errorMsg }
      }
    } else {
      const errorMsg = responseData.message || `HTTP ${response.status}`
      console.log('❌ HTTP Error:', errorMsg)
      return { success: false, error: errorMsg }
    }
  } catch (error) {
    console.log('❌ Network Error:', error.message)
    return { success: false, error: `Network error: ${error.message}` }
  }
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { phoneNumber, userName } = await req.json() as SendOTPRequest

    // Validate input
    if (!phoneNumber || !userName) {
      return new Response(
        JSON.stringify({
          success: false,
          error: 'Missing required fields: phoneNumber and userName',
        } as SendOTPResponse),
        {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }

    // Generate OTP
    const otp = generateOTP()
    console.log('🔢 Generated OTP:', otp)

    // Send OTP via Hypersender
    const result = await sendOTPViaHypersender(phoneNumber, userName, otp)

    if (result.success) {
      return new Response(
        JSON.stringify({
          success: true,
          otp: otp, // Return OTP for verification
          message: 'OTP sent successfully',
        } as SendOTPResponse),
        {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    } else {
      return new Response(
        JSON.stringify({
          success: false,
          error: result.error || 'Failed to send OTP',
        } as SendOTPResponse),
        {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        }
      )
    }
  } catch (error) {
    console.log('❌ Function Error:', error.message)
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message,
      } as SendOTPResponse),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
