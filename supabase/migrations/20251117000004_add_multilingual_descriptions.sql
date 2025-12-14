-- =====================================================
-- Add Multilingual Description Columns
-- Migration: 20251117000004_add_multilingual_descriptions
-- Created: 2025-11-17
-- Description: Add description_ar and description_fr columns to topics, lessons, and subjects
-- Issue: Admin panel was getting error "Could not find the 'description_ar' column"
-- Cause: Flutter code expected multilingual description fields but database only had 'description'
-- =====================================================

-- Add multilingual description columns to topics table
ALTER TABLE public.topics
  ADD COLUMN IF NOT EXISTS description_ar TEXT,
  ADD COLUMN IF NOT EXISTS description_fr TEXT;

COMMENT ON COLUMN public.topics.description_ar IS 'Arabic description of the topic';
COMMENT ON COLUMN public.topics.description_fr IS 'French description of the topic';

-- Add multilingual description columns to lessons table
ALTER TABLE public.lessons
  ADD COLUMN IF NOT EXISTS description_ar TEXT,
  ADD COLUMN IF NOT EXISTS description_fr TEXT;

COMMENT ON COLUMN public.lessons.description_ar IS 'Arabic description of the lesson';
COMMENT ON COLUMN public.lessons.description_fr IS 'French description of the lesson';

-- Add multilingual description columns to subjects table
ALTER TABLE public.subjects
  ADD COLUMN IF NOT EXISTS description_ar TEXT,
  ADD COLUMN IF NOT EXISTS description_fr TEXT;

COMMENT ON COLUMN public.subjects.description_ar IS 'Arabic description of the subject';
COMMENT ON COLUMN public.subjects.description_fr IS 'French description of the subject';

-- Verification comment
-- All content tables now have consistent multilingual support:
-- - name, name_ar, name_fr
-- - description, description_ar, description_fr
