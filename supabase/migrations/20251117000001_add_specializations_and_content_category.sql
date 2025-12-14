-- Migration: Add Specializations Table and Content Category Field
-- Purpose: Support Bac D, C, A specializations and distinguish content types
-- Date: 2025-11-17

-- ============================================================================
-- PART 1: Create Specializations Table
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.specializations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL UNIQUE, -- 'D', 'C', 'A'
  name TEXT NOT NULL, -- English name
  name_ar TEXT NOT NULL, -- Arabic name
  name_fr TEXT, -- French name
  description TEXT,
  description_ar TEXT,
  color TEXT, -- Hex color for UI
  icon TEXT, -- Icon identifier
  display_order INTEGER NOT NULL DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Add indexes
CREATE INDEX idx_specializations_code ON public.specializations(code);
CREATE INDEX idx_specializations_is_active ON public.specializations(is_active);

-- Add RLS policies
ALTER TABLE public.specializations ENABLE ROW LEVEL SECURITY;

-- Allow public read access to active specializations
CREATE POLICY "Specializations are viewable by everyone"
  ON public.specializations FOR SELECT
  USING (is_active = true);

-- Only admins can modify
CREATE POLICY "Only admins can insert specializations"
  ON public.specializations FOR INSERT
  WITH CHECK (public.is_admin());

CREATE POLICY "Only admins can update specializations"
  ON public.specializations FOR UPDATE
  USING (public.is_admin());

CREATE POLICY "Only admins can delete specializations"
  ON public.specializations FOR DELETE
  USING (public.is_admin());

-- ============================================================================
-- PART 2: Add Specialization to Subjects
-- ============================================================================

ALTER TABLE public.subjects
ADD COLUMN IF NOT EXISTS specialization_id UUID REFERENCES public.specializations(id) ON DELETE SET NULL;

CREATE INDEX idx_subjects_specialization ON public.subjects(specialization_id);

-- ============================================================================
-- PART 3: Add Content Category to Lessons
-- ============================================================================

-- Add content_category field to distinguish between different document types
ALTER TABLE public.lessons
ADD COLUMN IF NOT EXISTS content_category TEXT;

-- Add check constraint for valid values
ALTER TABLE public.lessons
ADD CONSTRAINT check_content_category CHECK (
  content_category IS NULL OR
  content_category IN (
    'video_lesson',           -- دروس مرئية
    'written_lesson',         -- دروس مكتوبة
    'solved_exercise',        -- تمارين محلولة
    'solved_baccalaureate',   -- باكالوريا محلولة
    'summary'                 -- ملخصات
  )
);

CREATE INDEX idx_lessons_content_category ON public.lessons(content_category);

-- ============================================================================
-- PART 4: Insert Specializations Data
-- ============================================================================

INSERT INTO public.specializations (code, name, name_ar, name_fr, description_ar, color, display_order) VALUES
('D', 'Experimental Sciences', 'العلوم التجريبية', 'Sciences Expérimentales', 'تخصص العلوم التجريبية (Bac D) - يشمل العلوم الطبيعية والفيزياء والكيمياء', '#4CAF50', 1),
('C', 'Mathematics', 'الرياضيات', 'Mathématiques', 'تخصص الرياضيات (Bac C) - يركز على الرياضيات والفيزياء', '#2196F3', 2),
('A', 'Arts & Literature', 'الآداب', 'Lettres et Arts', 'تخصص الآداب (Bac A) - يشمل الأدب واللغات والعلوم الإنسانية', '#FF9800', 3)
ON CONFLICT (code) DO NOTHING;

-- ============================================================================
-- PART 5: Data Migration - Update existing lessons with content_category
-- ============================================================================

-- Video lessons
UPDATE public.lessons
SET content_category = 'video_lesson'
WHERE lesson_type = 'video' AND content_category IS NULL;

-- Document lessons (default to written_lesson if not specified)
UPDATE public.lessons
SET content_category = 'written_lesson'
WHERE lesson_type = 'document' AND content_category IS NULL;

-- ============================================================================
-- PART 6: Add Comments for Documentation
-- ============================================================================

COMMENT ON TABLE public.specializations IS 'Academic specializations/branches for secondary school (Bac D, C, A)';
COMMENT ON COLUMN public.subjects.specialization_id IS 'Optional specialization - only for subjects in grades that have specializations';
COMMENT ON COLUMN public.lessons.content_category IS 'Categorizes document lessons into: written_lesson, solved_exercise, solved_baccalaureate, summary';

-- ============================================================================
-- PART 7: Create Helper Function to Get Content by Category
-- ============================================================================

CREATE OR REPLACE FUNCTION public.get_lessons_by_content_category(
  p_topic_id UUID,
  p_content_category TEXT
)
RETURNS TABLE (
  id UUID,
  title TEXT,
  title_ar TEXT,
  description TEXT,
  display_order INTEGER,
  duration_minutes INTEGER,
  is_free BOOLEAN,
  views_count INTEGER,
  lesson_type TEXT,
  content_category TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT
    l.id,
    l.title,
    l.title_ar,
    l.description,
    l.display_order,
    l.duration_minutes,
    l.is_free,
    l.views_count,
    l.lesson_type,
    l.content_category
  FROM public.lessons l
  WHERE l.topic_id = p_topic_id
    AND l.is_active = true
    AND (
      (p_content_category = 'video_lesson' AND l.lesson_type = 'video') OR
      (p_content_category IN ('written_lesson', 'solved_exercise', 'solved_baccalaureate', 'summary')
       AND l.lesson_type = 'document'
       AND l.content_category = p_content_category)
    )
  ORDER BY l.display_order, l.created_at;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.get_lessons_by_content_category TO authenticated, anon;

COMMENT ON FUNCTION public.get_lessons_by_content_category IS 'Retrieves lessons filtered by topic and content category';
