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
