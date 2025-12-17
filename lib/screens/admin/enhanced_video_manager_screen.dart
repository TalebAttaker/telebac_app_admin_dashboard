import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/secure_bunny_service.dart';
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
  String? _selectedCurriculumId;
  String? _selectedGradeId;
  String? _selectedSpecializationId;
  String? _selectedSubjectId;
  String? _selectedTopicId;

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
      });

      debugPrint('✅ Loaded ${_allVideos.length} videos successfully');
      debugPrint('📊 Videos with classification: ${_allVideos.where((v) => v['topics'] != null).length}');
      debugPrint('⚠️  Videos without classification: ${_allVideos.where((v) => v['topics'] == null).length}');
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
              _selectedTopicId == null;
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
      _grades = [];
      _specializations = [];
      _subjects = [];
      _topics = [];
      _filteredVideos = _allVideos;
    });
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
              if (_selectedCurriculumId != null || _selectedGradeId != null || _selectedSpecializationId != null || _selectedSubjectId != null || _selectedTopicId != null)
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
          if (_selectedGradeId != null || _selectedSubjectId != null || _selectedTopicId != null) ...[
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
            _selectedGradeId != null || _selectedSubjectId != null || _selectedTopicId != null
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
          childAspectRatio: 1.1, // Adjusted for reorder buttons
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
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
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
                  const SizedBox(height: 4),
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
      builder: (context) => _PdfManagementDialog(
        video: video,
        onUpdated: () {
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
