import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const CLOUDFLARE_ACCOUNT_ID = Deno.env.get('CLOUDFLARE_ACCOUNT_ID');
const CLOUDFLARE_API_TOKEN = Deno.env.get('CLOUDFLARE_API_TOKEN');
const CLOUDFLARE_API_URL = 'https://api.cloudflare.com/client/v4';
const CLOUDFLARE_CUSTOMER_SUBDOMAIN = 'customer-vegvgpl31x9ap217.cloudflarestream.com';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface RequestBody {
  action: string;
  [key: string]: any;
}

Deno.serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    // Verify authentication
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      throw new Error('Missing authorization header');
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      { global: { headers: { Authorization: authHeader } } }
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      throw new Error('Unauthorized');
    }

    const { action, ...params }: RequestBody = await req.json();

    // Check admin access for admin-only operations
    const adminOnlyActions = ['create_live_input', 'delete_live_input'];
    if (adminOnlyActions.includes(action)) {
      const { data: profile } = await supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();

      if (!profile || profile.role !== 'admin') {
        throw new Error('Admin access required');
      }
    }

    switch (action) {
      case 'create_live_input': {
        const { title } = params;
        const url = `${CLOUDFLARE_API_URL}/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/live_inputs`;

        const response = await fetch(url, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${CLOUDFLARE_API_TOKEN}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            meta: { name: title },
            recording: {
              mode: 'automatic',
              timeoutSeconds: 300,
              requireSignedURLs: false,
            },
          }),
        });

        const data = await response.json();
        if (!response.ok || !data.success) {
          throw new Error(data.errors?.[0]?.message || 'Failed to create live input');
        }

        const result = data.result;
        return new Response(
          JSON.stringify({
            success: true,
            liveInput: {
              uid: result.uid,
              streamKey: result.rtmps.streamKey,
              rtmpUrl: result.rtmps.url,
              hlsUrl: `https://${CLOUDFLARE_CUSTOMER_SUBDOMAIN}/${result.uid}/manifest/video.m3u8`,
              webRtcUrl: result.webRTC?.url,
            },
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'get_live_input_status': {
        const { uid } = params;
        const url = `${CLOUDFLARE_API_URL}/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/live_inputs/${uid}`;

        const response = await fetch(url, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${CLOUDFLARE_API_TOKEN}`,
            'Content-Type': 'application/json',
          },
        });

        const data = await response.json();
        if (!response.ok || !data.success) {
          throw new Error(data.errors?.[0]?.message || 'Failed to get live input status');
        }

        return new Response(
          JSON.stringify({ success: true, status: data.result }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'get_recordings': {
        const { liveInputUid } = params;
        const url = `${CLOUDFLARE_API_URL}/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/live_inputs/${liveInputUid}/videos`;

        const response = await fetch(url, {
          method: 'GET',
          headers: {
            'Authorization': `Bearer ${CLOUDFLARE_API_TOKEN}`,
            'Content-Type': 'application/json',
          },
        });

        const data = await response.json();
        if (!response.ok || !data.success) {
          throw new Error(data.errors?.[0]?.message || 'Failed to get recordings');
        }

        return new Response(
          JSON.stringify({ success: true, recordings: data.result || [] }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'delete_live_input': {
        const { uid } = params;
        const url = `${CLOUDFLARE_API_URL}/accounts/${CLOUDFLARE_ACCOUNT_ID}/stream/live_inputs/${uid}`;

        const response = await fetch(url, {
          method: 'DELETE',
          headers: {
            'Authorization': `Bearer ${CLOUDFLARE_API_TOKEN}`,
          },
        });

        if (!response.ok) {
          const data = await response.json();
          throw new Error(data.errors?.[0]?.message || 'Failed to delete live input');
        }

        return new Response(
          JSON.stringify({ success: true }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      default:
        throw new Error(`Unknown action: ${action}`);
    }
  } catch (error) {
    console.error('Error:', error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
      }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
