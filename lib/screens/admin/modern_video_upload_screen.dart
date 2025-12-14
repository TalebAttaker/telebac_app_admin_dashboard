import 'package:universal_io/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/secure_bunny_service.dart';
import '../../utils/admin_theme.dart';

// Conditional import for web file picker
import '../../services/web_file_picker_stub.dart'
  if (dart.library.html) '../../services/web_file_picker_web.dart';

/// Modern Video Upload Screen
/// Professional UI with grade/subject/topic selection

class ModernVideoUploadScreen extends StatefulWidget {
  final bool isEmbedded; // If true, don't show AppBar (will be in AdminLayout)

  const ModernVideoUploadScreen({super.key, this.isEmbedded = false});

  @override
  State<ModernVideoUploadScreen> createState() => _ModernVideoUploadScreenState();
}

class _ModernVideoUploadScreenState extends State<ModernVideoUploadScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleArController = TextEditingController();
  final _descriptionArController = TextEditingController();

  String? _selectedCurriculumId; // المنهج المختار
  String? _selectedGradeId;
  String? _selectedSpecializationId; // الشعبة المختارة
  String? _selectedSubjectId;
  String? _selectedTopicId;
  String _selectedContentCategory = 'lesson'; // نوع المحتوى الافتراضي

  // أنواع المحتوى المتاحة
  final List<Map<String, String>> _contentCategories = [
    {'value': 'lesson', 'label': 'درس مرئي', 'icon': 'video_library'},
    {'value': 'solved_exercise', 'label': 'تمرين محلول', 'icon': 'assignment'},
    {'value': 'summary', 'label': 'ملخص', 'icon': 'summarize'},
    {'value': 'solved_baccalaureate', 'label': 'باكالوريا محلولة', 'icon': 'school'},
  ];

  List<Map<String, dynamic>> _curricula = []; // قائمة المناهج
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _specializations = []; // الشعب المتاحة
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _topics = [];

  File? _videoFile;
  PlatformFile? _platformFile; // For web compatibility
  dynamic _htmlFile; // For web large file upload (dart:html File object)
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  // PDF file (optional)
  PlatformFile? _pdfFile;
  bool _isUploadingPdf = false;

  @override
  void initState() {
    super.initState();
    _loadCurricula();
  }

  Future<void> _loadCurricula() async {
    final response = await _supabase
        .from('curricula')
        .select()
        .eq('is_active', true)
        .order('display_order');
    setState(() => _curricula = List<Map<String, dynamic>>.from(response));
  }

  Future<void> _loadGrades() async {
    if (_selectedCurriculumId == null) {
      setState(() {
        _grades = [];
        _selectedGradeId = null;
        _specializations = [];
        _selectedSpecializationId = null;
        _subjects = [];
        _selectedSubjectId = null;
        _topics = [];
        _selectedTopicId = null;
      });
      return;
    }

    final response = await _supabase
        .from('grades')
        .select()
        .eq('curriculum_id', _selectedCurriculumId!)
        .eq('is_active', true)
        .order('display_order');
    setState(() {
      _grades = List<Map<String, dynamic>>.from(response);
      _selectedGradeId = null;
      _specializations = [];
      _selectedSpecializationId = null;
      _subjects = [];
      _selectedSubjectId = null;
      _topics = [];
      _selectedTopicId = null;
    });
  }

  /// تحميل الشعب حسب الفصل المختار
  Future<void> _loadSpecializations() async {
    if (_selectedGradeId == null) return;

    final response = await _supabase
        .from('specializations')
        .select()
        .eq('grade_id', _selectedGradeId!)
        .eq('is_active', true)
        .order('display_order');

    setState(() {
      _specializations = List<Map<String, dynamic>>.from(response);
      _selectedSpecializationId = null;
      _subjects = [];
      _selectedSubjectId = null;
      _topics = [];
      _selectedTopicId = null;
    });
  }

  Future<void> _loadSubjects() async {
    if (_selectedGradeId == null) return;

    // إذا كان الفصل يحتوي على شعب، يجب اختيار شعبة أولاً
    if (_specializations.isNotEmpty && _selectedSpecializationId == null) {
      setState(() {
        _subjects = [];
        _selectedSubjectId = null;
        _topics = [];
        _selectedTopicId = null;
      });
      return;
    }

    // بناء الاستعلام
    var query = _supabase
        .from('subjects')
        .select()
        .eq('grade_id', _selectedGradeId!)
        .eq('is_active', true);

    // إذا تم اختيار شعبة، نفلتر حسبها
    if (_selectedSpecializationId != null) {
      query = query.eq('specialization_id', _selectedSpecializationId!);
    }

    final response = await query.order('display_order');

    setState(() {
      _subjects = List<Map<String, dynamic>>.from(response);
      _selectedSubjectId = null;
      _topics = [];
      _selectedTopicId = null;
    });
  }

  Future<void> _loadTopics(String subjectId) async {
    final response = await _supabase
        .from('topics')
        .select()
        .eq('subject_id', subjectId)
        .eq('is_active', true)
        .order('display_order', ascending: true);
    setState(() {
      _topics = List<Map<String, dynamic>>.from(response);
      _selectedTopicId = null;
    });
  }

  Future<void> _pickVideo() async {
    try {
      if (kIsWeb) {
        // Web platform: Use custom web file picker to capture HTML File object
        final webResult = await WebFilePicker.pickVideoFile();

        if (webResult != null) {
          // Validate file size (max 500MB)
          if (!WebFilePicker.validateFileSize(webResult.size)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ الملف كبير جداً! الحد الأقصى: 500 ميجابايت'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }

          // Validate file type
          if (!WebFilePicker.validateVideoFile(webResult.name, webResult.type)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ نوع الملف غير صحيح! الرجاء اختيار ملف فيديو'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }

          setState(() {
            _htmlFile = webResult.htmlFile;
            _platformFile = PlatformFile(
              name: webResult.name,
              size: webResult.size,
              bytes: null, // Don't load bytes for large files
            );
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ تم اختيار: ${webResult.name}\nالحجم: ${(webResult.size / 1024 / 1024).toStringAsFixed(2)} MB\nجاهز للرفع!'),
                duration: const Duration(seconds: 5),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      } else {
        // Non-web platform: Use standard file picker
        final result = await FilePicker.platform.pickFiles(
          type: FileType.video,
          allowMultiple: false,
          withData: false,
          withReadStream: false,
        );

        if (result != null && result.files.isNotEmpty) {
          final file = result.files.first;

          // Validate file size (max 500MB)
          if (file.size > 500 * 1024 * 1024) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ الملف كبير جداً! الحد الأقصى: 500 ميجابايت'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 5),
                ),
              );
            }
            return;
          }

          setState(() {
            _platformFile = file;
            if (file.path != null) {
              _videoFile = File(file.path!);
            }
          });

          if (mounted) {
            final uploadReady = _videoFile != null;
            final status = uploadReady ? '✅ جاهز للرفع' : '❌ خطأ في الملف';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم اختيار: ${file.name}\nالحجم: ${(file.size / 1024 / 1024).toStringAsFixed(2)} MB\nالحالة: $status'),
                duration: const Duration(seconds: 5),
                backgroundColor: uploadReady ? Colors.green : Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في اختيار الملف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// اختيار ملف PDF (اختياري)
  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        setState(() {
          _pdfFile = file;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم اختيار PDF: ${file.name}\nالحجم: ${(file.size / 1024 / 1024).toStringAsFixed(2)} MB'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار ملف PDF: $e')),
        );
      }
    }
  }

  /// رفع ملف PDF إلى Supabase Storage
  Future<String?> _uploadPdfToStorage() async {
    if (_pdfFile == null || _pdfFile!.bytes == null) return null;

    try {
      setState(() => _isUploadingPdf = true);

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${_pdfFile!.name}';
      final filePath = 'lessons/$fileName';

      await _supabase.storage.from('lesson-pdfs').uploadBinary(
        filePath,
        _pdfFile!.bytes!,
        fileOptions: const FileOptions(
          contentType: 'application/pdf',
          upsert: true,
        ),
      );

      // Get public URL
      final publicUrl = _supabase.storage.from('lesson-pdfs').getPublicUrl(filePath);

      setState(() => _isUploadingPdf = false);
      return publicUrl;
    } catch (e) {
      setState(() => _isUploadingPdf = false);
      debugPrint('Error uploading PDF: $e');
      return null;
    }
  }

  /// Sync video duration in background with retry mechanism
  /// Makes 3 attempts with increasing delays (30s, 60s, 90s)
  Future<void> _syncVideoDurationInBackground(String bunnyVideoId) async {
    const supabaseUrl = 'https://ctupxmtreqyxubtphkrk.supabase.co';
    const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImN0dXB4bXRyZXF5eHVidHBoa3JrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyMjQxMTUsImV4cCI6MjA3ODgwMDExNX0.Clwx6EHcakWAh_6WFdljsvFD_TKh33QclATuIgdRcnM';

    final delays = [30, 60, 90]; // Seconds to wait before each attempt

    for (int attempt = 0; attempt < 3; attempt++) {
      // Wait before attempting
      await Future.delayed(Duration(seconds: delays[attempt]));

      try {
        debugPrint('🔄 Duration sync attempt ${attempt + 1}/3 for video: $bunnyVideoId');

        final response = await http.post(
          Uri.parse('$supabaseUrl/functions/v1/update-single-video-duration'),
          headers: {
            'Authorization': 'Bearer $anonKey',
            'Content-Type': 'application/json',
          },
          body: json.encode({'bunny_video_id': bunnyVideoId}),
        );

        final result = json.decode(response.body);
        debugPrint('📡 Sync response: $result');

        // Check if sync was successful
        if (result['ready'] == true && result['duration_seconds'] != null && result['duration_seconds'] > 0) {
          debugPrint('✅ Duration synced successfully: ${result['formatted_duration']}');
          return; // Success - exit the retry loop
        }

        // Video still processing, will retry
        debugPrint('⏳ Video still processing, will retry...');
      } catch (e) {
        debugPrint('❌ Sync attempt ${attempt + 1} failed: $e');
      }
    }

    debugPrint('⚠️ All sync attempts completed. Fallback pg_cron will handle remaining.');
  }

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء ملء جميع الحقول المطلوبة')),
      );
      return;
    }

    // DEBUG: Log upload state
    debugPrint('📤 Upload Button Clicked:');
    debugPrint('  - Platform: ${kIsWeb ? "WEB" : "MOBILE"}');
    debugPrint('  - _platformFile: ${_platformFile != null}');
    if (_platformFile != null) {
      debugPrint('  - _platformFile.name: ${_platformFile!.name}');
      debugPrint('  - _platformFile.bytes: ${_platformFile!.bytes != null}');
      if (_platformFile!.bytes != null) {
        debugPrint('  - _platformFile.bytes.length: ${_platformFile!.bytes!.length}');
      }
    }
    debugPrint('  - _videoFile: ${_videoFile != null}');

    if (_platformFile == null && _videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار ملف فيديو')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final secureBunny = context.read<SecureBunnyService>();

      // Get selected data with names
      final curriculum = _curricula.firstWhere((c) => c['id'] == _selectedCurriculumId);
      final grade = _grades.firstWhere((g) => g['id'] == _selectedGradeId);
      final subject = _subjects.firstWhere((s) => s['id'] == _selectedSubjectId);
      final topic = _topics.firstWhere((t) => t['id'] == _selectedTopicId);

      // Upload to BunnyCDN with organized folder structure
      String? videoId;

      if (kIsWeb && _platformFile != null) {
        // Web platform: Use HTML File object for upload
        final platformFile = _platformFile!;
        debugPrint('Uploading video from web');
        debugPrint('  - File: ${platformFile.name}');
        debugPrint('  - Size: ${(platformFile.size / 1024 / 1024).toStringAsFixed(2)} MB');
        debugPrint('  - Has HTML File: ${_htmlFile != null}');

        videoId = await secureBunny.uploadVideoFromWeb(
          htmlFile: _htmlFile,
          fileName: platformFile.name,
          fileSize: platformFile.size,
          title: _titleArController.text.isNotEmpty ? _titleArController.text : 'Untitled',
          curriculumName: curriculum['name_ar'] ?? curriculum['name'],
          gradeName: grade['name_ar'] ?? grade['name'],
          subjectName: subject['name_ar'] ?? subject['name'],
          topicName: topic['name_ar'] ?? topic['name'],
          onProgress: (progress) {
            setState(() => _uploadProgress = progress);
          },
        );

        if (videoId != null) {
          debugPrint('✅ Video uploaded successfully! Video ID: $videoId');
        } else {
          debugPrint('❌ Video upload failed - videoId is null');
        }

      } else if (_videoFile != null) {
        // Non-web platform: Use file upload
        debugPrint('Uploading video from file (non-web platform)');
        videoId = await secureBunny.uploadVideo(
          videoFile: _videoFile!,
          title: _titleArController.text.isNotEmpty ? _titleArController.text : 'Untitled',
          curriculumName: curriculum['name_ar'] ?? curriculum['name'],
          gradeName: grade['name_ar'] ?? grade['name'],
          subjectName: subject['name_ar'] ?? subject['name'],
          topicName: topic['name_ar'] ?? topic['name'],
          onProgress: (progress) {
            setState(() => _uploadProgress = progress);
          },
        );

        if (videoId != null) {
          debugPrint('✅ Video uploaded successfully! Video ID: $videoId');
        } else {
          debugPrint('❌ Video upload failed - videoId is null');
        }
      } else {
        throw Exception('No video file available for upload');
      }

      if (videoId == null) {
        throw Exception('فشل رفع الفيديو - لم يتم الحصول على معرف الفيديو');
      }

      // Upload PDF if selected (optional)
      String? pdfUrl;
      if (_pdfFile != null) {
        pdfUrl = await _uploadPdfToStorage();
      }

      // Call secure Edge Function to save video metadata
      final response = await _supabase.functions.invoke(
        'admin-upload-video',
        body: {
          'topic_id': _selectedTopicId,
          'bunny_video_id': videoId,
          'title': _titleArController.text.isNotEmpty ? _titleArController.text : 'Untitled Video',
          'title_ar': _titleArController.text.isNotEmpty ? _titleArController.text : 'فيديو بدون عنوان',
          'description': _descriptionArController.text.isNotEmpty ? _descriptionArController.text : null,
          'content_category': _selectedContentCategory,
          'pdf_url': pdfUrl,
          'thumbnail_url': secureBunny.getVideoThumbnailUrl(videoId),
          'url_360p': secureBunny.getVideoStreamUrl(videoId, '360p'),
          'url_480p': secureBunny.getVideoStreamUrl(videoId, '480p'),
          'url_720p': secureBunny.getVideoStreamUrl(videoId, '720p'),
          'url_1080p': secureBunny.getVideoStreamUrl(videoId, '1080p'),
          'encryption_key_id': 'default_key',
          'duration_seconds': 1, // Placeholder - will be synced automatically in background
          'is_downloadable': false,
          'is_free': false,
        },
      );

      // Check response status
      if (response.status != 200 && response.status != 201) {
        final errorData = response.data;
        String errorMessage = 'حدث خطأ غير متوقع';

        if (errorData is Map<String, dynamic> && errorData.containsKey('error')) {
          errorMessage = errorData['error'] as String;
        }

        throw Exception(errorMessage);
      }

      // Trigger automatic duration sync in background (3 attempts with delays)
      _syncVideoDurationInBackground(videoId);

      if (mounted) {
        // Clear only file selection and text fields, preserve grade/subject/topic
        setState(() {
          _videoFile = null;
          _platformFile = null;
          _htmlFile = null;
          _pdfFile = null; // Clear PDF file too
          _uploadProgress = 0.0;
          _titleArController.clear();
          _descriptionArController.clear();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم رفع الفيديو بنجاح! جاري مزامنة المدة تلقائياً...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: ${e.toString().replaceAll("Exception:", "").trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: AdminTheme.elevatedCard(
                    gradient: AdminTheme.gradientBlue,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Row(
                        children: [
                          if (constraints.maxWidth > 200) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.video_library_rounded,
                                size: 32,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'رفع درس مرئي جديد',
                                  style: AdminTheme.titleMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'اختر الفصل والمادة والموضوع ثم ارفع الفيديو',
                                  style: AdminTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // Content Category Selector
                _buildContentCategorySelector(),

                const SizedBox(height: 16),

                // Curriculum Selector - المنهج
                _buildCurriculumSelector(),

                const SizedBox(height: 16),

                // Selection Cards - الفصل
                _buildGradeSelector(),

                const SizedBox(height: 16),

                // الشعبة (تظهر فقط إذا كان الفصل يحتوي على شعب)
                _buildSpecializationSelector(),

                if (_specializations.isNotEmpty)
                  const SizedBox(height: 16),

                // المادة والموضوع
                Row(
                  children: [
                    Expanded(child: _buildSubjectSelector()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTopicSelector()),
                  ],
                ),

                const SizedBox(height: 16),

                // Video Title (Arabic)
                Container(
                  decoration: AdminTheme.glassCard(),
                  padding: const EdgeInsets.all(20),
                  child: TextFormField(
                    controller: _titleArController,
                    decoration: const InputDecoration(
                      labelText: 'عنوان الدرس (بالعربية) *',
                      hintText: 'مثال: مقدمة في الجبر',
                      filled: true,
                      fillColor: Color(0xFF1A1F25),
                    ),
                    style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                    validator: (value) => value == null || value.isEmpty ? 'أدخل عنوان الدرس' : null,
                  ),
                ),

                const SizedBox(height: 16),

                // Video Description (Arabic)
                Container(
                  decoration: AdminTheme.glassCard(),
                  padding: const EdgeInsets.all(20),
                  child: TextFormField(
                    controller: _descriptionArController,
                    decoration: const InputDecoration(
                      labelText: 'وصف الدرس (بالعربية)',
                      hintText: 'وصف مختصر للدرس',
                      filled: true,
                      fillColor: Color(0xFF1A1F25),
                    ),
                    style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                    maxLines: 3,
                  ),
                ),

                const SizedBox(height: 32),

                // Video Picker
                _buildVideoPicker(),

                const SizedBox(height: 32),

                // Upload Progress
                if (_isUploading) ...[
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: AdminTheme.glassCard(),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _uploadProgress,
                          backgroundColor: Colors.white.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AdminTheme.accentCyan,
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${(_uploadProgress * 100).toStringAsFixed(0)}% - جاري الرفع...',
                          style: AdminTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Upload Button
                Container(
                  height: 60,
                  decoration: AdminTheme.elevatedCard(
                    gradient: AdminTheme.gradientCyan,
                  ),
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _uploadVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.cloud_upload_rounded, size: 24),
                        const SizedBox(width: 12),
                        Text(
                          _isUploading ? 'جاري الرفع...' : 'رفع الفيديو',
                          style: AdminTheme.titleSmall,
                        ),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );

    // If embedded, just return content without Theme/Scaffold
    if (widget.isEmbedded) {
      return content;
    }

    // Standalone mode: wrap in Theme and Scaffold with AppBar
    return Theme(
      data: AdminTheme.darkTheme,
      child: Scaffold(
        backgroundColor: AdminTheme.primaryDark,
        appBar: AppBar(
          title: const Text('رفع درس مرئي'),
          backgroundColor: AdminTheme.secondaryDark,
        ),
        body: content,
      ),
    );
  }

  Widget _buildContentCategorySelector() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AdminTheme.gradientPink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.category_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('نوع المحتوى', style: AdminTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _contentCategories.map((category) {
              final isSelected = _selectedContentCategory == category['value'];
              IconData iconData;
              switch (category['icon']) {
                case 'video_library':
                  iconData = Icons.video_library_rounded;
                  break;
                case 'assignment':
                  iconData = Icons.assignment_rounded;
                  break;
                case 'summarize':
                  iconData = Icons.summarize_rounded;
                  break;
                case 'school':
                  iconData = Icons.school_rounded;
                  break;
                default:
                  iconData = Icons.video_library_rounded;
              }

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedContentCategory = category['value']!);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AdminTheme.gradientCyan : null,
                    color: isSelected ? null : const Color(0xFF1A1F25),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.1),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AdminTheme.accentCyan.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        iconData,
                        size: 18,
                        color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          category['label']!,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculumSelector() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AdminTheme.gradientGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.menu_book_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('المنهج الدراسي', style: AdminTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedCurriculumId,
            decoration: const InputDecoration(
              hintText: 'اختر المنهج',
              filled: true,
              fillColor: Color(0xFF1A1F25),
            ),
            dropdownColor: AdminTheme.secondaryDark,
            items: _curricula.map((curriculum) {
              return DropdownMenuItem<String>(
                value: curriculum['id'] as String,
                child: Text(
                  curriculum['name_ar'] ?? curriculum['name'],
                  style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedCurriculumId = value);
              _loadGrades();
            },
            validator: (value) => value == null ? 'اختر المنهج' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildGradeSelector() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AdminTheme.gradientPurple,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.school_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('الفصل', style: AdminTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedGradeId,
            decoration: const InputDecoration(
              hintText: 'اختر الفصل',
              filled: true,
              fillColor: Color(0xFF1A1F25),
            ),
            dropdownColor: AdminTheme.secondaryDark,
            items: _grades.map((grade) {
              return DropdownMenuItem<String>(
                value: grade['id'] as String,
                child: Text(
                  grade['name_ar'] ?? grade['name'],
                  style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedGradeId = value);
              if (value != null) {
                _loadSpecializations();
              }
            },
            validator: (value) => value == null ? 'اختر الفصل' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializationSelector() {
    // لا تظهر إذا لم يكن هناك شعب للفصل المختار
    if (_specializations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AdminTheme.gradientGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.account_tree_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الشعبة', style: AdminTheme.titleSmall),
                    Text(
                      'اختر الشعبة لعرض المواد الخاصة بها',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedSpecializationId,
            decoration: const InputDecoration(
              hintText: 'اختر الشعبة',
              filled: true,
              fillColor: Color(0xFF1A1F25),
            ),
            dropdownColor: AdminTheme.secondaryDark,
            items: _specializations.map((spec) {
              return DropdownMenuItem<String>(
                value: spec['id'] as String,
                child: Text(
                  spec['name_ar'] ?? spec['name'],
                  style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedSpecializationId = value);
              if (value != null) {
                _loadSubjects();
              }
            },
            validator: (value) {
              // الشعبة مطلوبة فقط إذا كان الفصل يحتوي على شعب
              if (_specializations.isNotEmpty && value == null) {
                return 'اختر الشعبة';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelector() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AdminTheme.gradientBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.book_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('المادة', style: AdminTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedSubjectId,
            decoration: const InputDecoration(
              hintText: 'اختر المادة',
              filled: true,
              fillColor: Color(0xFF1A1F25),
            ),
            dropdownColor: AdminTheme.secondaryDark,
            items: _subjects.map((subject) {
              return DropdownMenuItem<String>(
                value: subject['id'] as String,
                child: Text(
                  subject['name_ar'] ?? subject['name'],
                  style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedSubjectId = value);
              if (value != null) _loadTopics(value);
            },
            validator: (value) => value == null ? 'اختر المادة' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTopicSelector() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AdminTheme.gradientCyan,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.topic_rounded, size: 20, color: Colors.white),
              ),
              const SizedBox(width: 12),
              const Text('الموضوع', style: AdminTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _selectedTopicId,
            decoration: const InputDecoration(
              hintText: 'اختر الموضوع',
              filled: true,
              fillColor: Color(0xFF1A1F25),
            ),
            dropdownColor: AdminTheme.secondaryDark,
            items: _topics.map((topic) {
              return DropdownMenuItem<String>(
                value: topic['id'] as String,
                child: Text(
                  topic['name_ar'] ?? topic['name'],
                  style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedTopicId = value),
            validator: (value) => value == null ? 'اختر الموضوع' : null,
          ),
        ],
      ),
    );
  }


  Widget _buildVideoPicker() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_videoFile == null) ...[
            Icon(
              Icons.video_file_rounded,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'لم يتم اختيار ملف',
              style: AdminTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AdminTheme.gradientGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _platformFile != null
                        ? _platformFile!.name
                        : (_videoFile != null ? _videoFile!.path.split('/').last : ''),
                      style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          Container(
            height: 60,
            decoration: AdminTheme.elevatedCard(
              gradient: AdminTheme.gradientPurple,
            ),
            child: ElevatedButton(
              onPressed: _pickVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.video_file_rounded),
                  const SizedBox(width: 12),
                  Text(
                    _videoFile == null ? 'اختر ملف فيديو' : 'اختر ملف آخر',
                    style: AdminTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // قسم اختيار ملف PDF (اختياري)
          _buildPdfSelector(),
        ],
      ),
    );
  }

  /// بناء قسم اختيار ملف PDF
  Widget _buildPdfSelector() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(30),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملف PDF (اختياري)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'أرفق ملف PDF مع الفيديو',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_pdfFile != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(50)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pdfFile!.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${(_pdfFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _pdfFile = null),
                    icon: const Icon(Icons.close_rounded, color: Colors.red, size: 20),
                    tooltip: 'إزالة الملف',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pickPdf,
              icon: Icon(
                _pdfFile == null ? Icons.upload_file_rounded : Icons.swap_horiz_rounded,
                color: Colors.red,
              ),
              label: Text(
                _pdfFile == null ? 'اختر ملف PDF' : 'تغيير الملف',
                style: const TextStyle(color: Colors.red),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleArController.dispose();
    _descriptionArController.dispose();
    super.dispose();
  }
}
