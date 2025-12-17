import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import '../../services/secure_bunny_service.dart';
import '../../services/pdf_service.dart';
import '../../services/thumbnail_service.dart';
import '../../utils/admin_theme.dart';

/// Enhanced Video Manager Screen
/// Complete video management with filtering, preview, edit, and delete

class EnhancedVideoManagerScreen extends StatefulWidget {
  final bool isEmbedded;

  const EnhancedVideoManagerScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<EnhancedVideoManagerScreen> createState() => _EnhancedVideoManagerScreenState();
}

class _EnhancedVideoManagerScreenState extends State<EnhancedVideoManagerScreen> {
  final _supabase = Supabase.instance.client;

  // Data
  List<Map<String, dynamic>> _allVideos = [];
  List<Map<String, dynamic>> _filteredVideos = [];
  List<Map<String, dynamic>> _curricula = [];
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _specializations = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _topics = [];

  // State
  bool _isLoading = true;
  bool _isCompactView = false;
  bool _isSyncing = false;
  int _videosNeedingSync = 0;
  String? _selectedCurriculumId;
  String? _selectedGradeId;
  String? _selectedSpecializationId;
  String? _selectedSubjectId;
  String? _selectedTopicId;
  String? _selectedContentCategory;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadCurricula(),
      _loadAllVideos(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _loadCurricula() async {
    try {
      final response = await _supabase
          .from('curricula')
          .select()
          .eq('is_active', true)
          .order('display_order');
      setState(() => _curricula = List<Map<String, dynamic>>.from(response));
    } catch (e) {
      debugPrint('Error loading curricula: $e');
    }
  }

  Future<void> _loadGrades(String? curriculumId) async {
    try {
      var query = _supabase
          .from('grades')
          .select()
          .eq('is_active', true);

      if (curriculumId != null) {
        query = query.eq('curriculum_id', curriculumId);
      }

      final response = await query.order('display_order');

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
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading grades: $e');
    }
  }

  Future<void> _loadSpecializations(String? gradeId) async {
    try {
      var query = _supabase
          .from('specializations')
          .select()
          .eq('is_active', true);

      if (gradeId != null) {
        query = query.eq('grade_id', gradeId);
      }

      final response = await query.order('display_order');

      setState(() {
        _specializations = List<Map<String, dynamic>>.from(response);
        _selectedSpecializationId = null;
        _subjects = [];
        _selectedSubjectId = null;
        _topics = [];
        _selectedTopicId = null;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading specializations: $e');
    }
  }

  Future<void> _loadSubjects(String? gradeId, String? specializationId) async {
    try {
      var query = _supabase
          .from('subjects')
          .select()
          .eq('is_active', true);

      if (gradeId != null) {
        query = query.eq('grade_id', gradeId);
      }

      // Filter by specialization if selected, or show subjects without specialization
      if (specializationId != null) {
        query = query.eq('specialization_id', specializationId);
      }

      final response = await query.order('display_order');

      setState(() {
        _subjects = List<Map<String, dynamic>>.from(response);
        _selectedSubjectId = null;
        _topics = [];
        _selectedTopicId = null;
      });
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading subjects: $e');
    }
  }

  Future<void> _loadTopics(String subjectId) async {
    try {
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
      _applyFilters();
    } catch (e) {
      debugPrint('Error loading topics: $e');
    }
  }

  Future<void> _loadAllVideos() async {
    try {
      // Load all videos with their complete classification hierarchy in ONE query
      // This supports both direct topic_id and lesson_id → topic_id relationships
      final response = await _supabase
          .from('videos')
          .select('''
            *,
            topics:topic_id(
              id,
              name,
              name_ar,
              subjects(
                id,
                name,
                name_ar,
                specialization_id,
                specializations(
                  id,
                  name_ar
                ),
                grades(
                  id,
                  name,
                  name_ar,
                  curriculum_id,
                  curricula(
                    id,
                    name,
                    name_ar
                  )
                )
              )
            ),
            lessons:lesson_id(
              id,
              title,
              pdf_url,
              topic_id,
              topics(
                id,
                name,
                name_ar,
                subjects(
                  id,
                  name,
                  name_ar,
                  specialization_id,
                  specializations(
                    id,
                    name_ar
                  ),
                  grades(
                    id,
                    name,
                    name_ar,
                    curriculum_id,
                    curricula(
                      id,
                      name,
                      name_ar
                    )
                  )
                )
              )
            )
          ''')
          .order('display_order', ascending: true);

      final allVideos = List<Map<String, dynamic>>.from(response);

      // Process videos to use direct topic_id if available, otherwise use lesson → topic
      for (final video in allVideos) {
        // Priority 1: Direct topic_id relationship (current method)
        if (video['topics'] != null) {
          // Already has direct topic - keep it
          final lesson = video['lessons'];
          video['lesson'] = lesson; // Keep lesson for PDF access
        }
        // Priority 2: lesson_id → topic_id relationship (legacy method)
        else if (video['lessons'] != null && video['lessons']['topics'] != null) {
          video['topics'] = video['lessons']['topics'];
          video['lesson'] = video['lessons'];
        }
        // No classification found
        else {
          video['topics'] = null;
          video['lesson'] = video['lessons'];
        }
      }

      setState(() {
        _allVideos = allVideos;
        _filteredVideos = _allVideos;
        _videosNeedingSync = _allVideos.where((v) => (v['duration_seconds'] ?? 0) <= 5).length;
      });

      debugPrint('✅ Loaded ${_allVideos.length} videos successfully');
      debugPrint('📊 Videos with classification: ${_allVideos.where((v) => v['topics'] != null).length}');
      debugPrint('⚠️  Videos without classification: ${_allVideos.where((v) => v['topics'] == null).length}');
      debugPrint('🔄 Videos needing sync: $_videosNeedingSync');
    } catch (e) {
      debugPrint('Error loading videos: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الفيديوهات: $e')),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredVideos = _allVideos.where((video) {
        final topic = video['topics'] as Map<String, dynamic>?;

        // If video has no topic, show it only when no filters are applied
        if (topic == null) {
          return _selectedCurriculumId == null &&
              _selectedGradeId == null &&
              _selectedSpecializationId == null &&
              _selectedSubjectId == null &&
              _selectedTopicId == null &&
              _selectedContentCategory == null;
        }

        final subject = topic['subjects'] as Map<String, dynamic>?;
        final grade = subject?['grades'] as Map<String, dynamic>?;

        // Apply curriculum filter
        if (_selectedCurriculumId != null && grade?['curriculum_id'] != _selectedCurriculumId) {
          return false;
        }

        // Apply grade filter
        if (_selectedGradeId != null && grade?['id'] != _selectedGradeId) {
          return false;
        }

        // Apply specialization filter
        if (_selectedSpecializationId != null && subject?['specialization_id'] != _selectedSpecializationId) {
          return false;
        }

        // Apply subject filter
        if (_selectedSubjectId != null && subject?['id'] != _selectedSubjectId) {
          return false;
        }

        // Apply topic filter
        if (_selectedTopicId != null && topic['id'] != _selectedTopicId) {
          return false;
        }

        // Apply content category filter
        if (_selectedContentCategory != null) {
          final videoCategory = video['content_category'] as String?;
          if (videoCategory != _selectedContentCategory) {
            return false;
          }
        }

        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCurriculumId = null;
      _selectedGradeId = null;
      _selectedSpecializationId = null;
      _selectedSubjectId = null;
      _selectedTopicId = null;
      _selectedContentCategory = null;
      _grades = [];
      _specializations = [];
      _subjects = [];
      _topics = [];
      _filteredVideos = _allVideos;
    });
  }

  /// Sync video durations from BunnyCDN
  Future<void> _syncVideoDurations() async {
    if (_videosNeedingSync == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ جميع الفيديوهات محدثة بالفعل!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final response = await http.post(
        Uri.parse('https://ctupxmtreqyxubtphkrk.supabase.co/functions/v1/sync-video-durations'),
        headers: {
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken ?? ""}',
          'Content-Type': 'application/json',
        },
        body: json.encode({}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final updated = result['updated'] ?? 0;
        final failed = result['failed'] ?? 0;
        final total = result['total'] ?? 0;

        // Reload videos to reflect changes
        await _loadAllVideos();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ تم تحديث $updated من $total فيديو بنجاح!' +
                (failed > 0 ? '\n⚠️ فشل تحديث $failed فيديو' : ''),
              ),
              backgroundColor: failed > 0 ? Colors.orange : Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        throw Exception('فشل الاتصال بالخادم: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في المزامنة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  /// Update video content category instantly
  Future<void> _updateVideoCategory(String videoId, String newCategory, int videoIndex) async {
    try {
      // Update in Supabase
      await _supabase
          .from('videos')
          .update({'content_category': newCategory})
          .eq('id', videoId);

      // Update in local state immediately for instant UI update
      setState(() {
        // Update in _allVideos
        final allVideoIndex = _allVideos.indexWhere((v) => v['id'] == videoId);
        if (allVideoIndex != -1) {
          _allVideos[allVideoIndex]['content_category'] = newCategory;
        }

        // Update in _filteredVideos
        if (videoIndex >= 0 && videoIndex < _filteredVideos.length) {
          _filteredVideos[videoIndex]['content_category'] = newCategory;
        }
      });

      if (mounted) {
        // Show success message
        String categoryName = '';
        switch (newCategory) {
          case 'lesson':
            categoryName = 'درس مرئي';
            break;
          case 'solved_exercise':
            categoryName = 'تمرين محلول';
            break;
          case 'summary':
            categoryName = 'ملخص';
            break;
          case 'solved_baccalaureate':
            categoryName = 'باكالوريا محلولة';
            break;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ تم تغيير الفئة إلى: $categoryName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error updating video category: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الفئة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// تحريك الفيديو للأعلى (تقليل display_order)
  /// Move video up (decrease display_order)
  Future<void> _moveUp(int index) async {
    if (index <= 0) return; // لا يمكن تحريك العنصر الأول للأعلى

    final currentVideo = _filteredVideos[index];
    final previousVideo = _filteredVideos[index - 1];

    final currentOrder = currentVideo['display_order'] ?? index;
    final previousOrder = previousVideo['display_order'] ?? (index - 1);

    try {
      // تبديل الترتيب بين الفيديوهين
      await _supabase
          .from('videos')
          .update({'display_order': previousOrder})
          .eq('id', currentVideo['id']);

      await _supabase
          .from('videos')
          .update({'display_order': currentOrder})
          .eq('id', previousVideo['id']);

      // تحديث القائمة المحلية
      setState(() {
        _filteredVideos[index]['display_order'] = previousOrder;
        _filteredVideos[index - 1]['display_order'] = currentOrder;
        final temp = _filteredVideos[index];
        _filteredVideos[index] = _filteredVideos[index - 1];
        _filteredVideos[index - 1] = temp;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحريك الفيديو للأعلى'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error moving video up: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحريك الفيديو: $e')),
        );
      }
    }
  }

  /// تحريك الفيديو للأسفل (زيادة display_order)
  /// Move video down (increase display_order)
  Future<void> _moveDown(int index) async {
    if (index >= _filteredVideos.length - 1) return; // لا يمكن تحريك العنصر الأخير للأسفل

    final currentVideo = _filteredVideos[index];
    final nextVideo = _filteredVideos[index + 1];

    final currentOrder = currentVideo['display_order'] ?? index;
    final nextOrder = nextVideo['display_order'] ?? (index + 1);

    try {
      // تبديل الترتيب بين الفيديوهين
      await _supabase
          .from('videos')
          .update({'display_order': nextOrder})
          .eq('id', currentVideo['id']);

      await _supabase
          .from('videos')
          .update({'display_order': currentOrder})
          .eq('id', nextVideo['id']);

      // تحديث القائمة المحلية
      setState(() {
        _filteredVideos[index]['display_order'] = nextOrder;
        _filteredVideos[index + 1]['display_order'] = currentOrder;
        final temp = _filteredVideos[index];
        _filteredVideos[index] = _filteredVideos[index + 1];
        _filteredVideos[index + 1] = temp;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحريك الفيديو للأسفل'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error moving video down: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحريك الفيديو: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = Scaffold(
      backgroundColor: AdminTheme.primaryDark,
      appBar: widget.isEmbedded ? null : AppBar(
        title: const Text('إدارة الفيديوهات'),
        backgroundColor: AdminTheme.secondaryDark,
      ),
      body: Column(
        children: [
          // Filters Section
          _buildFiltersSection(),

          // Stats Header
          _buildStatsHeader(),

          // Videos Grid/List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredVideos.isEmpty
                    ? _buildEmptyState()
                    : _isCompactView
                        ? _buildCompactList()
                        : _buildVideosGrid(),
          ),
        ],
      ),
    );

    return widget.isEmbedded ? content : Theme(
      data: AdminTheme.darkTheme,
      child: content,
    );
  }

  Widget _buildFiltersSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.secondaryDark,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              const Text(
                'فلترة الفيديوهات',
                style: AdminTheme.titleSmall,
              ),
              const Spacer(),
              // Sync button with badge
              if (_videosNeedingSync > 0)
                Badge(
                  label: Text('$_videosNeedingSync'),
                  backgroundColor: Colors.orange,
                  child: ElevatedButton.icon(
                    onPressed: _isSyncing ? null : _syncVideoDurations,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.sync, size: 18),
                    label: Text(_isSyncing ? 'جاري المزامنة...' : 'مزامنة الأطوال'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                ),
              if (_videosNeedingSync > 0) const SizedBox(width: 12),
              if (_selectedCurriculumId != null || _selectedGradeId != null || _selectedSpecializationId != null || _selectedSubjectId != null || _selectedTopicId != null || _selectedContentCategory != null)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('إلغاء الفلاتر'),
                  style: TextButton.styleFrom(
                    foregroundColor: AdminTheme.accentBlue,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Curriculum Filter
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedCurriculumId,
                  decoration: InputDecoration(
                    labelText: 'المنهج',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AdminTheme.primaryDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: AdminTheme.secondaryDark,
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('جميع المناهج', style: TextStyle(color: Colors.white70)),
                    ),
                    ..._curricula.map((curriculum) {
                      return DropdownMenuItem(
                        value: curriculum['id'],
                        child: Text(
                          curriculum['name_ar'] ?? curriculum['name'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedCurriculumId = value);
                    if (value != null) {
                      _loadGrades(value);
                    } else {
                      setState(() {
                        _grades = [];
                        _specializations = [];
                        _subjects = [];
                        _topics = [];
                        _selectedGradeId = null;
                        _selectedSpecializationId = null;
                        _selectedSubjectId = null;
                        _selectedTopicId = null;
                      });
                      _applyFilters();
                    }
                  },
                ),
              ),

              // Grade Filter
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedGradeId,
                  decoration: InputDecoration(
                    labelText: 'المستوى',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AdminTheme.primaryDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: AdminTheme.secondaryDark,
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('جميع المستويات', style: TextStyle(color: Colors.white70)),
                    ),
                    ..._grades.map((grade) {
                      return DropdownMenuItem(
                        value: grade['id'],
                        child: Text(
                          grade['name_ar'] ?? grade['name'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }),
                  ],
                  onChanged: _selectedCurriculumId == null ? null : (value) {
                    setState(() => _selectedGradeId = value);
                    if (value != null) {
                      _loadSpecializations(value);
                    } else {
                      setState(() {
                        _specializations = [];
                        _subjects = [];
                        _topics = [];
                        _selectedSpecializationId = null;
                        _selectedSubjectId = null;
                        _selectedTopicId = null;
                      });
                      _applyFilters();
                    }
                  },
                ),
              ),

              // Specialization Filter
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedSpecializationId,
                  decoration: InputDecoration(
                    labelText: 'الشعبة',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AdminTheme.primaryDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: AdminTheme.secondaryDark,
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('جميع الشعب', style: TextStyle(color: Colors.white70)),
                    ),
                    ..._specializations.map((specialization) {
                      return DropdownMenuItem(
                        value: specialization['id'],
                        child: Text(
                          specialization['name_ar'] ?? specialization['name'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }),
                  ],
                  onChanged: _selectedGradeId == null ? null : (value) {
                    setState(() => _selectedSpecializationId = value);
                    if (value != null) {
                      _loadSubjects(_selectedGradeId, value);
                    } else {
                      setState(() {
                        _subjects = [];
                        _topics = [];
                        _selectedSubjectId = null;
                        _selectedTopicId = null;
                      });
                      _applyFilters();
                    }
                  },
                ),
              ),

              // Subject Filter
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedSubjectId,
                  decoration: InputDecoration(
                    labelText: 'المادة',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AdminTheme.primaryDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: AdminTheme.secondaryDark,
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('جميع المواد', style: TextStyle(color: Colors.white70)),
                    ),
                    ..._subjects.map((subject) {
                      return DropdownMenuItem(
                        value: subject['id'],
                        child: Text(
                          subject['name_ar'] ?? subject['name'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }),
                  ],
                  onChanged: _selectedGradeId == null ? null : (value) {
                    setState(() => _selectedSubjectId = value);
                    if (value != null) {
                      _loadTopics(value);
                    } else {
                      setState(() {
                        _topics = [];
                        _selectedTopicId = null;
                      });
                      _applyFilters();
                    }
                  },
                ),
              ),

              // Topic Filter
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedTopicId,
                  decoration: InputDecoration(
                    labelText: 'الموضوع',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AdminTheme.primaryDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: AdminTheme.secondaryDark,
                  style: const TextStyle(color: Colors.white),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('جميع المواضيع', style: TextStyle(color: Colors.white70)),
                    ),
                    ..._topics.map((topic) {
                      return DropdownMenuItem(
                        value: topic['id'],
                        child: Text(
                          topic['name_ar'] ?? topic['name'],
                          style: const TextStyle(color: Colors.white),
                        ),
                      );
                    }),
                  ],
                  onChanged: _selectedSubjectId == null ? null : (value) {
                    setState(() => _selectedTopicId = value);
                    _applyFilters();
                  },
                ),
              ),

              // Content Category Filter
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedContentCategory,
                  decoration: InputDecoration(
                    labelText: 'نوع المحتوى',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AdminTheme.primaryDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  dropdownColor: AdminTheme.secondaryDark,
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('جميع الأنواع', style: TextStyle(color: Colors.white70)),
                    ),
                    DropdownMenuItem<String>(
                      value: 'lesson',
                      child: Row(
                        children: [
                          Icon(Icons.video_library, color: Colors.blue, size: 18),
                          SizedBox(width: 8),
                          Text('درس مرئي', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    DropdownMenuItem<String>(
                      value: 'solved_exercise',
                      child: Row(
                        children: [
                          Icon(Icons.assignment, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text('تمرين محلول', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    DropdownMenuItem<String>(
                      value: 'summary',
                      child: Row(
                        children: [
                          Icon(Icons.summarize, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text('ملخص', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    DropdownMenuItem<String>(
                      value: 'solved_baccalaureate',
                      child: Row(
                        children: [
                          Icon(Icons.school, color: Colors.purple, size: 18),
                          SizedBox(width: 8),
                          Text('باكالوريا محلولة', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedContentCategory = value);
                    _applyFilters();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminTheme.secondaryDark.withOpacity(0.5),
      ),
      child: Row(
        children: [
          Icon(Icons.video_library, color: AdminTheme.accentBlue, size: 24),
          const SizedBox(width: 12),
          Text(
            'عدد الفيديوهات: ${_filteredVideos.length}',
            style: AdminTheme.titleSmall,
          ),
          if (_selectedGradeId != null || _selectedSubjectId != null || _selectedTopicId != null || _selectedContentCategory != null) ...[
            const SizedBox(width: 8),
            Text(
              '(${_allVideos.length} الإجمالي)',
              style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
            ),
          ],
          const Spacer(),
          // View toggle buttons
          Container(
            decoration: BoxDecoration(
              color: AdminTheme.primaryDark,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () => setState(() => _isCompactView = false),
                  icon: Icon(
                    Icons.grid_view,
                    color: !_isCompactView ? AdminTheme.accentBlue : Colors.white54,
                  ),
                  tooltip: 'عرض شبكي',
                ),
                Container(width: 1, height: 24, color: Colors.white10),
                IconButton(
                  onPressed: () => setState(() => _isCompactView = true),
                  icon: Icon(
                    Icons.view_list,
                    color: _isCompactView ? AdminTheme.accentBlue : Colors.white54,
                  ),
                  tooltip: 'عرض مضغوط',
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _loadAllVideos,
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'تحديث',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.video_library_outlined,
            size: 80,
            color: Colors.white24,
          ),
          const SizedBox(height: 16),
          Text(
            'لا توجد فيديوهات',
            style: AdminTheme.titleLarge.copyWith(color: Colors.white54),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedGradeId != null || _selectedSubjectId != null || _selectedTopicId != null || _selectedContentCategory != null
                ? 'لا توجد فيديوهات تطابق الفلاتر المحددة'
                : 'قم برفع فيديوهات من قسم "دروس مرئية"',
            style: AdminTheme.bodyMedium.copyWith(color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildVideosGrid() {
    return RefreshIndicator(
      onRefresh: _loadAllVideos,
      child: GridView.builder(
        padding: const EdgeInsets.all(20),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 400,
          childAspectRatio: 0.85, // Balanced height for all content (width/height ratio)
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: _filteredVideos.length,
        itemBuilder: (context, index) {
          return _buildVideoCard(_filteredVideos[index], index);
        },
      ),
    );
  }

  /// Build content category buttons widget
  Widget _buildCategoryButtons(Map<String, dynamic> video, int index, {bool isCompact = false}) {
    final currentCategory = video['content_category'] as String? ?? 'lesson';
    final videoId = video['id'] as String;

    final categories = [
      {'value': 'lesson', 'label': 'درس', 'icon': Icons.video_library, 'color': Colors.blue},
      {'value': 'solved_exercise', 'label': 'تمرين', 'icon': Icons.assignment, 'color': Colors.green},
      {'value': 'summary', 'label': 'ملخص', 'icon': Icons.summarize, 'color': Colors.orange},
      {'value': 'solved_baccalaureate', 'label': 'باك', 'icon': Icons.school, 'color': Colors.purple},
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: categories.map((cat) {
        final isActive = currentCategory == cat['value'];
        final color = cat['color'] as Color;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: InkWell(
              onTap: () => _updateVideoCategory(videoId, cat['value'] as String, index),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isCompact ? 6 : 4,
                  vertical: isCompact ? 8 : 6,
                ),
                decoration: BoxDecoration(
                  color: isActive ? color.withOpacity(0.9) : color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isActive ? color : color.withOpacity(0.5),
                    width: isActive ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: isCompact ? 16 : 14,
                      color: isActive ? Colors.white : color,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        fontSize: isCompact ? 10 : 9,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive ? Colors.white : color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video, int index) {
    final topic = video['topics'] as Map<String, dynamic>?;
    final subject = topic?['subjects'] as Map<String, dynamic>?;
    final grade = subject?['grades'] as Map<String, dynamic>?;
    final thumbnailUrl = video['thumbnail_url'] as String?;

    // Determine display texts
    final gradeName = grade?['name_ar'] ?? grade?['name'] ?? 'غير محدد';
    final subjectName = subject?['name_ar'] ?? subject?['name'] ?? 'غير محدد';
    final topicName = topic?['name_ar'] ?? topic?['name'] ?? 'غير مصنف';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AdminTheme.secondaryDark,
            AdminTheme.secondaryDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Thumbnail with Play Button Overlay
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    image: thumbnailUrl != null
                        ? DecorationImage(
                            image: NetworkImage(thumbnailUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: thumbnailUrl == null
                      ? const Center(
                          child: Icon(
                            Icons.video_library_outlined,
                            size: 48,
                            color: Colors.white24,
                          ),
                        )
                      : null,
                ),
                // Play button overlay
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showVideoPreview(video),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.3),
                            ],
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.play_circle_outline,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Duration badge
                if (video['duration_seconds'] != null)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatDuration(video['duration_seconds']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                // PDF badge
                if (video['lesson'] != null && video['lesson']['pdf_url'] != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.picture_as_pdf, color: Colors.white, size: 14),
                          SizedBox(width: 4),
                          Text(
                            'PDF',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Video Info
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    video['title_ar'] ?? video['title'] ?? 'بدون عنوان',
                    style: AdminTheme.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  // Hierarchy
                  Text(
                    '$gradeName • $subjectName',
                    style: AdminTheme.bodySmall.copyWith(color: AdminTheme.accentBlue),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    topicName,
                    style: AdminTheme.caption.copyWith(color: Colors.white54),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Content category buttons
                  _buildCategoryButtons(video, index),
                  const Spacer(),
                  // Reorder buttons row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Order badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AdminTheme.accentBlue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Move up button
                      IconButton(
                        onPressed: index > 0 ? () => _moveUp(index) : null,
                        icon: const Icon(Icons.arrow_upward, size: 18),
                        color: index > 0 ? Colors.green.shade300 : Colors.white24,
                        tooltip: 'تحريك للأعلى',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      // Move down button
                      IconButton(
                        onPressed: index < _filteredVideos.length - 1 ? () => _moveDown(index) : null,
                        icon: const Icon(Icons.arrow_downward, size: 18),
                        color: index < _filteredVideos.length - 1 ? Colors.orange.shade300 : Colors.white24,
                        tooltip: 'تحريك للأسفل',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Action buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Thumbnail button
                      IconButton(
                        onPressed: () => _showThumbnailDialog(video),
                        icon: Icon(
                          _isCustomThumbnail(video['thumbnail_url'])
                              ? Icons.image
                              : Icons.image_outlined,
                          size: 20,
                        ),
                        color: _isCustomThumbnail(video['thumbnail_url'])
                            ? Colors.green.shade300
                            : Colors.white38,
                        tooltip: 'إدارة الصورة المصغرة',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // PDF button
                      IconButton(
                        onPressed: video['lesson'] != null ? () => _showPdfDialog(video) : null,
                        icon: Icon(
                          video['lesson'] != null && video['lesson']['pdf_url'] != null
                              ? Icons.picture_as_pdf
                              : Icons.picture_as_pdf_outlined,
                          size: 20,
                        ),
                        color: video['lesson'] != null && video['lesson']['pdf_url'] != null
                            ? Colors.red.shade300
                            : Colors.white38,
                        tooltip: video['lesson'] != null ? 'إدارة PDF' : 'لا يوجد درس مرتبط',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showReplaceVideoDialog(video),
                        icon: const Icon(Icons.swap_horiz, size: 20),
                        color: Colors.orange.shade300,
                        tooltip: 'استبدال الفيديو',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _showEditDialog(video),
                        icon: const Icon(Icons.edit, size: 20),
                        color: Colors.white70,
                        tooltip: 'تعديل',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => _confirmDelete(video),
                        icon: const Icon(Icons.delete, size: 20),
                        color: Colors.red.shade300,
                        tooltip: 'حذف',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactList() {
    return RefreshIndicator(
      onRefresh: _loadAllVideos,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _filteredVideos.length,
        itemBuilder: (context, index) {
          return _buildCompactVideoCard(_filteredVideos[index], index);
        },
      ),
    );
  }

  Widget _buildCompactVideoCard(Map<String, dynamic> video, int index) {
    final topic = video['topics'] as Map<String, dynamic>?;
    final subject = topic?['subjects'] as Map<String, dynamic>?;
    final grade = subject?['grades'] as Map<String, dynamic>?;
    final thumbnailUrl = video['thumbnail_url'] as String?;

    // Determine display texts
    final gradeName = grade?['name_ar'] ?? grade?['name'] ?? 'غير محدد';
    final subjectName = subject?['name_ar'] ?? subject?['name'] ?? 'غير محدد';
    final topicName = topic?['name_ar'] ?? topic?['name'] ?? 'غير مصنف';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AdminTheme.secondaryDark,
            AdminTheme.secondaryDark.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showVideoPreview(video),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 120,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  image: thumbnailUrl != null
                      ? DecorationImage(
                          image: NetworkImage(thumbnailUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: Stack(
                  children: [
                    if (thumbnailUrl == null)
                      const Center(
                        child: Icon(
                          Icons.video_library_outlined,
                          size: 32,
                          color: Colors.white24,
                        ),
                      ),
                    Center(
                      child: Icon(
                        Icons.play_circle_outline,
                        size: 40,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                    if (video['duration_seconds'] != null)
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatDuration(video['duration_seconds']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Video Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['title_ar'] ?? video['title'] ?? 'بدون عنوان',
                      style: AdminTheme.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$gradeName • $subjectName • $topicName',
                      style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    // Content category buttons
                    _buildCategoryButtons(video, index, isCompact: true),
                  ],
                ),
              ),

              // Order badge & reorder buttons
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AdminTheme.accentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${index + 1}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Move up button
              IconButton(
                onPressed: index > 0 ? () => _moveUp(index) : null,
                icon: const Icon(Icons.arrow_upward, size: 20),
                color: index > 0 ? Colors.green.shade300 : Colors.white24,
                tooltip: 'تحريك للأعلى',
              ),
              // Move down button
              IconButton(
                onPressed: index < _filteredVideos.length - 1 ? () => _moveDown(index) : null,
                icon: const Icon(Icons.arrow_downward, size: 20),
                color: index < _filteredVideos.length - 1 ? Colors.orange.shade300 : Colors.white24,
                tooltip: 'تحريك للأسفل',
              ),
              const SizedBox(width: 4),
              // Action buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Thumbnail button
                  IconButton(
                    onPressed: () => _showThumbnailDialog(video),
                    icon: Icon(
                      _isCustomThumbnail(video['thumbnail_url'])
                          ? Icons.image
                          : Icons.image_outlined,
                      size: 20,
                    ),
                    color: _isCustomThumbnail(video['thumbnail_url'])
                        ? Colors.green.shade300
                        : Colors.white38,
                    tooltip: 'إدارة الصورة المصغرة',
                  ),
                  // PDF button
                  IconButton(
                    onPressed: video['lesson'] != null ? () => _showPdfDialog(video) : null,
                    icon: Icon(
                      video['lesson'] != null && video['lesson']['pdf_url'] != null
                          ? Icons.picture_as_pdf
                          : Icons.picture_as_pdf_outlined,
                      size: 20,
                    ),
                    color: video['lesson'] != null && video['lesson']['pdf_url'] != null
                        ? Colors.red.shade300
                        : Colors.white38,
                    tooltip: video['lesson'] != null ? 'إدارة PDF' : 'لا يوجد درس مرتبط',
                  ),
                  IconButton(
                    onPressed: () => _showReplaceVideoDialog(video),
                    icon: const Icon(Icons.swap_horiz, size: 20),
                    color: Colors.orange.shade300,
                    tooltip: 'استبدال الفيديو',
                  ),
                  IconButton(
                    onPressed: () => _showEditDialog(video),
                    icon: const Icon(Icons.edit, size: 20),
                    color: Colors.white70,
                    tooltip: 'تعديل',
                  ),
                  IconButton(
                    onPressed: () => _confirmDelete(video),
                    icon: const Icon(Icons.delete, size: 20),
                    color: Colors.red.shade300,
                    tooltip: 'حذف',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(int? seconds) {
    if (seconds == null) return '0:00';
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  void _showVideoPreview(Map<String, dynamic> video) {
    showDialog(
      context: context,
      builder: (context) => _VideoPreviewDialog(video: video),
    );
  }

  void _showEditDialog(Map<String, dynamic> video) {
    showDialog(
      context: context,
      builder: (context) => _EditVideoDialog(
        video: video,
        onUpdated: () {
          _loadAllVideos();
        },
      ),
    );
  }

  void _confirmDelete(Map<String, dynamic> video) {
    showDialog(
      context: context,
      builder: (context) => _DeleteConfirmationDialog(
        video: video,
        onDeleted: () {
          _loadAllVideos();
        },
      ),
    );
  }

  void _showPdfDialog(Map<String, dynamic> video) {
    showDialog(
      context: context,
      builder: (context) => _PdfUploadDialog(
        video: video,
        onUploaded: () {
          _loadAllVideos();
        },
      ),
    );
  }

  void _showThumbnailDialog(Map<String, dynamic> video) {
    showDialog(
      context: context,
      builder: (context) => _ThumbnailUploadDialog(
        video: video,
        onUploaded: () {
          _loadAllVideos();
        },
      ),
    );
  }

  bool _isCustomThumbnail(String? thumbnailUrl) {
    if (thumbnailUrl == null) return false;
    // التحقق من أن الصورة من Supabase Storage (وليس من BunnyCDN)
    return thumbnailUrl.contains('video-thumbnails');
  }

  void _showReplaceVideoDialog(Map<String, dynamic> video) {
    showDialog(
      context: context,
      builder: (context) => _ReplaceVideoDialog(
        video: video,
        onReplaced: () {
          _loadAllVideos();
        },
      ),
    );
  }
}

// ============================================================================
// Video Preview Dialog
// ============================================================================

class _VideoPreviewDialog extends StatefulWidget {
  final Map<String, dynamic> video;

  const _VideoPreviewDialog({required this.video});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  String _selectedQuality = '720p';

  /// Get BunnyCDN embed URL for the video
  String? _getEmbedUrl() {
    final bunnyVideoId = widget.video['bunny_video_id'] as String?;
    if (bunnyVideoId == null) return null;

    // BunnyCDN Stream embed URL format
    // Library ID from secure_bunny_service.dart
    const libraryId = '543524'; // Bunny Stream library ID
    return 'https://iframe.mediadelivery.net/embed/$libraryId/$bunnyVideoId?autoplay=true&preload=true';
  }

  /// Get direct video URL for quality
  String? _getVideoUrl() {
    return widget.video['url_$_selectedQuality'] ??
           widget.video['url_720p'] ??
           widget.video['url_480p'] ??
           widget.video['url_360p'];
  }

  /// Open video in new browser tab (fallback for web)
  Future<void> _openInNewTab() async {
    final embedUrl = _getEmbedUrl();
    final directUrl = _getVideoUrl();
    final urlToOpen = embedUrl ?? directUrl;

    if (urlToOpen != null) {
      final uri = Uri.parse(urlToOpen);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bunnyVideoId = widget.video['bunny_video_id'] as String?;
    final videoUrl = _getVideoUrl();
    final thumbnailUrl = widget.video['thumbnail_url'] as String?;
    final duration = widget.video['duration_seconds'] as int?;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 550),
        decoration: BoxDecoration(
          color: AdminTheme.secondaryDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.play_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.video['title_ar'] ?? widget.video['title'] ?? 'معاينة الفيديو',
                      style: AdminTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Video Preview Area
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                  image: thumbnailUrl != null
                      ? DecorationImage(
                          image: NetworkImage(thumbnailUrl),
                          fit: BoxFit.cover,
                          colorFilter: ColorFilter.mode(
                            Colors.black.withOpacity(0.5),
                            BlendMode.darken,
                          ),
                        )
                      : null,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Play button to open in new tab
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AdminTheme.accentBlue,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AdminTheme.accentBlue.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _openInNewTab,
                            borderRadius: BorderRadius.circular(40),
                            child: const Icon(
                              Icons.play_arrow,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'اضغط لتشغيل الفيديو في نافذة جديدة',
                        style: AdminTheme.bodyMedium.copyWith(color: Colors.white70),
                      ),
                      if (duration != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time, color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _formatDuration(duration),
                                style: const TextStyle(color: Colors.white70, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            // Video Info & Actions
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Video details
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AdminTheme.primaryDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          Icons.fingerprint,
                          'Bunny Video ID',
                          bunnyVideoId ?? 'غير متوفر',
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          Icons.link,
                          'رابط الفيديو',
                          videoUrl != null ? 'متوفر' : 'غير متوفر',
                          hasLink: videoUrl != null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Quality selector and open button
                  Row(
                    children: [
                      // Quality Selector
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AdminTheme.primaryDark,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedQuality,
                            isExpanded: true,
                            underline: const SizedBox(),
                            dropdownColor: AdminTheme.secondaryDark,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            items: [
                              if (widget.video['url_360p'] != null)
                                const DropdownMenuItem(value: '360p', child: Text('360p - جودة منخفضة')),
                              if (widget.video['url_480p'] != null)
                                const DropdownMenuItem(value: '480p', child: Text('480p - جودة متوسطة')),
                              if (widget.video['url_720p'] != null)
                                const DropdownMenuItem(value: '720p', child: Text('720p - جودة عالية')),
                              if (widget.video['url_1080p'] != null)
                                const DropdownMenuItem(value: '1080p', child: Text('1080p - جودة فائقة')),
                            ],
                            onChanged: (value) {
                              if (value != null) {
                                setState(() => _selectedQuality = value);
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Open in new tab button
                      ElevatedButton.icon(
                        onPressed: _openInNewTab,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('فتح الفيديو'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AdminTheme.accentBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool hasLink = false}) {
    return Row(
      children: [
        Icon(icon, color: Colors.white54, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: AdminTheme.bodySmall.copyWith(
              color: hasLink ? AdminTheme.accentBlue : Colors.white70,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// Edit Video Dialog
// ============================================================================

class _EditVideoDialog extends StatefulWidget {
  final Map<String, dynamic> video;
  final VoidCallback onUpdated;

  const _EditVideoDialog({
    required this.video,
    required this.onUpdated,
  });

  @override
  State<_EditVideoDialog> createState() => _EditVideoDialogState();
}

class _EditVideoDialogState extends State<_EditVideoDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleArController;
  late TextEditingController _titleController;
  late TextEditingController _descriptionArController;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _titleArController = TextEditingController(text: widget.video['title_ar']);
    _titleController = TextEditingController(text: widget.video['title']);
    _descriptionArController = TextEditingController(text: widget.video['description_ar']);
  }

  @override
  void dispose() {
    _titleArController.dispose();
    _titleController.dispose();
    _descriptionArController.dispose();
    super.dispose();
  }

  Future<void> _updateVideo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isUpdating = true);

    try {
      await Supabase.instance.client
          .from('videos')
          .update({
            'title_ar': _titleArController.text.trim(),
            'title': _titleController.text.trim(),
            'description_ar': _descriptionArController.text.trim(),
          })
          .eq('id', widget.video['id']);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث الفيديو بنجاح')),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحديث: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        decoration: BoxDecoration(
          color: AdminTheme.secondaryDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.edit, color: Colors.white),
                    const SizedBox(width: 12),
                    const Text('تعديل الفيديو', style: AdminTheme.titleSmall),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Title Arabic
                TextFormField(
                  controller: _titleArController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'العنوان (بالعربية)',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AdminTheme.primaryDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'العنوان مطلوب' : null,
                ),
                const SizedBox(height: 16),

                // Title English
                TextFormField(
                  controller: _titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'العنوان (بالإنجليزية) - اختياري',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AdminTheme.primaryDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Description Arabic
                TextFormField(
                  controller: _descriptionArController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'الوصف (بالعربية) - اختياري',
                    labelStyle: const TextStyle(color: Colors.white70),
                    filled: true,
                    fillColor: AdminTheme.primaryDark,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isUpdating ? null : () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isUpdating ? null : _updateVideo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AdminTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isUpdating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text('حفظ التغييرات'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Delete Confirmation Dialog
// ============================================================================

class _DeleteConfirmationDialog extends StatefulWidget {
  final Map<String, dynamic> video;
  final VoidCallback onDeleted;

  const _DeleteConfirmationDialog({
    required this.video,
    required this.onDeleted,
  });

  @override
  State<_DeleteConfirmationDialog> createState() => _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  bool _isDeleting = false;
  String _statusMessage = '';

  Future<void> _deleteVideo() async {
    setState(() {
      _isDeleting = true;
      _statusMessage = 'جاري الحذف من BunnyCDN...';
    });

    try {
      final bunnyVideoId = widget.video['bunny_video_id'] as String?;

      // Step 1: Delete from BunnyCDN
      if (bunnyVideoId != null) {
        final secureBunny = SecureBunnyService();
        final deleted = await secureBunny.deleteVideo(bunnyVideoId);

        if (!deleted) {
          throw Exception('فشل حذف الفيديو من BunnyCDN');
        }
      }

      setState(() => _statusMessage = 'جاري الحذف من قاعدة البيانات...');

      // Step 2: Delete from Database
      await Supabase.instance.client
          .from('videos')
          .delete()
          .eq('id', widget.video['id']);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الفيديو بنجاح من BunnyCDN وقاعدة البيانات'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onDeleted();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
          _statusMessage = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الحذف: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AdminTheme.secondaryDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.red.withOpacity(0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Text(
                'تأكيد الحذف',
                style: AdminTheme.titleSmall,
              ),
              const SizedBox(height: 12),

              // Message
              Text(
                'هل أنت متأكد من حذف هذا الفيديو؟\n\n"${widget.video['title_ar'] ?? widget.video['title'] ?? 'بدون عنوان'}"\n\nسيتم حذف الفيديو من BunnyCDN وقاعدة البيانات ولا يمكن التراجع عن هذا الإجراء.',
                style: AdminTheme.bodyMedium.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Status Message
              if (_isDeleting) ...[
                LinearProgressIndicator(
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation(Colors.red),
                ),
                const SizedBox(height: 12),
                Text(
                  _statusMessage,
                  style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
              ],

              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: _isDeleting ? null : () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isDeleting ? null : _deleteVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isDeleting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          )
                        : const Text('حذف نهائياً'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// PDF Management Dialog
// ============================================================================

class _PdfManagementDialog extends StatefulWidget {
  final Map<String, dynamic> video;
  final VoidCallback onUpdated;

  const _PdfManagementDialog({
    required this.video,
    required this.onUpdated,
  });

  @override
  State<_PdfManagementDialog> createState() => _PdfManagementDialogState();
}

class _PdfManagementDialogState extends State<_PdfManagementDialog> {
  final _supabase = Supabase.instance.client;
  PlatformFile? _selectedPdf;
  bool _isUploading = false;
  bool _isDeleting = false;
  String? _currentPdfUrl;

  @override
  void initState() {
    super.initState();
    _currentPdfUrl = widget.video['lesson']?['pdf_url'];
  }

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedPdf = result.files.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في اختيار الملف: $e')),
        );
      }
    }
  }

  Future<void> _uploadPdf() async {
    if (_selectedPdf == null || _selectedPdf!.bytes == null) return;

    final lessonId = widget.video['lesson']?['id'];
    if (lessonId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد درس مرتبط بهذا الفيديو')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '$lessonId/$timestamp.pdf';

      // Upload to Supabase Storage
      await _supabase.storage
          .from('lesson-pdfs')
          .uploadBinary(
            fileName,
            _selectedPdf!.bytes!,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );

      // Get public URL
      final pdfUrl = _supabase.storage
          .from('lesson-pdfs')
          .getPublicUrl(fileName);

      // Update lesson with PDF URL
      await _supabase
          .from('lessons')
          .update({'pdf_url': pdfUrl})
          .eq('id', lessonId);

      if (mounted) {
        setState(() {
          _currentPdfUrl = pdfUrl;
          _selectedPdf = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفع ملف PDF بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في رفع الملف: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deletePdf() async {
    final lessonId = widget.video['lesson']?['id'];
    if (lessonId == null || _currentPdfUrl == null) return;

    setState(() => _isDeleting = true);

    try {
      // Extract file path from URL and delete from storage
      try {
        final uri = Uri.parse(_currentPdfUrl!);
        final pathSegments = uri.pathSegments;
        final bucketIndex = pathSegments.indexOf('lesson-pdfs');
        if (bucketIndex != -1 && bucketIndex < pathSegments.length - 1) {
          final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
          await _supabase.storage.from('lesson-pdfs').remove([filePath]);
        }
      } catch (_) {
        // Ignore storage deletion errors
      }

      // Update lesson to remove PDF URL
      await _supabase
          .from('lessons')
          .update({'pdf_url': null})
          .eq('id', lessonId);

      if (mounted) {
        setState(() {
          _currentPdfUrl = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف ملف PDF'),
            backgroundColor: Colors.orange,
          ),
        );
        widget.onUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في حذف الملف: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  Future<void> _openPdf() async {
    if (_currentPdfUrl != null) {
      final uri = Uri.parse(_currentPdfUrl!);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoTitle = widget.video['title_ar'] ?? widget.video['title'] ?? 'بدون عنوان';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        decoration: BoxDecoration(
          color: AdminTheme.secondaryDark,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إدارة ملف PDF', style: AdminTheme.titleSmall),
                        Text(
                          videoTitle,
                          style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Current PDF Status
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AdminTheme.primaryDark,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _currentPdfUrl != null
                        ? Colors.green.withOpacity(0.3)
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _currentPdfUrl != null
                          ? Icons.check_circle
                          : Icons.info_outline,
                      color: _currentPdfUrl != null ? Colors.green : Colors.white54,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _currentPdfUrl != null
                            ? 'يوجد ملف PDF مرفق بهذا الدرس'
                            : 'لا يوجد ملف PDF مرفق',
                        style: AdminTheme.bodyMedium.copyWith(
                          color: _currentPdfUrl != null ? Colors.green : Colors.white70,
                        ),
                      ),
                    ),
                    if (_currentPdfUrl != null) ...[
                      IconButton(
                        onPressed: _openPdf,
                        icon: const Icon(Icons.open_in_new, size: 20),
                        color: AdminTheme.accentBlue,
                        tooltip: 'فتح PDF',
                      ),
                      IconButton(
                        onPressed: _isDeleting ? null : _deletePdf,
                        icon: _isDeleting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.delete_outline, size: 20),
                        color: Colors.red.shade300,
                        tooltip: 'حذف PDF',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // File Picker Section
              InkWell(
                onTap: _isUploading ? null : _pickPdf,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AdminTheme.primaryDark,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedPdf != null
                          ? AdminTheme.accentBlue.withOpacity(0.5)
                          : Colors.white.withOpacity(0.1),
                      width: _selectedPdf != null ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _selectedPdf != null ? Icons.description : Icons.upload_file,
                        color: _selectedPdf != null ? AdminTheme.accentBlue : Colors.white54,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedPdf != null
                            ? _selectedPdf!.name
                            : _currentPdfUrl != null
                                ? 'اضغط لتغيير ملف PDF'
                                : 'اضغط لاختيار ملف PDF',
                        style: AdminTheme.bodyMedium.copyWith(
                          color: _selectedPdf != null ? Colors.white : Colors.white70,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedPdf != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${(_selectedPdf!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                          style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Upload Button
              if (_selectedPdf != null)
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _uploadPdf,
                  icon: _isUploading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Icon(Icons.cloud_upload),
                  label: Text(_isUploading ? 'جاري الرفع...' : 'رفع ملف PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AdminTheme.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Replace Video Dialog
// ============================================================================

class _ReplaceVideoDialog extends StatefulWidget {
  final Map<String, dynamic> video;
  final VoidCallback onReplaced;

  const _ReplaceVideoDialog({
    required this.video,
    required this.onReplaced,
  });

  @override
  State<_ReplaceVideoDialog> createState() => _ReplaceVideoDialogState();
}

class _ReplaceVideoDialogState extends State<_ReplaceVideoDialog> {
  final _bunnyService = SecureBunnyService();
  final _supabase = Supabase.instance.client;

  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _error;
  PlatformFile? _selectedFile;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.secondaryDark,
      title: Row(
        children: [
          Icon(Icons.swap_horiz, color: Colors.orange.shade300),
          const SizedBox(width: 12),
          const Text('استبدال الفيديو', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange.shade300, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'سيتم حذف الفيديو القديم واستبداله بالفيديو الجديد. جميع البيانات الأخرى (العنوان، التصنيف، الموضوع) ستبقى كما هي.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Current video info
            Text(
              'الفيديو الحالي:',
              style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminTheme.primaryDark,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.video['title_ar'] ?? widget.video['title'] ?? 'بدون عنوان',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID: ${widget.video['bunny_video_id']}',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // File selection
            if (!_isUploading) ...[
              Text(
                'اختر الفيديو الجديد:',
                style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickFile,
                icon: const Icon(Icons.file_upload),
                label: Text(_selectedFile == null ? 'اختر فيديو' : _selectedFile!.name),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accentBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
              if (_selectedFile != null) ...[
                const SizedBox(height: 8),
                Text(
                  'الحجم: ${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(2)} MB',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ],

            // Upload progress
            if (_isUploading) ...[
              const SizedBox(height: 20),
              Text(
                'جاري الرفع...',
                style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: _uploadProgress,
                backgroundColor: Colors.white12,
                valueColor: AlwaysStoppedAnimation<Color>(AdminTheme.accentBlue),
              ),
              const SizedBox(height: 8),
              Text(
                '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],

            // Error message
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: (_isUploading || _selectedFile == null) ? null : _replaceVideo,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange.shade600,
            foregroundColor: Colors.white,
          ),
          child: const Text('استبدال'),
        ),
      ],
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'فشل اختيار الملف: $e';
      });
    }
  }

  Future<void> _replaceVideo() async {
    if (_selectedFile == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
    });

    try {
      // Step 1: Upload new video to BunnyCDN
      debugPrint('[REPLACE] Uploading new video...');
      String? newVideoId;

      if (kIsWeb) {
        // Web upload using HTML File
        newVideoId = await _bunnyService.uploadVideoFromWeb(
          htmlFile: _selectedFile!.bytes,
          fileName: _selectedFile!.name,
          fileSize: _selectedFile!.size,
          title: widget.video['title_ar'] ?? widget.video['title'] ?? 'Replaced Video',
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress * 0.7; // 70% for upload
            });
          },
        );
      } else {
        // Mobile/Desktop upload
        final bytes = _selectedFile!.bytes!;
        newVideoId = await _bunnyService.uploadVideoFromBytes(
          videoBytes: bytes,
          fileName: _selectedFile!.name,
          title: widget.video['title_ar'] ?? widget.video['title'] ?? 'Replaced Video',
          onProgress: (progress) {
            setState(() {
              _uploadProgress = progress * 0.7;
            });
          },
        );
      }

      if (newVideoId == null) {
        throw Exception(_bunnyService.error ?? 'فشل رفع الفيديو الجديد');
      }

      debugPrint('[REPLACE] New video uploaded: $newVideoId');
      setState(() => _uploadProgress = 0.75);

      // Step 2: Wait for video processing and get duration
      await Future.delayed(const Duration(seconds: 3));
      debugPrint('[REPLACE] Getting new video info...');

      final videoInfo = await _bunnyService.getVideoInfo(newVideoId);
      final duration = videoInfo != null ? (videoInfo['length'] as num?)?.round() ?? 1 : 1;
      final thumbnail = _bunnyService.getVideoThumbnailUrl(newVideoId);

      debugPrint('[REPLACE] New video duration: ${duration}s');
      setState(() => _uploadProgress = 0.85);

      // Step 3: Update database with new video ID
      debugPrint('[REPLACE] Updating database...');
      await _supabase
          .from('videos')
          .update({
            'bunny_video_id': newVideoId,
            'duration_seconds': duration,
            'thumbnail_url': thumbnail,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', widget.video['id']);

      debugPrint('[REPLACE] Database updated');
      setState(() => _uploadProgress = 0.95);

      // Step 4: Delete old video from BunnyCDN
      final oldVideoId = widget.video['bunny_video_id'] as String;
      debugPrint('[REPLACE] Deleting old video: $oldVideoId');
      await _bunnyService.deleteVideo(oldVideoId);
      debugPrint('[REPLACE] Old video deleted');

      setState(() => _uploadProgress = 1.0);

      // Success!
      if (mounted) {
        Navigator.pop(context);
        widget.onReplaced();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم استبدال الفيديو بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('[REPLACE] Error: $e');
      setState(() {
        _error = 'خطأ في استبدال الفيديو: $e';
        _isUploading = false;
      });
    }
  }
}

// ============================================================================
// PDF Upload/Replace Dialog
// ============================================================================

class _PdfUploadDialog extends StatefulWidget {
  final Map<String, dynamic> video;
  final VoidCallback onUploaded;

  const _PdfUploadDialog({
    required this.video,
    required this.onUploaded,
  });

  @override
  State<_PdfUploadDialog> createState() => _PdfUploadDialogState();
}

class _PdfUploadDialogState extends State<_PdfUploadDialog> {
  final _pdfService = PdfService();
  bool _isUploading = false;
  String? _error;
  PlatformFile? _selectedFile;

  // Check if PDF already exists
  bool get _hasPdf => widget.video['lesson']?['pdf_url'] != null;
  String? get _pdfUrl => widget.video['lesson']?['pdf_url'];
  String? get _lessonId => widget.video['lesson']?['id'];

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _error = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'فشل اختيار الملف: $e');
    }
  }

  Future<void> _uploadPdf() async {
    if (_selectedFile == null) {
      setState(() => _error = 'يرجى اختيار ملف PDF أولاً');
      return;
    }

    if (_lessonId == null) {
      setState(() => _error = 'لا يوجد درس مرتبط بهذا الفيديو');
      return;
    }

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      String pdfUrl;

      if (_hasPdf) {
        // Replace existing PDF
        pdfUrl = await _pdfService.replacePdf(
          file: _selectedFile!,
          lessonId: _lessonId!,
          oldPdfUrl: _pdfUrl!,
        );
      } else {
        // Upload new PDF
        pdfUrl = await _pdfService.uploadPdf(
          file: _selectedFile!,
          lessonId: _lessonId!,
        );

        // Update database
        await _pdfService.updateLessonPdfUrl(
          lessonId: _lessonId!,
          pdfUrl: pdfUrl,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onUploaded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_hasPdf ? '✅ تم استبدال ملف PDF بنجاح!' : '✅ تم رفع ملف PDF بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isUploading = false;
      });
    }
  }

  Future<void> _deletePdf() async {
    if (!_hasPdf || _lessonId == null) return;

    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف ملف PDF؟'),
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

    if (confirm != true) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      await _pdfService.deletePdf(_pdfUrl!);
      await _pdfService.updateLessonPdfUrl(
        lessonId: _lessonId!,
        pdfUrl: null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onUploaded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حذف ملف PDF بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'فشل حذف PDF: $e';
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AdminTheme.secondaryDark,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.picture_as_pdf, color: Colors.red.shade300, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _hasPdf ? 'إدارة ملف PDF' : 'رفع ملف PDF',
                    style: AdminTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: Colors.white70,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Current PDF status
            if (_hasPdf) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'يوجد ملف PDF مرفق بهذا الدرس',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => launchUrl(Uri.parse(_pdfUrl!)),
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('عرض'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // File picker
            if (!_isUploading) ...[
              Text(
                _hasPdf ? 'اختر ملف PDF جديد للاستبدال:' : 'اختر ملف PDF:',
                style: AdminTheme.bodyMedium.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _pickFile,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.file_upload, color: Colors.white54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFile?.name ?? 'اضغط لاختيار ملف PDF',
                          style: TextStyle(
                            color: _selectedFile != null ? Colors.white : Colors.white54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedFile != null)
                        Text(
                          '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(1)} MB',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),
            ],

            // Error message
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Loading indicator
            if (_isUploading) ...[
              const SizedBox(height: 24),
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('جاري العمل...', style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            if (!_isUploading)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_hasPdf)
                    TextButton.icon(
                      onPressed: _deletePdf,
                      icon: const Icon(Icons.delete),
                      label: const Text('حذف PDF'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _selectedFile != null ? _uploadPdf : null,
                    icon: Icon(_hasPdf ? Icons.swap_horiz : Icons.upload),
                    label: Text(_hasPdf ? 'استبدال' : 'رفع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.accentBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Thumbnail Upload/Replace Dialog
// ============================================================================

class _ThumbnailUploadDialog extends StatefulWidget {
  final Map<String, dynamic> video;
  final VoidCallback onUploaded;

  const _ThumbnailUploadDialog({
    required this.video,
    required this.onUploaded,
  });

  @override
  State<_ThumbnailUploadDialog> createState() => _ThumbnailUploadDialogState();
}

class _ThumbnailUploadDialogState extends State<_ThumbnailUploadDialog> {
  final _thumbnailService = ThumbnailService();
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _statusMessage = '';
  String? _error;
  PlatformFile? _selectedFile;
  ThumbnailUploadResult? _uploadResult;

  // Check if custom thumbnail already exists
  bool get _hasCustomThumbnail {
    final thumbnailUrl = widget.video['thumbnail_url'] as String?;
    if (thumbnailUrl == null) return false;
    return thumbnailUrl.contains('video-thumbnails');
  }

  String? get _thumbnailUrl => widget.video['thumbnail_url'];
  String? get _videoId => widget.video['id'];

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
          _error = null;
          _uploadResult = null;
        });
      }
    } catch (e) {
      setState(() => _error = 'فشل اختيار الصورة: $e');
    }
  }

  Future<void> _uploadThumbnail() async {
    if (_selectedFile == null) {
      setState(() => _error = 'يرجى اختيار صورة أولاً');
      return;
    }

    if (_videoId == null) {
      setState(() => _error = 'معرف الفيديو غير موجود');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _error = null;
    });

    try {
      ThumbnailUploadResult result;

      if (_hasCustomThumbnail) {
        // Replace existing custom thumbnail
        result = await _thumbnailService.replaceThumbnail(
          file: _selectedFile!,
          videoId: _videoId!,
          oldThumbnailUrl: _thumbnailUrl!,
          onProgress: (status, progress) {
            setState(() {
              _statusMessage = status;
              _uploadProgress = progress;
            });
          },
        );
      } else {
        // Upload new thumbnail
        result = await _thumbnailService.uploadThumbnail(
          file: _selectedFile!,
          videoId: _videoId!,
          onProgress: (status, progress) {
            setState(() {
              _statusMessage = status;
              _uploadProgress = progress;
            });
          },
        );

        // Update database
        await _thumbnailService.updateVideoThumbnail(
          videoId: _videoId!,
          thumbnailUrl: result.url,
        );
      }

      setState(() => _uploadResult = result);

      if (mounted) {
        await Future.delayed(const Duration(seconds: 1));
        Navigator.pop(context);
        widget.onUploaded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _hasCustomThumbnail
                  ? '✅ تم استبدال الصورة المصغرة بنجاح!'
                  : '✅ تم رفع الصورة المصغرة بنجاح!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isUploading = false;
      });
    }
  }

  Future<void> _deleteThumbnail() async {
    if (!_hasCustomThumbnail || _videoId == null) return;

    // Confirm deletion
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text(
          'هل أنت متأكد من حذف الصورة المصغرة المخصصة؟\nسيتم العودة إلى الصورة المصغرة من BunnyCDN.',
        ),
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

    if (confirm != true) return;

    setState(() {
      _isUploading = true;
      _error = null;
    });

    try {
      await _thumbnailService.deleteThumbnail(_thumbnailUrl!);

      // Set thumbnail_url to null to use BunnyCDN default
      await _thumbnailService.updateVideoThumbnail(
        videoId: _videoId!,
        thumbnailUrl: null,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onUploaded();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حذف الصورة المصغرة بنجاح!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'فشل حذف الصورة المصغرة: $e';
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AdminTheme.secondaryDark,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.image, color: Colors.green.shade300, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _hasCustomThumbnail
                        ? 'إدارة الصورة المصغرة'
                        : 'رفع صورة مصغرة مخصصة',
                    style: AdminTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  color: Colors.white70,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Current thumbnail status
            if (_hasCustomThumbnail) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'يوجد صورة مصغرة مخصصة لهذا الفيديو',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    // Preview current thumbnail
                    if (_thumbnailUrl != null)
                      Container(
                        width: 80,
                        height: 45,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          image: DecorationImage(
                            image: NetworkImage(_thumbnailUrl!),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // File picker
            if (!_isUploading && _uploadResult == null) ...[
              Text(
                _hasCustomThumbnail
                    ? 'اختر صورة جديدة للاستبدال:'
                    : 'اختر صورة مصغرة:',
                style: AdminTheme.bodyMedium.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                'الصورة سيتم ضغطها تلقائياً إلى WebP بحجم أقل من 500KB',
                style: AdminTheme.bodySmall.copyWith(color: Colors.white38),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickImage,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.image, color: Colors.white54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _selectedFile?.name ?? 'اضغط لاختيار صورة (JPG, PNG, WebP)',
                          style: TextStyle(
                            color: _selectedFile != null ? Colors.white : Colors.white54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_selectedFile != null)
                        Text(
                          '${(_selectedFile!.size / 1024 / 1024).toStringAsFixed(1)} MB',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ),

              // Image preview
              if (_selectedFile != null && _selectedFile!.bytes != null) ...[
                const SizedBox(height: 16),
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: MemoryImage(_selectedFile!.bytes!),
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ],

            // Upload progress
            if (_isUploading && _uploadResult == null) ...[
              const SizedBox(height: 24),
              Column(
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AdminTheme.accentBlue,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _statusMessage,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                    style: AdminTheme.bodySmall.copyWith(color: Colors.white38),
                  ),
                ],
              ),
            ],

            // Upload result
            if (_uploadResult != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 24),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'تم بنجاح!',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _uploadResult!.compressionInfo,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],

            // Error message
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Action buttons
            if (!_isUploading && _uploadResult == null)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_hasCustomThumbnail)
                    TextButton.icon(
                      onPressed: _deleteThumbnail,
                      icon: const Icon(Icons.delete),
                      label: const Text('حذف'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _selectedFile != null ? _uploadThumbnail : null,
                    icon: Icon(_hasCustomThumbnail ? Icons.swap_horiz : Icons.upload),
                    label: Text(_hasCustomThumbnail ? 'استبدال' : 'رفع'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.accentBlue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
