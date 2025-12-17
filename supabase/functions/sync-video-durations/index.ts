import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// BunnyCDN Configuration
const BUNNY_VIDEO_LIBRARY_ID = "543524";
const BUNNY_API_KEY = "7731ce2a-2e9e-47ea-847035d2b46d-bd74-4dc0";
const BUNNY_API_URL = `https://video.bunnycdn.com/library/${BUNNY_VIDEO_LIBRARY_ID}`;

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    // Create Supabase client with service role
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Get all videos with suspicious duration (<=5 seconds)
    // This catches both duration_seconds = 0 and = 1 (placeholder values)
    const { data: videos, error: fetchError } = await supabase
      .from("videos")
      .select("id, bunny_video_id, duration_seconds")
      .lte("duration_seconds", 5);

    if (fetchError) {
      throw new Error(`Failed to fetch videos: ${fetchError.message}`);
    }

    if (!videos || videos.length === 0) {
      return new Response(
        JSON.stringify({ message: "No videos with suspicious duration found", updated: 0 }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${videos.length} videos with duration ≤ 5 seconds`);

    let updatedCount = 0;
    let skippedCount = 0;
    let failedCount = 0;
    const results: Array<{ id: string; bunnyId: string; oldDuration: number; newDuration: number | null; error?: string }> = [];

    // Fetch duration from BunnyCDN for each video
    for (const video of videos) {
      try {
        const bunnyResponse = await fetch(
          `${BUNNY_API_URL}/videos/${video.bunny_video_id}`,
          {
            headers: {
              "AccessKey": BUNNY_API_KEY,
              "Accept": "application/json",
            },
          }
        );

        if (!bunnyResponse.ok) {
          console.error(`Failed to fetch video ${video.bunny_video_id}: ${bunnyResponse.status}`);
          results.push({
            id: video.id,
            bunnyId: video.bunny_video_id,
            oldDuration: video.duration_seconds,
            newDuration: null,
            error: `HTTP ${bunnyResponse.status}`
          });
          failedCount++;
          continue;
        }

        const bunnyVideo = await bunnyResponse.json();
        const durationSeconds = Math.round(bunnyVideo.length || 0);
        const status = bunnyVideo.status; // 0=created, 1=uploaded, 2=processing, 3=transcoding, 4=finished, 5=error

        console.log(`Video ${video.bunny_video_id}: old=${video.duration_seconds}s, new=${durationSeconds}s, status=${status}`);

        // Only update if:
        // 1. Duration is > 5 seconds (actual video content)
        // 2. Different from current duration
        if (durationSeconds > 5 && durationSeconds !== video.duration_seconds) {
          const { error: updateError } = await supabase
            .from("videos")
            .update({ duration_seconds: durationSeconds })
            .eq("id", video.id);

          if (updateError) {
            console.error(`Failed to update video ${video.id}: ${updateError.message}`);
            results.push({
              id: video.id,
              bunnyId: video.bunny_video_id,
              oldDuration: video.duration_seconds,
              newDuration: durationSeconds,
              error: updateError.message
            });
            failedCount++;
          } else {
            results.push({
              id: video.id,
              bunnyId: video.bunny_video_id,
              oldDuration: video.duration_seconds,
              newDuration: durationSeconds
            });
            updatedCount++;
            console.log(`✅ Updated video ${video.bunny_video_id}: ${video.duration_seconds}s → ${durationSeconds}s`);
          }
        } else if (durationSeconds <= 5) {
          // Video still processing or very short
          results.push({
            id: video.id,
            bunnyId: video.bunny_video_id,
            oldDuration: video.duration_seconds,
            newDuration: durationSeconds,
            error: `Duration still ≤5s (status: ${status})`
          });
          skippedCount++;
        } else {
          // Same duration, skip
          skippedCount++;
        }
      } catch (err) {
        console.error(`Error processing video ${video.bunny_video_id}:`, err);
        results.push({
          id: video.id,
          bunnyId: video.bunny_video_id,
          oldDuration: video.duration_seconds,
          newDuration: null,
          error: String(err)
        });
        failedCount++;
      }
    }

    return new Response(
      JSON.stringify({
        message: `Sync completed`,
        total: videos.length,
        updated: updatedCount,
        skipped: skippedCount,
        failed: failedCount,
        results: results,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    console.error("Sync error:", error);
    return new Response(
      JSON.stringify({ error: String(error) }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
