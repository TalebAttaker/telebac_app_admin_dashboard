-- =====================================================
-- Restructure Videos to Link Directly to Topics
-- Migration: 20251117000005_restructure_videos_direct_to_topics
-- Created: 2025-11-17
-- Description: Simplify content hierarchy by removing intermediate "lessons" layer
-- Videos ARE the actual lessons now, linked directly to topics
-- =====================================================

-- Background:
-- Old model: grades → subjects → topics → lessons → videos
-- New model: grades → subjects → topics → videos (directly)
--
-- Rationale:
-- - Videos are the actual lesson content
-- - Having an intermediate "lessons" table was redundant
-- - Simplifies admin UX: Grade → Subject → Topic → Upload Video

-- Step 1: Add new columns to videos table to make them self-contained lessons
ALTER TABLE public.videos
  -- Direct link to topics (bypass lessons)
  ADD COLUMN IF NOT EXISTS topic_id UUID REFERENCES topics(id) ON DELETE CASCADE,

  -- Lesson metadata (videos ARE lessons now)
  ADD COLUMN IF NOT EXISTS title TEXT,
  ADD COLUMN IF NOT EXISTS title_ar TEXT,
  ADD COLUMN IF NOT EXISTS title_fr TEXT,
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS description_ar TEXT,
  ADD COLUMN IF NOT EXISTS description_fr TEXT,
  ADD COLUMN IF NOT EXISTS display_order INTEGER DEFAULT 1,
  ADD COLUMN IF NOT EXISTS is_free BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0;

-- Step 2: Make lesson_id nullable for backward compatibility
ALTER TABLE public.videos
  ALTER COLUMN lesson_id DROP NOT NULL;

-- Step 3: Add helpful comments
COMMENT ON COLUMN public.videos.topic_id IS 'Direct link to topic - videos belong to topics now, not lessons';
COMMENT ON COLUMN public.videos.title IS 'Video/Lesson title in English';
COMMENT ON COLUMN public.videos.title_ar IS 'Video/Lesson title in Arabic (primary)';
COMMENT ON COLUMN public.videos.title_fr IS 'Video/Lesson title in French';
COMMENT ON COLUMN public.videos.description IS 'Video/Lesson description in English';
COMMENT ON COLUMN public.videos.description_ar IS 'Video/Lesson description in Arabic';
COMMENT ON COLUMN public.videos.description_fr IS 'Video/Lesson description in French';
COMMENT ON COLUMN public.videos.display_order IS 'Display order of videos within a topic';
COMMENT ON COLUMN public.videos.is_free IS 'Whether this video lesson is free or requires subscription';
COMMENT ON COLUMN public.videos.views_count IS 'Number of times this video has been viewed';

-- Step 4: Clean up empty lessons (lessons with no videos)
DELETE FROM public.lessons
WHERE id NOT IN (
  SELECT DISTINCT lesson_id
  FROM public.videos
  WHERE lesson_id IS NOT NULL
);

-- Note: The lessons table is kept for now but may be deprecated in future
-- New videos will use topic_id directly
-- Existing videos (if any) can continue using lesson_id for backward compatibility
