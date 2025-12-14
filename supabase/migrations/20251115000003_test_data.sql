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
