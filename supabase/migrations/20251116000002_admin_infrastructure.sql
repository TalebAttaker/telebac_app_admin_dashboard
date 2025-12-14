-- =====================================================
-- Admin Infrastructure Setup
-- Sets up admin permissions and RLS policies
-- User will be created via Supabase Auth API
-- =====================================================

-- Step 1: Create helper function to check if user is admin
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
    AND role = 'admin'
    AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin() TO anon;

-- =====================================================
-- RLS Policies for ALL Tables - Admin Full Access
-- =====================================================

-- PROFILES TABLE
DROP POLICY IF EXISTS "admin_all_profiles" ON profiles;
CREATE POLICY "admin_all_profiles"
ON profiles
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- GRADES TABLE
DROP POLICY IF EXISTS "admin_all_grades" ON grades;
CREATE POLICY "admin_all_grades"
ON grades
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- SUBJECTS TABLE
DROP POLICY IF EXISTS "admin_all_subjects" ON subjects;
CREATE POLICY "admin_all_subjects"
ON subjects
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- TOPICS TABLE
DROP POLICY IF EXISTS "admin_all_topics" ON topics;
CREATE POLICY "admin_all_topics"
ON topics
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- LESSONS TABLE
DROP POLICY IF EXISTS "admin_all_lessons" ON lessons;
CREATE POLICY "admin_all_lessons"
ON lessons
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- VIDEOS TABLE
DROP POLICY IF EXISTS "admin_all_videos" ON videos;
CREATE POLICY "admin_all_videos"
ON videos
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- LIVE_SESSIONS TABLE
DROP POLICY IF EXISTS "admin_all_live_sessions" ON live_sessions;
CREATE POLICY "admin_all_live_sessions"
ON live_sessions
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- LIVE_SESSION_ATTENDANCE TABLE
DROP POLICY IF EXISTS "admin_all_live_session_attendance" ON live_session_attendance;
CREATE POLICY "admin_all_live_session_attendance"
ON live_session_attendance
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- SUBSCRIPTIONS TABLE
DROP POLICY IF EXISTS "admin_all_subscriptions" ON subscriptions;
CREATE POLICY "admin_all_subscriptions"
ON subscriptions
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- SUBSCRIPTION_ACCESS TABLE
DROP POLICY IF EXISTS "admin_all_subscription_access" ON subscription_access;
CREATE POLICY "admin_all_subscription_access"
ON subscription_access
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- USER_PROGRESS TABLE
DROP POLICY IF EXISTS "admin_all_user_progress" ON user_progress;
CREATE POLICY "admin_all_user_progress"
ON user_progress
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- DOWNLOADED_VIDEOS TABLE
DROP POLICY IF EXISTS "admin_all_downloaded_videos" ON downloaded_videos;
CREATE POLICY "admin_all_downloaded_videos"
ON downloaded_videos
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- NOTIFICATIONS TABLE
DROP POLICY IF EXISTS "admin_all_notifications" ON notifications;
CREATE POLICY "admin_all_notifications"
ON notifications
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- ANALYTICS_EVENTS TABLE
DROP POLICY IF EXISTS "admin_all_analytics_events" ON analytics_events;
CREATE POLICY "admin_all_analytics_events"
ON analytics_events
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- ENCRYPTION_KEYS TABLE
DROP POLICY IF EXISTS "admin_all_encryption_keys" ON encryption_keys;
CREATE POLICY "admin_all_encryption_keys"
ON encryption_keys
FOR ALL
TO authenticated
USING (is_admin())
WITH CHECK (is_admin());

-- =====================================================
-- Storage Policies - Admin Full Access
-- =====================================================

DROP POLICY IF EXISTS "admin_all_pdf_lessons" ON storage.objects;
CREATE POLICY "admin_all_pdf_lessons"
ON storage.objects
FOR ALL
TO authenticated
USING (
  bucket_id = 'pdf-lessons' AND is_admin()
)
WITH CHECK (
  bucket_id = 'pdf-lessons' AND is_admin()
);

-- =====================================================
-- Grant permissions
-- =====================================================

DO $$
DECLARE
  table_name TEXT;
BEGIN
  FOR table_name IN
    SELECT tablename FROM pg_tables
    WHERE schemaname = 'public'
  LOOP
    EXECUTE format('GRANT ALL ON TABLE public.%I TO authenticated', table_name);
  END LOOP;
END $$;

-- =====================================================
-- Success Message
-- =====================================================

DO $$
BEGIN
  RAISE NOTICE '========================================';
  RAISE NOTICE 'ADMIN INFRASTRUCTURE CREATED!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Admin permissions: ENABLED';
  RAISE NOTICE 'RLS policies: UPDATED';
  RAISE NOTICE 'Next: Create admin user via Supabase';
  RAISE NOTICE '========================================';
END $$;
