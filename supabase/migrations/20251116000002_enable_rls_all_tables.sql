-- =====================================================
-- Enable RLS on All Tables
-- Migration: 20251116000002_enable_rls_all_tables
-- Created: 2025-11-16
-- Description: Enable Row Level Security on all tables for proper access control
-- =====================================================

-- Enable RLS on content tables (currently public read)
ALTER TABLE grades ENABLE ROW LEVEL SECURITY;
ALTER TABLE subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE topics ENABLE ROW LEVEL SECURITY;
ALTER TABLE lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE videos ENABLE ROW LEVEL SECURITY;

-- Enable RLS on session and access tables
ALTER TABLE live_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription_access ENABLE ROW LEVEL SECURITY;
ALTER TABLE encryption_keys ENABLE ROW LEVEL SECURITY;

-- Create public read policies for content tables (students can view all active content)
CREATE POLICY "Anyone can view active grades"
  ON grades FOR SELECT
  USING (is_active = true);

CREATE POLICY "Anyone can view active subjects"
  ON subjects FOR SELECT
  USING (is_active = true);

CREATE POLICY "Anyone can view active topics"
  ON topics FOR SELECT
  USING (is_active = true);

CREATE POLICY "Anyone can view active lessons"
  ON lessons FOR SELECT
  USING (is_active = true);

CREATE POLICY "Anyone can view videos"
  ON videos FOR SELECT
  USING (true);

-- Live sessions policies
CREATE POLICY "Anyone can view scheduled/live sessions"
  ON live_sessions FOR SELECT
  USING (status IN ('scheduled', 'live'));

CREATE POLICY "Teachers can manage their sessions"
  ON live_sessions FOR ALL
  USING (teacher_id = auth.uid());

-- Admin policies for content management
CREATE POLICY "Admins can manage grades"
  ON grades FOR ALL
  USING (is_admin());

CREATE POLICY "Admins can manage subjects"
  ON subjects FOR ALL
  USING (is_admin());

CREATE POLICY "Admins can manage topics"
  ON topics FOR ALL
  USING (is_admin());

CREATE POLICY "Admins can manage lessons"
  ON lessons FOR ALL
  USING (is_admin());

CREATE POLICY "Admins can manage videos"
  ON videos FOR ALL
  USING (is_admin());

-- Encryption keys - only admins can access
CREATE POLICY "Only admins can view encryption keys"
  ON encryption_keys FOR SELECT
  USING (is_admin());

CREATE POLICY "Only admins can manage encryption keys"
  ON encryption_keys FOR ALL
  USING (is_admin());

-- Subscription access - users can view their own access
CREATE POLICY "Users can view their subscription access"
  ON subscription_access FOR SELECT
  USING (
    subscription_id IN (
      SELECT id FROM subscriptions WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "Admins can manage subscription access"
  ON subscription_access FOR ALL
  USING (is_admin());

COMMENT ON POLICY "Anyone can view active grades" ON grades IS 'Public read access to active grades';
COMMENT ON POLICY "Anyone can view active subjects" ON subjects IS 'Public read access to active subjects';
COMMENT ON POLICY "Anyone can view active topics" ON topics IS 'Public read access to active topics';
COMMENT ON POLICY "Anyone can view active lessons" ON lessons IS 'Public read access to active lessons';
COMMENT ON POLICY "Anyone can view videos" ON videos IS 'Public read access to all videos';
