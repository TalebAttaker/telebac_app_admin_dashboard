-- =====================================================
-- Setup Supabase Storage for PDF Lessons
-- Run this in Supabase SQL Editor
-- =====================================================

-- Create storage bucket for PDF lessons
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'pdf-lessons',
  'pdf-lessons',
  true,
  52428800, -- 50MB limit
  ARRAY['application/pdf']
)
ON CONFLICT (id) DO NOTHING;

-- Policy: Allow authenticated users to upload PDFs
CREATE POLICY "Authenticated users can upload PDFs"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'pdf-lessons' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Allow public to download PDFs
CREATE POLICY "Public can download PDFs"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'pdf-lessons');

-- Policy: Allow owners to delete their PDFs
CREATE POLICY "Users can delete their own PDFs"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'pdf-lessons' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Grant permissions
GRANT ALL ON storage.buckets TO authenticated;
GRANT ALL ON storage.objects TO authenticated;

COMMENT ON TABLE storage.buckets IS 'Storage buckets for file uploads';
COMMENT ON TABLE storage.objects IS 'Files uploaded to storage buckets';
