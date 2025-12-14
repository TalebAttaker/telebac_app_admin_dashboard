import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/secure_bunny_service.dart';

/// Video Lessons Manager Screen
/// Upload and manage video lessons

class VideoLessonsManagerScreen extends StatefulWidget {
  const VideoLessonsManagerScreen({super.key});

  @override
  State<VideoLessonsManagerScreen> createState() => _VideoLessonsManagerScreenState();
}

class _VideoLessonsManagerScreenState extends State<VideoLessonsManagerScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _videos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('videos')
          .select('''
            *,
            topics!inner(
              id,
              name,
              name_ar,
              subjects!inner(
                id,
                name,
                name_ar,
                grades!inner(
                  id,
                  name,
                  name_ar
                )
              )
            )
          ''')
          .order('display_order', ascending: true);

      setState(() {
        _videos = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading videos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showUploadDialog() async {
    if (!SecureBunnyService.isConfigured) {
      _showConfigurationError();
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => const _VideoUploadDialog(),
    );

    // Reload videos after upload
    await _loadVideos();
  }

  void _showConfigurationError() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('BunnyCDN Not Configured'),
        content: const Text(
          'Please configure BunnyCDN credentials (this should not happen with SecureBunnyService)\n\n'
          'You need to set:\n'
          '- Storage Zone Name\n'
          '- Storage Password\n'
          '- Video Library ID\n'
          '- Video Library API Key\n'
          '- Pull Zone URL',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الدروس المرئية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadVideos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.video_library_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد فيديوهات حالياً',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'اضغط على زر + لرفع فيديو جديد',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadVideos,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _videos.length,
                    itemBuilder: (context, index) {
                      final video = _videos[index];
                      final topic = video['topics'];
                      final subject = topic['subjects'];
                      final grade = subject['grades'];
                      final displayOrder = video['display_order'] ?? (index + 1);

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              // أزرار تغيير الترتيب
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.arrow_upward,
                                      color: index > 0 ? Colors.blue : Colors.grey.shade300,
                                      size: 20,
                                    ),
                                    onPressed: index > 0 ? () => _moveUp(index) : null,
                                    tooltip: 'تحريك للأعلى',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '$displayOrder',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.arrow_downward,
                                      color: index < _videos.length - 1 ? Colors.blue : Colors.grey.shade300,
                                      size: 20,
                                    ),
                                    onPressed: index < _videos.length - 1 ? () => _moveDown(index) : null,
                                    tooltip: 'تحريك للأسفل',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                  ),
                                ],
                              ),
                              // صورة الفيديو
                              Container(
                                width: 80,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: video['thumbnail_url'] != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: CachedNetworkImage(
                                          imageUrl: video['thumbnail_url'],
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => const Center(
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) =>
                                              const Icon(Icons.play_circle_outline, size: 40),
                                        ),
                                      )
                                    : const Icon(Icons.play_circle_outline, size: 40),
                              ),
                              const SizedBox(width: 12),
                              // معلومات الفيديو
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      video['title_ar'] ?? video['title'] ?? 'بدون عنوان',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${grade['name_ar'] ?? grade['name']} - ${subject['name_ar'] ?? subject['name']}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                                    ),
                                    Text(
                                      '${topic['name_ar'] ?? topic['name']}',
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                    ),
                                    Text(
                                      'المدة: ${_formatDuration(video['duration_seconds'])}',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // زر الخيارات
                              IconButton(
                                icon: const Icon(Icons.more_vert),
                                onPressed: () {
                                  _showVideoOptions(video);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        icon: const Icon(Icons.upload),
        label: const Text('رفع فيديو'),
      ),
    );
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return 'غير محدد';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  void _showVideoOptions(Map<String, dynamic> video) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle),
              title: const Text('مشاهدة'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Play video
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('تعديل'),
              onTap: () {
                Navigator.pop(context);
                // TODO: Edit video
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('حذف', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await _deleteVideo(video);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteVideo(Map<String, dynamic> video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الفيديو؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Delete from Supabase
        await _supabase.from('videos').delete().eq('id', video['id']);

        // TODO: Also delete from BunnyCDN if needed
        // final bunnyCDN = context.read<BunnyCDNService>();
        // await secureBunny.deleteVideo(video['bunny_video_id']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الفيديو بنجاح')),
          );
          await _loadVideos();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ في حذف الفيديو: $e')),
          );
        }
      }
    }
  }

  /// تحريك الفيديو للأعلى (تقليل display_order)
  Future<void> _moveUp(int index) async {
    if (index <= 0) return; // لا يمكن التحريك للأعلى إذا كان الأول

    try {
      final currentVideo = _videos[index];
      final previousVideo = _videos[index - 1];

      final currentOrder = currentVideo['display_order'] ?? index + 1;
      final previousOrder = previousVideo['display_order'] ?? index;

      // تبديل الترتيب
      await _supabase
          .from('videos')
          .update({'display_order': previousOrder})
          .eq('id', currentVideo['id']);

      await _supabase
          .from('videos')
          .update({'display_order': currentOrder})
          .eq('id', previousVideo['id']);

      // تحديث القائمة محلياً
      setState(() {
        _videos[index]['display_order'] = previousOrder;
        _videos[index - 1]['display_order'] = currentOrder;
        final temp = _videos[index];
        _videos[index] = _videos[index - 1];
        _videos[index - 1] = temp;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير الترتيب'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error moving video up: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تغيير الترتيب: $e')),
        );
      }
    }
  }

  /// تحريك الفيديو للأسفل (زيادة display_order)
  Future<void> _moveDown(int index) async {
    if (index >= _videos.length - 1) return; // لا يمكن التحريك للأسفل إذا كان الأخير

    try {
      final currentVideo = _videos[index];
      final nextVideo = _videos[index + 1];

      final currentOrder = currentVideo['display_order'] ?? index + 1;
      final nextOrder = nextVideo['display_order'] ?? index + 2;

      // تبديل الترتيب
      await _supabase
          .from('videos')
          .update({'display_order': nextOrder})
          .eq('id', currentVideo['id']);

      await _supabase
          .from('videos')
          .update({'display_order': currentOrder})
          .eq('id', nextVideo['id']);

      // تحديث القائمة محلياً
      setState(() {
        _videos[index]['display_order'] = nextOrder;
        _videos[index + 1]['display_order'] = currentOrder;
        final temp = _videos[index];
        _videos[index] = _videos[index + 1];
        _videos[index + 1] = temp;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تغيير الترتيب'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error moving video down: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تغيير الترتيب: $e')),
        );
      }
    }
  }
}

/// Video Upload Dialog
class _VideoUploadDialog extends StatefulWidget {
  const _VideoUploadDialog();

  @override
  State<_VideoUploadDialog> createState() => _VideoUploadDialogState();
}

class _VideoUploadDialogState extends State<_VideoUploadDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _titleArController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _descriptionArController = TextEditingController();
  final _supabase = Supabase.instance.client;

  String? _selectedGrade;
  String? _selectedSubject;
  String? _selectedTopic;

  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _topics = [];

  File? _videoFile;
  PlatformFile? _platformFile; // For web compatibility
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadGrades();
  }

  Future<void> _loadGrades() async {
    final response = await _supabase
        .from('grades')
        .select()
        .eq('is_active', true)
        .order('display_order');
    setState(() => _grades = List<Map<String, dynamic>>.from(response));
  }

  Future<void> _loadSubjects(String gradeId) async {
    final response = await _supabase
        .from('subjects')
        .select()
        .eq('grade_id', gradeId)
        .eq('is_active', true)
        .order('display_order');
    setState(() {
      _subjects = List<Map<String, dynamic>>.from(response);
      _selectedSubject = null;
      _topics = [];
      _selectedTopic = null;
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
      _selectedTopic = null;
    });
  }

  Future<void> _pickVideoFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
        withData: kIsWeb, // Load bytes only on web
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        setState(() {
          _platformFile = file;

          // Only try to create File on non-web platforms
          if (!kIsWeb && file.path != null) {
            _videoFile = File(file.path!);
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم اختيار: ${file.name}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الملف: $e')),
        );
      }
    }
  }

  Future<void> _uploadVideo() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء ملء جميع الحقول المطلوبة')),
      );
      return;
    }

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

      // Upload to BunnyCDN
      // Note: For web, you may need to update BunnyCDN service to accept bytes
      // Get the names for BunnyCDN organization
      final selectedGradeData = _grades.firstWhere((g) => g['id'] == _selectedGrade, orElse: () => {});
      final selectedSubjectData = _subjects.firstWhere((s) => s['id'] == _selectedSubject, orElse: () => {});
      final selectedTopicData = _topics.firstWhere((t) => t['id'] == _selectedTopic, orElse: () => {});

      final gradeName = selectedGradeData['name_ar'] ?? selectedGradeData['name'] ?? 'Unknown';
      final subjectName = selectedSubjectData['name_ar'] ?? selectedSubjectData['name'] ?? 'Unknown';
      final topicName = selectedTopicData['name_ar'] ?? selectedTopicData['name'] ?? 'Unknown';

      final videoId = await secureBunny.uploadVideo(
        videoFile: _videoFile ?? File(_platformFile!.name),
        title: _titleArController.text.isNotEmpty ? _titleArController.text : _titleController.text,
        curriculumName: 'telebac+',
        gradeName: gradeName,
        subjectName: subjectName,
        topicName: topicName,
        onProgress: (progress) {
          setState(() => _uploadProgress = progress);
        },
      );

      if (videoId == null) {
        throw Exception('Failed to upload video to BunnyCDN');
      }

      // Create video record in Supabase with new structure
      await _supabase.from('videos').insert({
        'topic_id': _selectedTopic,
        'bunny_video_id': videoId,
        'title': _titleController.text.isNotEmpty ? _titleController.text : null,
        'title_ar': _titleArController.text.isNotEmpty ? _titleArController.text : null,
        'description': _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
        'description_ar': _descriptionArController.text.isNotEmpty ? _descriptionArController.text : null,
        'duration_seconds': 0, // Will be updated by BunnyCDN webhook
        'thumbnail_url': secureBunny.getVideoThumbnailUrl(videoId),
        'url_360p': secureBunny.getVideoStreamUrl(videoId, '360p'),
        'url_480p': secureBunny.getVideoStreamUrl(videoId, '480p'),
        'url_720p': secureBunny.getVideoStreamUrl(videoId, '720p'),
        'url_1080p': secureBunny.getVideoStreamUrl(videoId, '1080p'),
        'encryption_key_id': 'default_key',
        'is_downloadable': true,
        'display_order': 1,
        'is_free': false,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الفيديو بنجاح!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفع الفيديو: $e')),
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
    return AlertDialog(
      title: const Text('رفع فيديو جديد'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Grade Dropdown
              DropdownButtonFormField<String>(
                value: _selectedGrade,
                decoration: const InputDecoration(labelText: 'المستوى'),
                items: _grades.map((grade) {
                  return DropdownMenuItem<String>(
                    value: grade['id'] as String,
                    child: Text(grade['name_ar'] ?? grade['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedGrade = value);
                  if (value != null) _loadSubjects(value);
                },
                validator: (value) => value == null ? 'اختر المستوى' : null,
              ),

              // Subject Dropdown
              DropdownButtonFormField<String>(
                value: _selectedSubject,
                decoration: const InputDecoration(labelText: 'المادة'),
                items: _subjects.map((subject) {
                  return DropdownMenuItem<String>(
                    value: subject['id'] as String,
                    child: Text(subject['name_ar'] ?? subject['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedSubject = value);
                  if (value != null) _loadTopics(value);
                },
                validator: (value) => value == null ? 'اختر المادة' : null,
              ),

              // Topic Dropdown
              DropdownButtonFormField<String>(
                value: _selectedTopic,
                decoration: const InputDecoration(labelText: 'الموضوع'),
                items: _topics.map((topic) {
                  return DropdownMenuItem<String>(
                    value: topic['id'] as String,
                    child: Text(topic['name_ar'] ?? topic['name']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedTopic = value),
                validator: (value) => value == null ? 'اختر الموضوع' : null,
              ),

              const SizedBox(height: 16),

              // Video Title (Arabic)
              TextFormField(
                controller: _titleArController,
                decoration: const InputDecoration(
                  labelText: 'عنوان الدرس (بالعربية) *',
                  hintText: 'مثال: مقدمة في الجبر',
                ),
                validator: (value) => value == null || value.isEmpty ? 'أدخل عنوان الدرس' : null,
              ),

              const SizedBox(height: 16),

              // Video Description (Arabic)
              TextFormField(
                controller: _descriptionArController,
                decoration: const InputDecoration(
                  labelText: 'وصف الدرس (بالعربية)',
                  hintText: 'وصف مختصر للدرس',
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 16),

              // Video File Picker
              OutlinedButton.icon(
                onPressed: _isUploading ? null : _pickVideoFile,
                icon: const Icon(Icons.video_file),
                label: Text(_videoFile == null ? 'اختر ملف فيديو' : 'تم اختيار الملف'),
              ),

              if (_platformFile != null || _videoFile != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _platformFile != null
                      ? _platformFile!.name
                      : (_videoFile != null ? _videoFile!.path.split('/').last : ''),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),

              if (_isUploading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 8),
                Text(
                  '${(_uploadProgress * 100).toStringAsFixed(0)}% جاري الرفع...',
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _uploadVideo,
          child: const Text('رفع'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleArController.dispose();
    _descriptionController.dispose();
    _descriptionArController.dispose();
    super.dispose();
  }
}
