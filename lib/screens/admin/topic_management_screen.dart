import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/secure_bunny_service.dart';
import '../../utils/admin_theme.dart';

/// Topic Management Screen
/// Create, edit, and delete topics within subjects
/// Topics contain: video lessons, written lessons, summaries, etc.

class TopicManagementScreen extends StatefulWidget {
  const TopicManagementScreen({super.key});

  @override
  State<TopicManagementScreen> createState() => _TopicManagementScreenState();
}

class _TopicManagementScreenState extends State<TopicManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // المتغيرات الأصلية
  String? _selectedGradeId;
  String? _selectedSubjectId;

  // المتغيرات الجديدة - المنهج والشعبة
  String? _selectedCurriculumId;
  String? _selectedSpecializationId;

  // القوائم الأصلية
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _topics = [];

  // القوائم الجديدة - المناهج والشعب
  List<Map<String, dynamic>> _curricula = [];
  List<Map<String, dynamic>> _specializations = [];

  bool _isLoading = false;
  bool _isLoadingTopics = false;

  @override
  void initState() {
    super.initState();
    _loadCurricula(); // تحميل المناهج أولاً
  }

  /// تحميل المناهج الدراسية
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

  /// تحميل الفصول حسب المنهج المختار
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
      });
      return;
    }

    try {
      final response = await _supabase
          .from('grades')
          .select('*, curricula(id, name, name_ar)')
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
      });
    } catch (e) {
      debugPrint('Error loading grades: $e');
    }
  }

  /// تحميل الشعب حسب الفصل المختار
  Future<void> _loadSpecializations() async {
    if (_selectedGradeId == null) {
      setState(() {
        _specializations = [];
        _selectedSpecializationId = null;
        _subjects = [];
        _selectedSubjectId = null;
        _topics = [];
      });
      return;
    }

    try {
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
      });

      // إذا لم تكن هناك شعب، نحمّل المواد مباشرة
      if (_specializations.isEmpty) {
        _loadSubjects(_selectedGradeId!);
      }
    } catch (e) {
      debugPrint('Error loading specializations: $e');
      // إذا فشل تحميل الشعب، نحمّل المواد مباشرة
      _loadSubjects(_selectedGradeId!);
    }
  }

  /// تحميل المواد حسب الفصل والشعبة
  Future<void> _loadSubjects(String gradeId) async {
    try {
      // بناء الاستعلام الأساسي
      var query = _supabase
          .from('subjects')
          .select()
          .eq('grade_id', gradeId)
          .eq('is_active', true);

      // إذا تم اختيار شعبة، نفلتر حسبها
      if (_selectedSpecializationId != null) {
        query = query.eq('specialization_id', _selectedSpecializationId!);
      } else if (_specializations.isNotEmpty) {
        // إذا كانت هناك شعب متاحة ولم يتم اختيار واحدة، لا نعرض شيء
        setState(() {
          _subjects = [];
          _selectedSubjectId = null;
          _topics = [];
        });
        return;
      }

      final response = await query.order('display_order');
      setState(() {
        _subjects = List<Map<String, dynamic>>.from(response);
        _selectedSubjectId = null;
        _topics = [];
      });
    } catch (e) {
      debugPrint('Error loading subjects: $e');
    }
  }

  Future<void> _loadTopics(String subjectId) async {
    setState(() => _isLoadingTopics = true);
    try {
      final response = await _supabase
          .from('topics')
          .select()
          .eq('subject_id', subjectId)
          .order('display_order', ascending: true);
      setState(() {
        _topics = List<Map<String, dynamic>>.from(response);
        _isLoadingTopics = false;
      });
    } catch (e) {
      setState(() => _isLoadingTopics = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل المواضيع: $e')),
        );
      }
    }
  }

  Future<void> _showAddTopicDialog() async {
    // التحقق من اختيار المنهج
    if (_selectedCurriculumId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المنهج أولاً')),
      );
      return;
    }

    // التحقق من اختيار الفصل
    if (_selectedGradeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الفصل أولاً')),
      );
      return;
    }

    // التحقق من اختيار الشعبة (إذا كانت هناك شعب)
    if (_specializations.isNotEmpty && _selectedSpecializationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الشعبة أولاً')),
      );
      return;
    }

    // التحقق من اختيار المادة
    if (_selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار المادة أولاً')),
      );
      return;
    }

    final nameController = TextEditingController();
    final nameArController = TextEditingController();
    final descriptionController = TextEditingController();
    final descriptionArController = TextEditingController();
    final displayOrderController = TextEditingController(text: '${_topics.length + 1}');

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondaryDark,
        title: const Text('إضافة موضوع جديد', style: AdminTheme.titleMedium),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Arabic Name
                TextFormField(
                  controller: nameArController,
                  style: AdminTheme.bodyMedium,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموضوع (عربي)',
                    hintText: 'مثال: النحو والصرف',
                    filled: true,
                    fillColor: Color(0xFF0F1419),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
                ),
                const SizedBox(height: 16),

                // English Name
                TextFormField(
                  controller: nameController,
                  style: AdminTheme.bodyMedium,
                  decoration: const InputDecoration(
                    labelText: 'اسم الموضوع (إنجليزي)',
                    hintText: 'Example: Grammar',
                    filled: true,
                    fillColor: Color(0xFF0F1419),
                  ),
                ),
                const SizedBox(height: 16),

                // Arabic Description
                TextFormField(
                  controller: descriptionArController,
                  style: AdminTheme.bodyMedium,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'الوصف (عربي)',
                    hintText: 'وصف الموضوع...',
                    filled: true,
                    fillColor: Color(0xFF0F1419),
                  ),
                ),
                const SizedBox(height: 16),

                // English Description
                TextFormField(
                  controller: descriptionController,
                  style: AdminTheme.bodyMedium,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'الوصف (إنجليزي)',
                    hintText: 'Topic description...',
                    filled: true,
                    fillColor: Color(0xFF0F1419),
                  ),
                ),
                const SizedBox(height: 16),

                // Display Order
                TextFormField(
                  controller: displayOrderController,
                  style: AdminTheme.bodyMedium,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'ترتيب العرض',
                    filled: true,
                    fillColor: Color(0xFF0F1419),
                  ),
                  validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentCyan,
            ),
            onPressed: () async {
              if (_formKey.currentState?.validate() ?? false) {
                await _addTopic(
                  name: nameController.text.trim(),
                  nameAr: nameArController.text.trim(),
                  description: descriptionController.text.trim(),
                  descriptionAr: descriptionArController.text.trim(),
                  displayOrder: int.tryParse(displayOrderController.text) ?? 1,
                );
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _addTopic({
    required String name,
    required String nameAr,
    required String description,
    required String descriptionAr,
    required int displayOrder,
  }) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.from('topics').insert({
        'subject_id': _selectedSubjectId,
        'name': name.isNotEmpty ? name : nameAr,
        'name_ar': nameAr,
        'description': description.isNotEmpty ? description : null,
        'description_ar': descriptionAr.isNotEmpty ? descriptionAr : null,
        'display_order': displayOrder,
        'is_active': true,
      });

      // Sync with BunnyCDN - create collection for the new topic
      _syncTopicWithBunnyCDN(nameAr.isNotEmpty ? nameAr : name);

      await _loadTopics(_selectedSubjectId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إضافة الموضوع بنجاح!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Sync topic with BunnyCDN by creating a collection
  /// This is non-blocking and won't affect the main operation
  Future<void> _syncTopicWithBunnyCDN(String topicName) async {
    try {
      // Get curriculum name from selected grade
      final grade = _grades.firstWhere(
        (g) => g['id'] == _selectedGradeId,
        orElse: () => {},
      );
      if (grade.isEmpty) return;

      final curriculum = grade['curricula'] as Map<String, dynamic>?;
      if (curriculum == null) {
        debugPrint('Warning: Grade has no curriculum assigned');
        return;
      }

      final curriculumName = curriculum['name_ar'] ?? curriculum['name'];
      final gradeName = grade['name_ar'] ?? grade['name'];

      // Get subject name
      final subject = _subjects.firstWhere(
        (s) => s['id'] == _selectedSubjectId,
        orElse: () => {},
      );
      if (subject.isEmpty) return;

      final subjectName = subject['name_ar'] ?? subject['name'];

      final secureBunny = context.read<SecureBunnyService>();
      await secureBunny.createCollection(
        '$curriculumName › $gradeName › $subjectName › $topicName',
      );
      debugPrint('BunnyCDN: Topic collection created for "$curriculumName > $gradeName > $subjectName > $topicName"');
    } catch (e) {
      // Log warning but don't show error to user - this is a background sync
      debugPrint('Warning: Failed to sync topic with BunnyCDN: $e');
    }
  }

  Future<void> _deleteTopic(String topicId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondaryDark,
        title: const Text('تأكيد الحذف', style: AdminTheme.titleMedium),
        content: const Text(
          'هل أنت متأكد من حذف هذا الموضوع؟ سيتم حذف جميع الدروس المرتبطة به!',
          style: AdminTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AdminTheme.accentRed,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supabase.from('topics').delete().eq('id', topicId);
        await _loadTopics(_selectedSubjectId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الموضوع ✓')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إدارة المواضيع',
                  style: AdminTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'أضف وأدر المواضيع داخل كل مادة. كل موضوع يحتوي على دروس مرئية ومكتوبة وملخصات',
                  style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),

        // Filters - الصف الأول: المنهج والفصل
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Curriculum Selector - اختيار المنهج
                Expanded(
                  child: Container(
                    decoration: AdminTheme.glassCard(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('المنهج', style: AdminTheme.titleSmall),
                        const SizedBox(height: 12),
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
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Grade Selector - اختيار الفصل
                Expanded(
                  child: Container(
                    decoration: AdminTheme.glassCard(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الفصل', style: AdminTheme.titleSmall),
                        const SizedBox(height: 12),
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
                            _loadSpecializations();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Filters - الصف الثاني: الشعبة والمادة وزر الإضافة
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Specialization Selector - اختيار الشعبة (يظهر فقط إذا كانت هناك شعب)
                if (_specializations.isNotEmpty)
                  Expanded(
                    child: Container(
                      decoration: AdminTheme.glassCard(),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('الشعبة', style: AdminTheme.titleSmall),
                          const SizedBox(height: 12),
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
                              if (_selectedGradeId != null) {
                                _loadSubjects(_selectedGradeId!);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_specializations.isNotEmpty) const SizedBox(width: 16),

                // Subject Selector - اختيار المادة
                Expanded(
                  child: Container(
                    decoration: AdminTheme.glassCard(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('المادة', style: AdminTheme.titleSmall),
                        const SizedBox(height: 12),
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
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Add Topic Button - زر إضافة موضوع
                Container(
                  height: 88,
                  decoration: AdminTheme.elevatedCard(gradient: AdminTheme.gradientCyan),
                  child: ElevatedButton(
                    onPressed: _showAddTopicDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_circle_rounded, size: 24),
                        SizedBox(width: 12),
                        Text('إضافة موضوع', style: AdminTheme.titleSmall),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // Topics List
        if (_selectedSubjectId == null)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.topic_rounded,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'اختر المنهج والفصل والمادة لعرض المواضيع',
                    style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
          )
        else if (_isLoadingTopics)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AdminTheme.accentCyan),
            ),
          )
        else if (_topics.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.topic_outlined,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مواضيع في هذه المادة',
                    style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddTopicDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة موضوع جديد'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.accentCyan,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.2,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildTopicCard(_topics[index]),
                childCount: _topics.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopicCard(Map<String, dynamic> topic) {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AdminTheme.gradientPurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.topic_rounded, color: Colors.white),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: AdminTheme.accentRed),
                onPressed: () => _deleteTopic(topic['id']),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            topic['name_ar'] ?? topic['name'],
            style: AdminTheme.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          if (topic['description_ar'] != null || topic['description'] != null)
            Text(
              topic['description_ar'] ?? topic['description'] ?? '',
              style: AdminTheme.bodySmall.copyWith(color: Colors.white60),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          const Spacer(),
          Row(
            children: [
              Icon(
                Icons.sort,
                size: 16,
                color: Colors.white.withOpacity(0.5),
              ),
              const SizedBox(width: 4),
              Text(
                'ترتيب: ${topic['display_order']}',
                style: AdminTheme.caption,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: topic['is_active'] == true
                      ? Colors.green.withOpacity(0.2)
                      : AdminTheme.accentRed.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  topic['is_active'] == true ? 'نشط' : 'غير نشط',
                  style: AdminTheme.caption.copyWith(
                    color: topic['is_active'] == true
                        ? Colors.green
                        : AdminTheme.accentRed,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
