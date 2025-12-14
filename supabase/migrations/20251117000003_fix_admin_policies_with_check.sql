-- =====================================================
-- Fix Admin RLS Policies - Add WITH CHECK Clause
-- Migration: 20251117000003_fix_admin_policies_with_check
-- Created: 2025-11-17
-- Description: Add WITH CHECK clause to all admin policies for INSERT/UPDATE operations
-- Issue: Admin users were getting 400 errors when trying to INSERT records
-- Cause: RLS policies had USING clause but missing WITH CHECK clause
-- =====================================================

-- PostgreSQL RLS requires both clauses:
-- - USING: checked when reading existing rows
-- - WITH CHECK: checked when inserting/updating rows

-- 1. Fix Topics table
DROP POLICY IF EXISTS "Admins can manage topics" ON topics;
CREATE POLICY "Admins can manage topics"
  ON topics FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- 2. Fix Grades table
DROP POLICY IF EXISTS "Admins can manage grades" ON grades;
CREATE POLICY "Admins can manage grades"
  ON grades FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- 3. Fix Subjects table
DROP POLICY IF EXISTS "Admins can manage subjects" ON subjects;
CREATE POLICY "Admins can manage subjects"
  ON subjects FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- 4. Fix Lessons table
DROP POLICY IF EXISTS "Admins can manage lessons" ON lessons;
CREATE POLICY "Admins can manage lessons"
  ON lessons FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- 5. Fix Videos table
DROP POLICY IF EXISTS "Admins can manage videos" ON videos;
CREATE POLICY "Admins can manage videos"
  ON videos FOR ALL
  USING (is_admin())
  WITH CHECK (is_admin());

-- Verification: All policies now allow admin INSERT/UPDATE/DELETE operations
COMMENT ON POLICY "Admins can manage topics" ON topics IS 'Admin full access with WITH CHECK for INSERT/UPDATE';
COMMENT ON POLICY "Admins can manage grades" ON grades IS 'Admin full access with WITH CHECK for INSERT/UPDATE';
COMMENT ON POLICY "Admins can manage subjects" ON subjects IS 'Admin full access with WITH CHECK for INSERT/UPDATE';
COMMENT ON POLICY "Admins can manage lessons" ON lessons IS 'Admin full access with WITH CHECK for INSERT/UPDATE';
COMMENT ON POLICY "Admins can manage videos" ON videos IS 'Admin full access with WITH CHECK for INSERT/UPDATE';
