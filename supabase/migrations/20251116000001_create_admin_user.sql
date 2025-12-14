-- =====================================================
-- Create Root Admin User
-- Email: tasynmym@gmail.com
-- Password: 32004001
-- Full root access to everything
-- =====================================================

-- Step 1: Insert admin user into auth.users
-- This creates the authentication record
DO $$
DECLARE
  admin_user_id UUID;
BEGIN
  -- Create the auth user with encrypted password
  INSERT INTO auth.users (
    instance_id,
    id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    recovery_sent_at,
    last_sign_in_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at,
    confirmation_token,
    email_change,
    email_change_token_new,
    recovery_token
  ) VALUES (
    '00000000-0000-0000-0000-000000000000',
    gen_random_uuid(),
    'authenticated',
    'authenticated',
    'tasynmym@gmail.com',
    crypt('32004001', gen_salt('bf')), -- Encrypted password
    NOW(),
    NOW(),
    NOW(),
    '{"provider":"email","providers":["email"],"role":"admin"}',
    '{"full_name":"Root Admin","role":"admin"}',
    NOW(),
    NOW(),
    '',
    '',
    '',
    ''
  )
  ON CONFLICT (email) DO UPDATE
  SET
    encrypted_password = crypt('32004001', gen_salt('bf')),
    raw_app_meta_data = '{"provider":"email","providers":["email"],"role":"admin"}',
    raw_user_meta_data = '{"full_name":"Root Admin","role":"admin"}',
    email_confirmed_at = NOW()
  RETURNING id INTO admin_user_id;

  -- Create or update profile
  INSERT INTO public.profiles (
    id,
    email,
    full_name,
    role,
    is_active,
    max_devices,
    created_at,
    updated_at
  ) VALUES (
    admin_user_id,
    'tasynmym@gmail.com',
    'Root Admin',
    'admin',
    true,
    999, -- Unlimited devices
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET
    role = 'admin',
    is_active = true,
    max_devices = 999,
    updated_at = NOW();

  RAISE NOTICE 'Admin user created successfully with ID: %', admin_user_id;
END $$;

-- =====================================================
-- Step 2: Update RLS Policies for Admin Access
-- Admins can do EVERYTHING on ALL tables
-- =====================================================

-- Helper function to check if user is admin
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
-- Step 3: Storage Policies - Admin Full Access
-- =====================================================

-- PDF Lessons bucket
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
-- Step 4: Grant necessary permissions
-- =====================================================

-- Grant admin access to all tables
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
  RAISE NOTICE 'ROOT ADMIN CREATED SUCCESSFULLY!';
  RAISE NOTICE '========================================';
  RAISE NOTICE 'Email: tasynmym@gmail.com';
  RAISE NOTICE 'Password: 32004001';
  RAISE NOTICE 'Role: admin (root access)';
  RAISE NOTICE 'Permissions: FULL ACCESS TO EVERYTHING';
  RAISE NOTICE '========================================';
END $$;
