-- =====================================================
-- Educational Platform - Initial Database Schema
-- Migration: 20251115000001_initial_schema
-- Created: 2025-11-15
-- Description: Create all core tables, indexes, and RLS policies
-- =====================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =====================================================
-- TABLE: profiles (User profiles - extends auth.users)
-- =====================================================
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT NOT NULL,
  full_name TEXT,
  phone TEXT,
  avatar_url TEXT,
  role TEXT NOT NULL CHECK (role IN ('student', 'teacher', 'admin')) DEFAULT 'student',
  is_active BOOLEAN DEFAULT true,
  device_id TEXT, -- For device binding
  max_devices INTEGER DEFAULT 2, -- Max simultaneous devices
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE profiles IS 'User profiles extending Supabase auth.users';
COMMENT ON COLUMN profiles.device_id IS 'Hashed device identifier for download binding';
COMMENT ON COLUMN profiles.max_devices IS 'Maximum number of devices allowed for downloads';

-- =====================================================
-- TABLE: grades (Educational grade levels)
-- =====================================================
CREATE TABLE grades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE, -- e.g., "Grade 1", "Grade 2"
  name_ar TEXT, -- Arabic translation
  name_fr TEXT, -- French translation
  display_order INTEGER NOT NULL,
  icon_url TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE grades IS 'Educational grade levels (e.g., Grade 1, Grade 2)';

-- =====================================================
-- TABLE: subjects (Subjects within a grade)
-- =====================================================
CREATE TABLE subjects (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  grade_id UUID NOT NULL REFERENCES grades(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  name_ar TEXT,
  name_fr TEXT,
  description TEXT,
  icon_url TEXT,
  cover_image_url TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(grade_id, name)
);

COMMENT ON TABLE subjects IS 'Subjects within a grade (e.g., Mathematics, Science)';

-- =====================================================
-- TABLE: topics (Topics/chapters within a subject)
-- =====================================================
CREATE TABLE topics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subject_id UUID NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  name_ar TEXT,
  name_fr TEXT,
  description TEXT,
  display_order INTEGER NOT NULL,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE topics IS 'Topics or chapters within a subject';

-- =====================================================
-- TABLE: lessons (Individual lessons)
-- =====================================================
CREATE TABLE lessons (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  topic_id UUID NOT NULL REFERENCES topics(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  title_ar TEXT,
  title_fr TEXT,
  description TEXT,
  lesson_type TEXT NOT NULL CHECK (lesson_type IN ('video', 'live', 'document', 'quiz')) DEFAULT 'video',
  display_order INTEGER NOT NULL,
  duration_minutes INTEGER, -- Estimated duration
  is_free BOOLEAN DEFAULT false, -- Free preview
  is_active BOOLEAN DEFAULT true,
  views_count INTEGER DEFAULT 0,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE lessons IS 'Individual lessons within a topic';
COMMENT ON COLUMN lessons.is_free IS 'True if lesson is available without subscription';

-- =====================================================
-- TABLE: videos (Video content for lessons)
-- =====================================================
CREATE TABLE videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  bunny_video_id TEXT NOT NULL UNIQUE, -- BunnyCDN video library ID
  duration_seconds INTEGER NOT NULL,
  thumbnail_url TEXT,

  -- BunnyCDN HLS URLs for different resolutions
  url_360p TEXT,
  url_480p TEXT,
  url_720p TEXT,
  url_1080p TEXT,

  -- File sizes for download estimation
  size_360p_mb DECIMAL(10, 2),
  size_480p_mb DECIMAL(10, 2),
  size_720p_mb DECIMAL(10, 2),
  size_1080p_mb DECIMAL(10, 2),

  -- Encryption metadata
  encryption_key_id TEXT NOT NULL, -- Reference to key in encryption_keys table
  is_downloadable BOOLEAN DEFAULT true,

  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE videos IS 'Video content associated with lessons';
COMMENT ON COLUMN videos.bunny_video_id IS 'BunnyCDN video library unique identifier';
COMMENT ON COLUMN videos.encryption_key_id IS 'Reference to encryption key for downloads';

-- =====================================================
-- TABLE: downloaded_videos (Track encrypted downloads)
-- =====================================================
CREATE TABLE downloaded_videos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_id UUID NOT NULL REFERENCES videos(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL, -- Encrypted device identifier
  resolution TEXT NOT NULL CHECK (resolution IN ('360p', '480p', '720p', '1080p')),
  local_file_path TEXT NOT NULL, -- Encrypted storage path on device
  encryption_iv TEXT NOT NULL, -- Initialization vector for AES
  download_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  last_accessed TIMESTAMP WITH TIME ZONE,
  expiry_date TIMESTAMP WITH TIME ZONE, -- Optional expiry for rentals
  is_valid BOOLEAN DEFAULT true, -- Can be invalidated remotely
  UNIQUE(user_id, video_id, device_id, resolution)
);

COMMENT ON TABLE downloaded_videos IS 'Tracks encrypted video downloads per user and device';
COMMENT ON COLUMN downloaded_videos.device_id IS 'Hashed device fingerprint for device binding';
COMMENT ON COLUMN downloaded_videos.encryption_iv IS 'AES initialization vector for this download';
COMMENT ON COLUMN downloaded_videos.is_valid IS 'Can be set to false to remotely revoke access';

-- =====================================================
-- TABLE: live_sessions (Jitsi live streaming sessions)
-- =====================================================
CREATE TABLE live_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  lesson_id UUID REFERENCES lessons(id) ON DELETE SET NULL,
  teacher_id UUID NOT NULL REFERENCES auth.users(id),
  title TEXT NOT NULL,
  title_ar TEXT,
  title_fr TEXT,
  description TEXT,
  scheduled_start TIMESTAMP WITH TIME ZONE NOT NULL,
  scheduled_end TIMESTAMP WITH TIME ZONE NOT NULL,
  actual_start TIMESTAMP WITH TIME ZONE,
  actual_end TIMESTAMP WITH TIME ZONE,
  jitsi_room_name TEXT NOT NULL UNIQUE,
  jitsi_jwt_token TEXT, -- Pre-generated JWT for security
  max_participants INTEGER DEFAULT 1000,
  status TEXT NOT NULL CHECK (status IN ('scheduled', 'live', 'ended', 'cancelled')) DEFAULT 'scheduled',
  recording_url TEXT, -- If recorded
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE live_sessions IS 'Jitsi live streaming sessions';
COMMENT ON COLUMN live_sessions.jitsi_room_name IS 'Unique Jitsi room identifier';
COMMENT ON COLUMN live_sessions.status IS 'Current session status';

-- =====================================================
-- TABLE: live_session_attendance (Track who joined)
-- =====================================================
CREATE TABLE live_session_attendance (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES live_sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  left_at TIMESTAMP WITH TIME ZONE,
  duration_minutes INTEGER,
  UNIQUE(session_id, user_id)
);

COMMENT ON TABLE live_session_attendance IS 'Tracks attendance for live sessions';

-- =====================================================
-- TABLE: subscriptions (User subscriptions)
-- =====================================================
CREATE TABLE subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_type TEXT NOT NULL CHECK (plan_type IN ('free', 'monthly', 'quarterly', 'yearly', 'lifetime')),
  status TEXT NOT NULL CHECK (status IN ('active', 'expired', 'cancelled', 'pending')) DEFAULT 'pending',
  start_date TIMESTAMP WITH TIME ZONE NOT NULL,
  end_date TIMESTAMP WITH TIME ZONE,
  payment_provider TEXT, -- 'apple', 'google', 'stripe'
  payment_transaction_id TEXT,
  amount DECIMAL(10, 2),
  currency TEXT DEFAULT 'MRU', -- Mauritanian Ouguiya
  auto_renew BOOLEAN DEFAULT true,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE subscriptions IS 'User subscription plans and payment tracking';

-- =====================================================
-- TABLE: subscription_access (What content is accessible)
-- =====================================================
CREATE TABLE subscription_access (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  subscription_id UUID NOT NULL REFERENCES subscriptions(id) ON DELETE CASCADE,
  grade_id UUID REFERENCES grades(id) ON DELETE CASCADE,
  subject_id UUID REFERENCES subjects(id) ON DELETE CASCADE,
  -- Either grade_id OR subject_id should be set (flexible plans)
  granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  CHECK (
    (grade_id IS NOT NULL AND subject_id IS NULL) OR
    (grade_id IS NULL AND subject_id IS NOT NULL)
  )
);

COMMENT ON TABLE subscription_access IS 'Defines what content each subscription provides access to';

-- =====================================================
-- TABLE: user_progress (Track learning progress)
-- =====================================================
CREATE TABLE user_progress (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  lesson_id UUID NOT NULL REFERENCES lessons(id) ON DELETE CASCADE,
  video_id UUID REFERENCES videos(id) ON DELETE CASCADE,
  watched_duration_seconds INTEGER DEFAULT 0,
  total_duration_seconds INTEGER,
  completion_percentage DECIMAL(5, 2) DEFAULT 0.00,
  is_completed BOOLEAN DEFAULT false,
  last_watched_position_seconds INTEGER DEFAULT 0,
  last_watched_at TIMESTAMP WITH TIME ZONE,
  completed_at TIMESTAMP WITH TIME ZONE,
  UNIQUE(user_id, lesson_id)
);

COMMENT ON TABLE user_progress IS 'Tracks user progress through lessons';

-- =====================================================
-- TABLE: notifications (Push notifications log)
-- =====================================================
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- NULL for broadcast
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  notification_type TEXT NOT NULL CHECK (
    notification_type IN ('info', 'live_session', 'new_content', 'subscription', 'system')
  ),
  action_url TEXT, -- Deep link to specific content
  is_read BOOLEAN DEFAULT false,
  sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  read_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE notifications IS 'Push notifications sent to users';

-- =====================================================
-- TABLE: analytics_events (Usage analytics)
-- =====================================================
CREATE TABLE analytics_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL, -- 'video_view', 'download', 'live_join', 'search'
  event_data JSONB, -- Flexible event metadata
  device_info JSONB, -- Device type, OS, app version
  session_id TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE analytics_events IS 'Usage analytics and event tracking';

-- =====================================================
-- TABLE: encryption_keys (Secure key vault)
-- =====================================================
CREATE TABLE encryption_keys (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key_identifier TEXT NOT NULL UNIQUE,
  encrypted_key TEXT NOT NULL, -- The actual AES key, encrypted with master key
  algorithm TEXT NOT NULL DEFAULT 'AES-256-CBC',
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  rotated_at TIMESTAMP WITH TIME ZONE,
  is_active BOOLEAN DEFAULT true
);

COMMENT ON TABLE encryption_keys IS 'Secure vault for video encryption keys';
COMMENT ON COLUMN encryption_keys.encrypted_key IS 'Encryption key encrypted with master secret';

-- =====================================================
-- INDEXES FOR PERFORMANCE
-- =====================================================

-- Profiles
CREATE INDEX idx_profiles_role ON profiles(role);
CREATE INDEX idx_profiles_device_id ON profiles(device_id);
CREATE INDEX idx_profiles_email ON profiles(email);

-- Subjects
CREATE INDEX idx_subjects_grade_id ON subjects(grade_id);
CREATE INDEX idx_subjects_display_order ON subjects(grade_id, display_order);

-- Topics
CREATE INDEX idx_topics_subject_id ON topics(subject_id);
CREATE INDEX idx_topics_display_order ON topics(subject_id, display_order);

-- Lessons
CREATE INDEX idx_lessons_topic_id ON lessons(topic_id);
CREATE INDEX idx_lessons_display_order ON lessons(topic_id, display_order);
CREATE INDEX idx_lessons_is_free ON lessons(is_free);
CREATE INDEX idx_lessons_type ON lessons(lesson_type);

-- Videos
CREATE INDEX idx_videos_lesson_id ON videos(lesson_id);
CREATE INDEX idx_videos_bunny_id ON videos(bunny_video_id);

-- Downloaded Videos
CREATE INDEX idx_downloaded_videos_user_device ON downloaded_videos(user_id, device_id);
CREATE INDEX idx_downloaded_videos_video_id ON downloaded_videos(video_id);
CREATE INDEX idx_downloaded_videos_expiry ON downloaded_videos(expiry_date) WHERE expiry_date IS NOT NULL;

-- Live Sessions
CREATE INDEX idx_live_sessions_status ON live_sessions(status);
CREATE INDEX idx_live_sessions_scheduled_start ON live_sessions(scheduled_start);
CREATE INDEX idx_live_sessions_teacher ON live_sessions(teacher_id);

-- Live Session Attendance
CREATE INDEX idx_attendance_session_id ON live_session_attendance(session_id);
CREATE INDEX idx_attendance_user_id ON live_session_attendance(user_id);

-- Subscriptions
CREATE INDEX idx_subscriptions_user_status ON subscriptions(user_id, status);
CREATE INDEX idx_subscriptions_end_date ON subscriptions(end_date) WHERE status = 'active';

-- User Progress
CREATE INDEX idx_user_progress_user_lesson ON user_progress(user_id, lesson_id);
CREATE INDEX idx_user_progress_user_id ON user_progress(user_id);
CREATE INDEX idx_user_progress_completed ON user_progress(is_completed);

-- Notifications
CREATE INDEX idx_notifications_user_read ON notifications(user_id, is_read);
CREATE INDEX idx_notifications_sent_at ON notifications(sent_at DESC);

-- Analytics Events
CREATE INDEX idx_analytics_events_type_created ON analytics_events(event_type, created_at);
CREATE INDEX idx_analytics_events_user_id ON analytics_events(user_id);
CREATE INDEX idx_analytics_events_created_at ON analytics_events(created_at DESC);

-- Encryption Keys
CREATE INDEX idx_encryption_keys_identifier ON encryption_keys(key_identifier);
CREATE INDEX idx_encryption_keys_active ON encryption_keys(is_active) WHERE is_active = true;
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
-- =====================================================
-- Educational Platform - Test Data
-- Migration: 20251115000003_test_data
-- Created: 2025-11-15
-- Description: Insert sample data for testing
-- =====================================================

-- =====================================================
-- GRADES
-- =====================================================
INSERT INTO grades (id, name, name_ar, name_fr, display_order, is_active) VALUES
  ('00000000-0000-0000-0000-000000000001', 'Grade 1', 'الصف الأول', 'Classe 1', 1, true),
  ('00000000-0000-0000-0000-000000000002', 'Grade 2', 'الصف الثاني', 'Classe 2', 2, true),
  ('00000000-0000-0000-0000-000000000003', 'Grade 3', 'الصف الثالث', 'Classe 3', 3, true),
  ('00000000-0000-0000-0000-000000000004', 'Grade 4', 'الصف الرابع', 'Classe 4', 4, true),
  ('00000000-0000-0000-0000-000000000005', 'Grade 5', 'الصف الخامس', 'Classe 5', 5, true);

-- =====================================================
-- SUBJECTS
-- =====================================================
-- Grade 1 Subjects
INSERT INTO subjects (id, grade_id, name, name_ar, name_fr, description, display_order, is_active) VALUES
  ('10000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', 'Mathematics', 'الرياضيات', 'Mathématiques', 'Basic mathematics concepts', 1, true),
  ('10000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'Arabic Language', 'اللغة العربية', 'Langue Arabe', 'Arabic language fundamentals', 2, true),
  ('10000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'French Language', 'اللغة الفرنسية', 'Langue Française', 'French language basics', 3, true),
  ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000001', 'Science', 'العلوم', 'Sciences', 'Introduction to science', 4, true);

-- Grade 2 Subjects
INSERT INTO subjects (id, grade_id, name, name_ar, name_fr, description, display_order, is_active) VALUES
  ('20000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002', 'Mathematics', 'الرياضيات', 'Mathématiques', 'Intermediate mathematics', 1, true),
  ('20000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'Arabic Language', 'اللغة العربية', 'Langue Arabe', 'Arabic language development', 2, true),
  ('20000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000002', 'French Language', 'اللغة الفرنسية', 'Langue Française', 'French language intermediate', 3, true);

-- =====================================================
-- TOPICS (Grade 1 - Mathematics)
-- =====================================================
INSERT INTO topics (id, subject_id, name, name_ar, name_fr, description, display_order, is_active) VALUES
  ('30000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000001', 'Numbers 1-10', 'الأعداد من 1 إلى 10', 'Nombres 1-10', 'Learning numbers from 1 to 10', 1, true),
  ('30000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Addition & Subtraction', 'الجمع والطرح', 'Addition et Soustraction', 'Basic addition and subtraction', 2, true),
  ('30000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000001', 'Shapes & Patterns', 'الأشكال والأنماط', 'Formes et Motifs', 'Recognizing shapes and patterns', 3, true);

-- =====================================================
-- LESSONS (Numbers 1-10 Topic)
-- =====================================================
INSERT INTO lessons (id, topic_id, title, title_ar, title_fr, description, lesson_type, display_order, duration_minutes, is_free, is_active, views_count) VALUES
  ('40000000-0000-0000-0000-000000000001', '30000000-0000-0000-0000-000000000001', 'Introduction to Numbers', 'مقدمة في الأعداد', 'Introduction aux Nombres', 'Learn what numbers are', 'video', 1, 10, true, true, 0),
  ('40000000-0000-0000-0000-000000000002', '30000000-0000-0000-0000-000000000001', 'Counting 1 to 5', 'العد من 1 إلى 5', 'Compter de 1 à 5', 'Learn to count from 1 to 5', 'video', 2, 8, true, true, 0),
  ('40000000-0000-0000-0000-000000000003', '30000000-0000-0000-0000-000000000001', 'Counting 6 to 10', 'العد من 6 إلى 10', 'Compter de 6 à 10', 'Learn to count from 6 to 10', 'video', 3, 8, false, true, 0),
  ('40000000-0000-0000-0000-000000000004', '30000000-0000-0000-0000-000000000001', 'Practice Quiz', 'اختبار تدريبي', 'Quiz de Pratique', 'Test your knowledge', 'quiz', 4, 5, false, true, 0);

-- Addition & Subtraction Topic
INSERT INTO lessons (id, topic_id, title, title_ar, title_fr, description, lesson_type, display_order, duration_minutes, is_free, is_active, views_count) VALUES
  ('40000000-0000-0000-0000-000000000005', '30000000-0000-0000-0000-000000000002', 'What is Addition?', 'ما هو الجمع؟', 'Qu''est-ce que l''Addition?', 'Understanding addition', 'video', 1, 12, false, true, 0),
  ('40000000-0000-0000-0000-000000000006', '30000000-0000-0000-0000-000000000002', 'Adding Numbers 1-5', 'جمع الأعداد من 1-5', 'Additionner 1-5', 'Practice adding small numbers', 'video', 2, 15, false, true, 0);

-- =====================================================
-- ENCRYPTION KEYS (For testing - in production, generate securely)
-- =====================================================
INSERT INTO encryption_keys (id, key_identifier, encrypted_key, algorithm, is_active) VALUES
  ('50000000-0000-0000-0000-000000000001', 'test-key-001', 'ENCRYPTED_KEY_PLACEHOLDER_REPLACE_IN_PRODUCTION', 'AES-256-CBC', true);

-- =====================================================
-- VIDEOS (Sample video metadata - BunnyCDN IDs would be real in production)
-- =====================================================
INSERT INTO videos (id, lesson_id, bunny_video_id, duration_seconds, thumbnail_url, encryption_key_id, is_downloadable) VALUES
  ('60000000-0000-0000-0000-000000000001', '40000000-0000-0000-0000-000000000001', 'sample-video-001', 600, 'https://placeholder.com/thumbnail1.jpg', '50000000-0000-0000-0000-000000000001', true),
  ('60000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000002', 'sample-video-002', 480, 'https://placeholder.com/thumbnail2.jpg', '50000000-0000-0000-0000-000000000001', true),
  ('60000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000003', 'sample-video-003', 480, 'https://placeholder.com/thumbnail3.jpg', '50000000-0000-0000-0000-000000000001', true),
  ('60000000-0000-0000-0000-000000000005', '40000000-0000-0000-0000-000000000005', 'sample-video-005', 720, 'https://placeholder.com/thumbnail5.jpg', '50000000-0000-0000-0000-000000000001', true),
  ('60000000-0000-0000-0000-000000000006', '40000000-0000-0000-0000-000000000006', 'sample-video-006', 900, 'https://placeholder.com/thumbnail6.jpg', '50000000-0000-0000-0000-000000000001', true);

-- Update videos with sample resolution URLs (would be real BunnyCDN URLs in production)
UPDATE videos SET
  url_360p = 'https://vz-placeholder.b-cdn.net/video-360p.m3u8',
  url_480p = 'https://vz-placeholder.b-cdn.net/video-480p.m3u8',
  url_720p = 'https://vz-placeholder.b-cdn.net/video-720p.m3u8',
  url_1080p = 'https://vz-placeholder.b-cdn.net/video-1080p.m3u8',
  size_360p_mb = 50.5,
  size_480p_mb = 85.2,
  size_720p_mb = 150.8,
  size_1080p_mb = 280.3
WHERE id IN (
  '60000000-0000-0000-0000-000000000001',
  '60000000-0000-0000-0000-000000000002',
  '60000000-0000-0000-0000-000000000003',
  '60000000-0000-0000-0000-000000000005',
  '60000000-0000-0000-0000-000000000006'
);

-- =====================================================
-- COMMIT
-- =====================================================
COMMIT;
