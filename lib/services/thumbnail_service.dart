import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة إدارة الصور المصغرة للفيديوهات
/// توفر وظائف ضغط، رفع، حذف، وتحديث الصور المصغرة
class ThumbnailService {
  final _supabase = Supabase.instance.client;
  static const String _bucketName = 'video-thumbnails';
  static const int _maxFileSizeMB = 10; // 10MB max before compression
  static const int _maxFileSizeBytes = _maxFileSizeMB * 1024 * 1024;

  // إعدادات الضغط
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1080;
  static const int _quality = 80; // 80% quality
  static const CompressFormat _format = CompressFormat.webp; // WebP للحجم الأصغر

  /// ضغط الصورة
  ///
  /// Parameters:
  /// - [imageBytes]: bytes الصورة الأصلية
  /// - [fileName]: اسم الملف
  ///
  /// Returns: CompressionResult يحتوي على الصورة المضغوطة والمعلومات
  Future<CompressionResult> compressImage({
    required Uint8List imageBytes,
    required String fileName,
  }) async {
    try {
      final originalSize = imageBytes.length;

      // ضغط الصورة
      final compressedBytes = await FlutterImageCompress.compressWithList(
        imageBytes,
        minWidth: _maxWidth,
        minHeight: _maxHeight,
        quality: _quality,
        format: _format,
      );

      final compressedSize = compressedBytes.length;
      final compressionRatio = ((originalSize - compressedSize) / originalSize * 100);

      return CompressionResult(
        compressedBytes: Uint8List.fromList(compressedBytes),
        originalSize: originalSize,
        compressedSize: compressedSize,
        compressionRatio: compressionRatio,
      );
    } catch (e) {
      throw Exception('فشل ضغط الصورة: ${e.toString()}');
    }
  }

  /// رفع صورة مصغرة جديدة
  ///
  /// Parameters:
  /// - [file]: ملف الصورة المختار
  /// - [videoId]: معرف الفيديو
  /// - [onProgress]: callback لتتبع تقدم الضغط والرفع
  ///
  /// Returns: ThumbnailUploadResult يحتوي على الرابط والمعلومات
  Future<ThumbnailUploadResult> uploadThumbnail({
    required PlatformFile file,
    required String videoId,
    Function(String status, double progress)? onProgress,
  }) async {
    try {
      // التحقق من نوع الملف
      final extension = file.extension?.toLowerCase();
      if (extension == null ||
          !['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw Exception('يجب أن تكون الصورة من نوع JPG, PNG, أو WebP');
      }

      // التحقق من حجم الملف
      if (file.size > _maxFileSizeBytes) {
        throw Exception('حجم الصورة يجب أن يكون أقل من $_maxFileSizeMB ميجابايت');
      }

      // الحصول على bytes الصورة
      if (file.bytes == null) {
        throw Exception('فشل قراءة الصورة. يرجى التأكد من اختيار ملف صالح');
      }

      final Uint8List imageBytes = file.bytes!;

      // ضغط الصورة
      onProgress?.call('جاري ضغط الصورة...', 0.3);
      final compressionResult = await compressImage(
        imageBytes: imageBytes,
        fileName: file.name,
      );

      // إنشاء اسم فريد للملف
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'video_${videoId}_$timestamp.webp';

      // رفع الصورة المضغوطة إلى Supabase Storage
      onProgress?.call('جاري رفع الصورة...', 0.7);
      await _supabase.storage.from(_bucketName).uploadBinary(
            fileName,
            compressionResult.compressedBytes,
            fileOptions: const FileOptions(
              contentType: 'image/webp',
              upsert: false,
            ),
          );

      // الحصول على الرابط العام
      final publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(fileName);

      onProgress?.call('تم بنجاح', 1.0);

      return ThumbnailUploadResult(
        url: publicUrl,
        originalSize: compressionResult.originalSize,
        compressedSize: compressionResult.compressedSize,
        compressionRatio: compressionResult.compressionRatio,
      );
    } catch (e) {
      throw Exception('فشل رفع الصورة المصغرة: ${e.toString()}');
    }
  }

  /// حذف صورة مصغرة
  ///
  /// Parameters:
  /// - [thumbnailUrl]: رابط الصورة المصغرة المراد حذفها
  Future<void> deleteThumbnail(String thumbnailUrl) async {
    try {
      // التحقق من أن الصورة في bucket الصحيح
      if (!thumbnailUrl.contains(_bucketName)) {
        // الصورة ليست في bucket الصور المصغرة (ربما من BunnyCDN)
        // لا نحذفها
        return;
      }

      // استخراج اسم الملف من الرابط
      final fileName = _extractFileNameFromUrl(thumbnailUrl);
      if (fileName == null) {
        throw Exception('رابط الصورة غير صالح');
      }

      // حذف الصورة من Storage
      await _supabase.storage.from(_bucketName).remove([fileName]);
    } catch (e) {
      throw Exception('فشل حذف الصورة المصغرة: ${e.toString()}');
    }
  }

  /// تحديث رابط الصورة المصغرة في جدول videos
  ///
  /// Parameters:
  /// - [videoId]: معرف الفيديو
  /// - [thumbnailUrl]: رابط الصورة المصغرة الجديدة (null للحذف)
  Future<void> updateVideoThumbnail({
    required String videoId,
    String? thumbnailUrl,
  }) async {
    try {
      await _supabase
          .from('videos')
          .update({'thumbnail_url': thumbnailUrl}).eq('id', videoId);
    } catch (e) {
      throw Exception('فشل تحديث الصورة المصغرة: ${e.toString()}');
    }
  }

  /// استبدال صورة مصغرة موجودة بصورة جديدة
  ///
  /// Parameters:
  /// - [file]: ملف الصورة الجديد
  /// - [videoId]: معرف الفيديو
  /// - [oldThumbnailUrl]: رابط الصورة القديمة المراد حذفها
  /// - [onProgress]: callback لتتبع التقدم
  ///
  /// Returns: ThumbnailUploadResult يحتوي على الرابط والمعلومات
  Future<ThumbnailUploadResult> replaceThumbnail({
    required PlatformFile file,
    required String videoId,
    required String oldThumbnailUrl,
    Function(String status, double progress)? onProgress,
  }) async {
    try {
      // رفع الصورة الجديدة
      onProgress?.call('جاري رفع الصورة الجديدة...', 0.0);
      final result = await uploadThumbnail(
        file: file,
        videoId: videoId,
        onProgress: (status, progress) {
          // تحويل progress من 0-1 إلى 0-0.8
          onProgress?.call(status, progress * 0.8);
        },
      );

      // تحديث قاعدة البيانات
      onProgress?.call('جاري تحديث قاعدة البيانات...', 0.85);
      await updateVideoThumbnail(
        videoId: videoId,
        thumbnailUrl: result.url,
      );

      // حذف الصورة القديمة
      onProgress?.call('جاري حذف الصورة القديمة...', 0.9);
      try {
        await deleteThumbnail(oldThumbnailUrl);
      } catch (e) {
        // لا نفشل العملية إذا فشل حذف الصورة القديمة
        if (kDebugMode) {
          print('تحذير: فشل حذف الصورة المصغرة القديمة: $e');
        }
      }

      onProgress?.call('تم بنجاح', 1.0);
      return result;
    } catch (e) {
      throw Exception('فشل استبدال الصورة المصغرة: ${e.toString()}');
    }
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

  /// التحقق من وجود صورة مصغرة لفيديو معين
  Future<String?> getVideoThumbnailUrl(String videoId) async {
    try {
      final response = await _supabase
          .from('videos')
          .select('thumbnail_url')
          .eq('id', videoId)
          .single();

      return response['thumbnail_url'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// تنسيق حجم الملف
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes بايت';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} كيلوبايت';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} ميجابايت';
    }
  }
}

/// نتيجة ضغط الصورة
class CompressionResult {
  final Uint8List compressedBytes;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;

  CompressionResult({
    required this.compressedBytes,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
  });
}

/// نتيجة رفع الصورة المصغرة
class ThumbnailUploadResult {
  final String url;
  final int originalSize;
  final int compressedSize;
  final double compressionRatio;

  ThumbnailUploadResult({
    required this.url,
    required this.originalSize,
    required this.compressedSize,
    required this.compressionRatio,
  });

  String get compressionInfo =>
      'الحجم الأصلي: ${ThumbnailService.formatFileSize(originalSize)}\n'
      'الحجم بعد الضغط: ${ThumbnailService.formatFileSize(compressedSize)}\n'
      'نسبة الضغط: ${compressionRatio.toStringAsFixed(1)}%';
}
