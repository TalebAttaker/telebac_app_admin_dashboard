import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة إدارة ملفات PDF للدروس
/// توفر وظائف رفع، حذف، وتحديث ملفات PDF
class PdfService {
  final _supabase = Supabase.instance.client;
  static const String _bucketName = 'lesson-pdfs';
  static const int _maxFileSizeMB = 50; // 50MB max for PDFs
  static const int _maxFileSizeBytes = _maxFileSizeMB * 1024 * 1024;

  /// رفع ملف PDF جديد
  ///
  /// Parameters:
  /// - [file]: ملف PDF المختار
  /// - [lessonId]: معرف الدرس
  ///
  /// Returns: رابط الملف المرفوع
  ///
  /// Throws: Exception في حالة الفشل
  Future<String> uploadPdf({
    required PlatformFile file,
    required String lessonId,
  }) async {
    try {
      // التحقق من نوع الملف
      if (file.extension?.toLowerCase() != 'pdf') {
        throw Exception('يجب أن يكون الملف من نوع PDF');
      }

      // التحقق من حجم الملف
      if (file.size > _maxFileSizeBytes) {
        throw Exception('حجم الملف يجب أن يكون أقل من $_maxFileSizeMB ميجابايت');
      }

      // الحصول على bytes الملف
      Uint8List fileBytes;
      if (kIsWeb) {
        if (file.bytes == null) {
          throw Exception('فشل قراءة الملف');
        }
        fileBytes = file.bytes!;
      } else {
        if (file.path == null) {
          throw Exception('فشل قراءة الملف');
        }
        fileBytes = await _readFileBytes(file.path!);
      }

      // إنشاء اسم فريد للملف
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'lesson_${lessonId}_$timestamp.pdf';

      // رفع الملف إلى Supabase Storage
      final response = await _supabase.storage
          .from(_bucketName)
          .uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: false,
            ),
          );

      // الحصول على الرابط العام
      final publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      throw Exception('فشل رفع ملف PDF: ${e.toString()}');
    }
  }

  /// حذف ملف PDF
  ///
  /// Parameters:
  /// - [pdfUrl]: رابط ملف PDF المراد حذفه
  Future<void> deletePdf(String pdfUrl) async {
    try {
      // استخراج اسم الملف من الرابط
      final fileName = _extractFileNameFromUrl(pdfUrl);
      if (fileName == null) {
        throw Exception('رابط الملف غير صالح');
      }

      // حذف الملف من Storage
      await _supabase.storage
          .from(_bucketName)
          .remove([fileName]);
    } catch (e) {
      throw Exception('فشل حذف ملف PDF: ${e.toString()}');
    }
  }

  /// تحديث رابط PDF في جدول lessons
  ///
  /// Parameters:
  /// - [lessonId]: معرف الدرس
  /// - [pdfUrl]: رابط PDF الجديد (null للحذف)
  Future<void> updateLessonPdfUrl({
    required String lessonId,
    String? pdfUrl,
  }) async {
    try {
      await _supabase
          .from('lessons')
          .update({'pdf_url': pdfUrl})
          .eq('id', lessonId);
    } catch (e) {
      throw Exception('فشل تحديث رابط PDF: ${e.toString()}');
    }
  }

  /// استبدال ملف PDF موجود بملف جديد
  ///
  /// Parameters:
  /// - [file]: ملف PDF الجديد
  /// - [lessonId]: معرف الدرس
  /// - [oldPdfUrl]: رابط PDF القديم المراد حذفه
  ///
  /// Returns: رابط الملف الجديد
  Future<String> replacePdf({
    required PlatformFile file,
    required String lessonId,
    required String oldPdfUrl,
  }) async {
    try {
      // رفع الملف الجديد
      final newPdfUrl = await uploadPdf(
        file: file,
        lessonId: lessonId,
      );

      // تحديث قاعدة البيانات
      await updateLessonPdfUrl(
        lessonId: lessonId,
        pdfUrl: newPdfUrl,
      );

      // حذف الملف القديم
      try {
        await deletePdf(oldPdfUrl);
      } catch (e) {
        // لا نفشل العملية إذا فشل حذف الملف القديم
        if (kDebugMode) {
          print('تحذير: فشل حذف PDF القديم: $e');
        }
      }

      return newPdfUrl;
    } catch (e) {
      throw Exception('فشل استبدال ملف PDF: ${e.toString()}');
    }
  }

  /// قراءة bytes الملف (للمنصات غير الويب)
  Future<Uint8List> _readFileBytes(String filePath) async {
    // في الحالة العادية، file.bytes متوفر من FilePicker
    // هذه الدالة احتياطية فقط
    throw Exception('يجب استخدام file.bytes مباشرة');
  }

  /// استخراج اسم الملف من الرابط
  String? _extractFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;

      // البحث عن اسم الملف بعد bucket name
      final bucketIndex = pathSegments.indexOf(_bucketName);
      if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
        return pathSegments[bucketIndex + 1];
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// التحقق من وجود PDF لدرس معين
  Future<String?> getLessonPdfUrl(String lessonId) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('pdf_url')
          .eq('id', lessonId)
          .single();

      return response['pdf_url'] as String?;
    } catch (e) {
      return null;
    }
  }
}
