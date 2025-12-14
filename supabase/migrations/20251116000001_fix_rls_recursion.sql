-- =====================================================
-- Fix: RLS Infinite Recursion in Profiles Table
-- Migration: 20251116000001_fix_rls_recursion
-- Created: 2025-11-16
-- Description: Fixes infinite recursion by dropping problematic policies
--              and recreating them using the is_admin() function
-- =====================================================

-- Drop the problematic admin policies
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON profiles;

-- Recreate the admin policies using the is_admin() function
-- This function uses SECURITY DEFINER to bypass RLS checks

CREATE POLICY "Admins can view all profiles"
  ON profiles FOR SELECT
  USING (is_admin());

CREATE POLICY "Admins can update all profiles"
  ON profiles FOR UPDATE
  USING (is_admin());

COMMENT ON POLICY "Admins can view all profiles" ON profiles IS 'Allows admins to view all user profiles using is_admin() to avoid recursion';
COMMENT ON POLICY "Admins can update all profiles" ON profiles IS 'Allows admins to update all user profiles using is_admin() to avoid recursion';
