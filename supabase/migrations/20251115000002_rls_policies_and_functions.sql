-- =====================================================
-- Educational Platform - RLS Policies and Functions
-- Migration: 20251115000002_rls_policies_and_functions
-- Created: 2025-11-15
-- Description: Row Level Security policies, helper functions, and triggers
-- =====================================================

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

-- Function: Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_updated_at_column IS 'Automatically updates updated_at column on row update';

-- Function: Increment lesson views
CREATE OR REPLACE FUNCTION increment_views(lesson_id_param UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE lessons
  SET views_count = views_count + 1
  WHERE id = lesson_id_param;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION increment_views IS 'Increments view count for a lesson';

-- Function: Check if user has active subscription
CREATE OR REPLACE FUNCTION check_subscription(user_id_param UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM subscriptions
    WHERE user_id = user_id_param
      AND status = 'active'
      AND (end_date IS NULL OR end_date > NOW())
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION check_subscription IS 'Returns true if user has active subscription';

-- Function: Upsert watch history
CREATE OR REPLACE FUNCTION upsert_watch_history(
  p_user_id UUID,
  p_lesson_id UUID,
  p_video_id UUID,
  p_position_seconds INTEGER,
  p_duration_seconds INTEGER
)
RETURNS VOID AS $$
DECLARE
  completion DECIMAL(5,2);
BEGIN
  -- Calculate completion percentage
  IF p_duration_seconds > 0 THEN
    completion := (p_position_seconds::DECIMAL / p_duration_seconds::DECIMAL) * 100;
    IF completion > 100 THEN
      completion := 100;
    END IF;
  ELSE
    completion := 0;
  END IF;

  INSERT INTO user_progress (
    user_id,
    lesson_id,
    video_id,
    watched_duration_seconds,
    total_duration_seconds,
    completion_percentage,
    is_completed,
    last_watched_position_seconds,
    last_watched_at
  )
  VALUES (
    p_user_id,
    p_lesson_id,
    p_video_id,
    p_position_seconds,
    p_duration_seconds,
    completion,
    completion >= 90, -- Consider completed if 90%+ watched
    p_position_seconds,
    NOW()
  )
  ON CONFLICT (user_id, lesson_id)
  DO UPDATE SET
    watched_duration_seconds = GREATEST(user_progress.watched_duration_seconds, p_position_seconds),
    total_duration_seconds = p_duration_seconds,
    completion_percentage = completion,
    is_completed = completion >= 90,
    last_watched_position_seconds = p_position_seconds,
    last_watched_at = NOW(),
    completed_at = CASE
      WHEN completion >= 90 AND user_progress.completed_at IS NULL THEN NOW()
      ELSE user_progress.completed_at
    END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION upsert_watch_history IS 'Updates or inserts user watch progress';

-- Function: Check user access to lesson
CREATE OR REPLACE FUNCTION can_access_lesson(
  p_user_id UUID,
  p_lesson_id UUID
)
RETURNS BOOLEAN AS $$
DECLARE
  lesson_free BOOLEAN;
  user_subscribed BOOLEAN;
BEGIN
  -- Check if lesson is free
  SELECT is_free INTO lesson_free
  FROM lessons
  WHERE id = p_lesson_id;

  IF lesson_free THEN
    RETURN true;
  END IF;

  -- Check if user has active subscription
  user_subscribed := check_subscription(p_user_id);

  RETURN user_subscribed;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION can_access_lesson IS 'Checks if user can access a lesson (free or subscribed)';

-- =====================================================
-- TRIGGERS
-- =====================================================

-- Trigger: Auto-update updated_at for profiles
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Auto-update updated_at for grades
CREATE TRIGGER update_grades_updated_at
  BEFORE UPDATE ON grades
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Auto-update updated_at for subjects
CREATE TRIGGER update_subjects_updated_at
  BEFORE UPDATE ON subjects
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Auto-update updated_at for topics
CREATE TRIGGER update_topics_updated_at
  BEFORE UPDATE ON topics
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Auto-update updated_at for lessons
CREATE TRIGGER update_lessons_updated_at
  BEFORE UPDATE ON lessons
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Auto-update updated_at for videos
CREATE TRIGGER update_videos_updated_at
  BEFORE UPDATE ON videos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Auto-update updated_at for subscriptions
CREATE TRIGGER update_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Auto-update updated_at for live_sessions
CREATE TRIGGER update_live_sessions_updated_at
  BEFORE UPDATE ON live_sessions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger: Update subscription status on expiry
CREATE OR REPLACE FUNCTION update_subscription_status()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.end_date IS NOT NULL AND NEW.end_date < NOW() AND NEW.status = 'active' THEN
    NEW.status := 'expired';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_subscription_expiry
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_subscription_status();

-- Trigger: Calculate live session duration on end
CREATE OR REPLACE FUNCTION calculate_session_duration()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.left_at IS NOT NULL AND OLD.left_at IS NULL THEN
    NEW.duration_minutes := EXTRACT(EPOCH FROM (NEW.left_at - NEW.joined_at)) / 60;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_attendance_duration
  BEFORE UPDATE ON live_session_attendance
  FOR EACH ROW EXECUTE FUNCTION calculate_session_duration();

-- =====================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- =====================================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE downloaded_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE live_session_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_events ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- PROFILES POLICIES
-- =====================================================

-- Users can view their own profile
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Admins can view all profiles
CREATE POLICY "Admins can view all profiles"
  ON profiles FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can update all profiles
CREATE POLICY "Admins can update all profiles"
  ON profiles FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- =====================================================
-- DOWNLOADED VIDEOS POLICIES
-- =====================================================

-- Users can view their own downloads
CREATE POLICY "Users can view own downloads"
  ON downloaded_videos FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own downloads
CREATE POLICY "Users can insert own downloads"
  ON downloaded_videos FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own downloads
CREATE POLICY "Users can update own downloads"
  ON downloaded_videos FOR UPDATE
  USING (auth.uid() = user_id);

-- Users can delete their own downloads
CREATE POLICY "Users can delete own downloads"
  ON downloaded_videos FOR DELETE
  USING (auth.uid() = user_id);

-- =====================================================
-- SUBSCRIPTIONS POLICIES
-- =====================================================

-- Users can view their own subscriptions
CREATE POLICY "Users can view own subscriptions"
  ON subscriptions FOR SELECT
  USING (auth.uid() = user_id);

-- Admins can view all subscriptions
CREATE POLICY "Admins can view all subscriptions"
  ON subscriptions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- Admins can manage all subscriptions
CREATE POLICY "Admins can manage subscriptions"
  ON subscriptions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- =====================================================
-- USER PROGRESS POLICIES
-- =====================================================

-- Users can view their own progress
CREATE POLICY "Users can view own progress"
  ON user_progress FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own progress
CREATE POLICY "Users can insert own progress"
  ON user_progress FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own progress
CREATE POLICY "Users can update own progress"
  ON user_progress FOR UPDATE
  USING (auth.uid() = user_id);

-- Admins can view all progress
CREATE POLICY "Admins can view all progress"
  ON user_progress FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- =====================================================
-- NOTIFICATIONS POLICIES
-- =====================================================

-- Users can view their own notifications (or broadcast notifications)
CREATE POLICY "Users can view own notifications"
  ON notifications FOR SELECT
  USING (auth.uid() = user_id OR user_id IS NULL);

-- Users can update their own notifications (mark as read)
CREATE POLICY "Users can update own notifications"
  ON notifications FOR UPDATE
  USING (auth.uid() = user_id);

-- Admins can create notifications
CREATE POLICY "Admins can create notifications"
  ON notifications FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'teacher')
    )
  );

-- =====================================================
-- LIVE SESSION ATTENDANCE POLICIES
-- =====================================================

-- Users can view their own attendance
CREATE POLICY "Users can view own attendance"
  ON live_session_attendance FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own attendance
CREATE POLICY "Users can insert own attendance"
  ON live_session_attendance FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Users can update their own attendance
CREATE POLICY "Users can update own attendance"
  ON live_session_attendance FOR UPDATE
  USING (auth.uid() = user_id);

-- Teachers can view attendance for their sessions
CREATE POLICY "Teachers can view session attendance"
  ON live_session_attendance FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM live_sessions ls
      WHERE ls.id = live_session_attendance.session_id
        AND ls.teacher_id = auth.uid()
    )
  );

-- Admins can view all attendance
CREATE POLICY "Admins can view all attendance"
  ON live_session_attendance FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- =====================================================
-- ANALYTICS EVENTS POLICIES
-- =====================================================

-- Users can insert their own events
CREATE POLICY "Users can insert own analytics events"
  ON analytics_events FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);

-- Admins can view all analytics
CREATE POLICY "Admins can view all analytics"
  ON analytics_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- =====================================================
-- PUBLIC READ ACCESS FOR CONTENT TABLES
-- =====================================================

-- Grades: Public read access to active grades
CREATE POLICY "Public read access to active grades"
  ON grades FOR SELECT
  USING (is_active = true);

-- Subjects: Public read access to active subjects
CREATE POLICY "Public read access to active subjects"
  ON subjects FOR SELECT
  USING (is_active = true);

-- Topics: Public read access to active topics
CREATE POLICY "Public read access to active topics"
  ON topics FOR SELECT
  USING (is_active = true);

-- Lessons: Public read access to active lessons
CREATE POLICY "Public read access to active lessons"
  ON lessons FOR SELECT
  USING (is_active = true);

-- Videos: Authenticated read access (need to check subscription in app)
CREATE POLICY "Authenticated read access to videos"
  ON videos FOR SELECT
  USING (auth.role() = 'authenticated');

-- Live Sessions: Public read access to scheduled/live sessions
CREATE POLICY "Public read access to live sessions"
  ON live_sessions FOR SELECT
  USING (status IN ('scheduled', 'live', 'ended'));

-- =====================================================
-- ADMIN WRITE ACCESS FOR CONTENT TABLES
-- =====================================================

-- Helper function: Check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grades: Admin can manage
CREATE POLICY "Admins can manage grades"
  ON grades FOR ALL
  USING (is_admin());

-- Subjects: Admin can manage
CREATE POLICY "Admins can manage subjects"
  ON subjects FOR ALL
  USING (is_admin());

-- Topics: Admin can manage
CREATE POLICY "Admins can manage topics"
  ON topics FOR ALL
  USING (is_admin());

-- Lessons: Admin can manage
CREATE POLICY "Admins can manage lessons"
  ON lessons FOR ALL
  USING (is_admin());

-- Videos: Admin can manage
CREATE POLICY "Admins can manage videos"
  ON videos FOR ALL
  USING (is_admin());

-- Live Sessions: Teachers and admins can create
CREATE POLICY "Teachers and admins can create live sessions"
  ON live_sessions FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role IN ('admin', 'teacher')
    )
  );

-- Live Sessions: Teachers can manage their own sessions
CREATE POLICY "Teachers can manage own live sessions"
  ON live_sessions FOR ALL
  USING (auth.uid() = teacher_id);

-- Live Sessions: Admins can manage all sessions
CREATE POLICY "Admins can manage all live sessions"
  ON live_sessions FOR ALL
  USING (is_admin());
