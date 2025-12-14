import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import '../../utils/admin_theme.dart';
import 'package:path/path.dart' as path;

/// Modern PDF Upload Screen
/// Upload PDF files for written lessons (الدروس المكتوبة)

class ModernPDFUploadScreen extends StatefulWidget {
  final bool isEmbedded; // If true, don't show AppBar (will be in AdminLayout)

  const ModernPDFUploadScreen({super.key, this.isEmbedded = false});

  @override
  State<ModernPDFUploadScreen> createState() => _ModernPDFUploadScreenState();
}

class _ModernPDFUploadScreenState extends State<ModernPDFUploadScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _titleArController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedGradeId;
  String? _selectedSubjectId;
  String? _selectedTopicId;

  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _topics = [];

  File? _pdfFile;
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

  Future<void> _pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      allowMultiple: false,
    );

    if (result != null && result.files.isNotEmpty) {
      setState(() => _pdfFile = File(result.files.first.path!));
    }
  }

  Future<void> _uploadPDF() async {
    if (!_formKey.currentState!.validate() || _pdfFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إكمال جميع الحقول واختيار ملف PDF')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      // Upload PDF to Supabase Storage
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(_pdfFile!.path)}';
      final bytes = await _pdfFile!.readAsBytes();

      setState(() => _uploadProgress = 0.3);

      await _supabase.storage
          .from('pdf-lessons')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
            ),
          );

      setState(() => _uploadProgress = 0.6);

      // Get public URL
      final pdfUrl = _supabase.storage
          .from('pdf-lessons')
          .getPublicUrl(fileName);

      setState(() => _uploadProgress = 0.8);

      // Create lesson entry with content_category = 'written_lesson'
      await _supabase.from('lessons').insert({
        'topic_id': _selectedTopicId,
        'title': _titleController.text,
        'title_ar': _titleArController.text,
        'description': _descriptionController.text,
        'lesson_type': 'document',
        'content_category': 'written_lesson', // ✅ Mark as written lesson
        'pdf_url': pdfUrl, // ✅ Save PDF URL
        'display_order': 999,
        'is_free': false,
        'is_active': true,
      });

      setState(() => _uploadProgress = 1.0);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم رفع الدرس المكتوب بنجاح! ✓')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
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
                    gradient: AdminTheme.gradientPink,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 32,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'رفع درس مكتوب (PDF)',
                              style: AdminTheme.titleMedium,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'أضف دروساً مكتوبة بصيغة PDF للطلاب',
                              style: AdminTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Lesson Info
                Container(
                  decoration: AdminTheme.glassCard(),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('معلومات الدرس', style: AdminTheme.titleSmall),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الدرس (بالإنجليزية)',
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'أدخل العنوان' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleArController,
                        decoration: const InputDecoration(
                          labelText: 'عنوان الدرس (بالعربية)',
                          prefixIcon: Icon(Icons.translate_rounded),
                        ),
                        validator: (value) =>
                            value?.isEmpty ?? true ? 'أدخل العنوان بالعربية' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'وصف الدرس',
                          prefixIcon: Icon(Icons.description_rounded),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Selection Cards
                Row(
                  children: [
                    Expanded(child: _buildGradeSelector()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildSubjectSelector()),
                  ],
                ),

                const SizedBox(height: 16),

                _buildTopicSelector(),

                const SizedBox(height: 32),

                // PDF Picker
                _buildPDFPicker(),

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
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AdminTheme.accentPink,
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
                    gradient: AdminTheme.gradientPink,
                  ),
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _uploadPDF,
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
                          _isUploading ? 'جاري الرفع...' : 'رفع الدرس المكتوب',
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
          title: const Text('رفع درس مكتوب (PDF)'),
          backgroundColor: AdminTheme.secondaryDark,
        ),
        body: content,
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
              if (value != null) _loadSubjects(value);
            },
            validator: (value) => value == null ? 'اختر الفصل' : null,
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

  Widget _buildPDFPicker() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_pdfFile == null) ...[
            Icon(
              Icons.picture_as_pdf_rounded,
              size: 80,
              color: Colors.white.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            const Text(
              'لم يتم اختيار ملف PDF',
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _pdfFile!.path.split('/').last,
                          style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${(_pdfFile!.lengthSync() / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: AdminTheme.bodySmall.copyWith(color: Colors.white70),
                        ),
                      ],
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
              onPressed: _pickPDF,
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
                  const Icon(Icons.picture_as_pdf_rounded),
                  const SizedBox(width: 12),
                  Text(
                    _pdfFile == null ? 'اختر ملف PDF' : 'اختر ملف آخر',
                    style: AdminTheme.titleSmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleArController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
