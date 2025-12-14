-- =====================================================
-- Fix Payment Proofs Storage Bucket
-- Created: 2025-12-14
-- Issue: Admin cannot see payment screenshots (HTTP 400 errors)
-- Root Cause: Missing storage bucket configuration and RLS policies
-- =====================================================

-- Create payment-proofs storage bucket if it doesn't exist
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'payment-proofs',
  'payment-proofs',
  true, -- PUBLIC bucket for easy access via getPublicUrl()
  10485760, -- 10MB limit for payment screenshots
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
)
ON CONFLICT (id)
DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

-- =====================================================
-- DROP EXISTING POLICIES (if any) to start fresh
-- =====================================================
DROP POLICY IF EXISTS "Users can upload payment proofs" ON storage.objects;
DROP POLICY IF EXISTS "Public can view payment proofs" ON storage.objects;
DROP POLICY IF EXISTS "Admins can view payment proofs" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own payment proofs" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload payment proofs" ON storage.objects;

-- =====================================================
-- CREATE NEW POLICIES FOR PAYMENT-PROOFS BUCKET
-- =====================================================

-- Policy 1: Allow authenticated users to upload their own payment proofs
-- Users can only upload to their own folder (userId/filename.jpg)
CREATE POLICY "Authenticated users can upload payment proofs"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'payment-proofs' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Allow public SELECT (viewing) for payment proofs
-- This enables getPublicUrl() to work without authentication
CREATE POLICY "Public can view payment proofs"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'payment-proofs');

-- Policy 3: Allow admins to view all payment proofs (redundant with public but explicit)
CREATE POLICY "Admins can view all payment proofs"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'payment-proofs' AND
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- Policy 4: Allow users to delete their own payment proofs
CREATE POLICY "Users can delete their own payment proofs"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'payment-proofs' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 5: Allow admins to delete any payment proof
CREATE POLICY "Admins can delete any payment proof"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'payment-proofs' AND
  EXISTS (
    SELECT 1 FROM public.profiles
    WHERE profiles.id = auth.uid()
    AND profiles.role = 'admin'
  )
);

-- =====================================================
-- GRANT PERMISSIONS
-- =====================================================
GRANT ALL ON storage.buckets TO authenticated;
GRANT ALL ON storage.objects TO authenticated;

-- =====================================================
-- VERIFICATION QUERIES (for testing)
-- =====================================================

-- Check bucket configuration
-- SELECT * FROM storage.buckets WHERE id = 'payment-proofs';

-- Check storage policies
-- SELECT * FROM pg_policies WHERE tablename = 'objects' AND policyname LIKE '%payment%';

-- =====================================================
-- MIGRATION COMPLETE
-- =====================================================

COMMENT ON TABLE storage.buckets IS 'Storage buckets including payment-proofs for payment verification screenshots';
