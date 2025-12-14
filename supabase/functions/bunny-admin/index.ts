import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from 'jsr:@supabase/supabase-js@2';

const BUNNY_API_KEY = Deno.env.get('BUNNY_API_KEY');
const BUNNY_LIBRARY_ID = Deno.env.get('BUNNY_LIBRARY_ID');
const BUNNY_STREAM_API = 'https://video.bunnycdn.com';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
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

    // Check if user is admin
    const { data: profile } = await supabase
      .from('profiles')
      .select('role')
      .eq('id', user.id)
      .single();

    if (!profile || profile.role !== 'admin') {
      throw new Error('Admin access required');
    }

    const { action, ...params }: RequestBody = await req.json();

    switch (action) {
      case 'create_video': {
        const { title, collectionId } = params;
        const response = await fetch(`${BUNNY_STREAM_API}/library/${BUNNY_LIBRARY_ID}/videos`, {
          method: 'POST',
          headers: {
            'AccessKey': BUNNY_API_KEY!,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            title,
            collectionId,
          }),
        });

        const data = await response.json();
        if (!response.ok) {
          throw new Error(data.Message || 'Failed to create video');
        }

        return new Response(
          JSON.stringify({ success: true, videoId: data.guid }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'get_upload_url': {
        const { videoId } = params;
        // BunnyCDN provides direct upload URL
        const uploadUrl = `${BUNNY_STREAM_API}/library/${BUNNY_LIBRARY_ID}/videos/${videoId}`;

        return new Response(
          JSON.stringify({
            success: true,
            uploadUrl,
            authKey: BUNNY_API_KEY,
            libraryId: BUNNY_LIBRARY_ID,
          }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'delete_video': {
        const { videoId } = params;
        const response = await fetch(
          `${BUNNY_STREAM_API}/library/${BUNNY_LIBRARY_ID}/videos/${videoId}`,
          {
            method: 'DELETE',
            headers: { 'AccessKey': BUNNY_API_KEY! },
          }
        );

        if (!response.ok) {
          const data = await response.json();
          throw new Error(data.Message || 'Failed to delete video');
        }

        return new Response(
          JSON.stringify({ success: true }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'get_video_info': {
        const { videoId } = params;
        const response = await fetch(
          `${BUNNY_STREAM_API}/library/${BUNNY_LIBRARY_ID}/videos/${videoId}`,
          {
            method: 'GET',
            headers: { 'AccessKey': BUNNY_API_KEY! },
          }
        );

        const data = await response.json();
        if (!response.ok) {
          throw new Error(data.Message || 'Failed to get video info');
        }

        return new Response(
          JSON.stringify({ success: true, data }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'list_collections': {
        const response = await fetch(
          `${BUNNY_STREAM_API}/library/${BUNNY_LIBRARY_ID}/collections?page=1&itemsPerPage=1000`,
          {
            method: 'GET',
            headers: { 'AccessKey': BUNNY_API_KEY! },
          }
        );

        const data = await response.json();
        if (!response.ok) {
          throw new Error(data.Message || 'Failed to list collections');
        }

        return new Response(
          JSON.stringify({ success: true, collections: data.items || [] }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      case 'create_collection': {
        const { name } = params;
        const response = await fetch(
          `${BUNNY_STREAM_API}/library/${BUNNY_LIBRARY_ID}/collections`,
          {
            method: 'POST',
            headers: {
              'AccessKey': BUNNY_API_KEY!,
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({ name }),
          }
        );

        const data = await response.json();
        if (!response.ok) {
          throw new Error(data.Message || 'Failed to create collection');
        }

        return new Response(
          JSON.stringify({ success: true, collectionId: data.guid }),
          { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        );
      }

      default:
        throw new Error(`Unknown action: ${action}`);
    }
  } catch (error) {
    console.error('[BUNNY-ADMIN] Error:', error);
    console.error('[BUNNY-ADMIN] Error stack:', error instanceof Error ? error.stack : 'N/A');
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : 'Unknown error',
        details: error instanceof Error ? error.stack : String(error),
      }),
      {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    );
  }
});
