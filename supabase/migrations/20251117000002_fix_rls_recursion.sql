-- =====================================================
-- Fix RLS Infinite Recursion on profiles table
-- Migration: 20251117000002_fix_rls_recursion
-- Created: 2025-11-17
-- Description: Remove recursive policies and add safe function-based check
-- =====================================================

-- Drop the problematic recursive policy
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;

-- Create a SECURITY DEFINER function to check if user is admin
-- This bypasses RLS and prevents recursion
CREATE OR REPLACE FUNCTION is_admin()
RETURNS BOOLEAN AS $$
DECLARE
  user_role TEXT;
BEGIN
  SELECT role INTO user_role
  FROM profiles
  WHERE id = auth.uid()
  LIMIT 1;

  RETURN user_role = 'admin';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

COMMENT ON FUNCTION is_admin IS 'Check if current user has admin role (bypasses RLS to prevent recursion)';

-- Create new admin policy using the safe function
CREATE POLICY "Admins can view all profiles"
  ON profiles FOR SELECT
  USING (is_admin());

-- Also update any other admin policies to use the new function
CREATE POLICY "Admins can update all profiles"
  ON profiles FOR UPDATE
  USING (is_admin());

CREATE POLICY "Admins can delete profiles"
  ON profiles FOR DELETE
  USING (is_admin());
