import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/secure_bunny_service.dart';
import '../../utils/admin_theme.dart';

/// Subjects Management Screen
/// Create, edit, and delete subjects within grades
/// Requires selecting curriculum and grade first to prevent mixing subjects
/// from different curricula/grades

class SubjectsManagementScreen extends StatefulWidget {
  const SubjectsManagementScreen({super.key});

  @override
  State<SubjectsManagementScreen> createState() => _SubjectsManagementScreenState();
}

class _SubjectsManagementScreenState extends State<SubjectsManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Selection state - cascading dropdowns
  String? _selectedCurriculumId;
  String? _selectedGradeId;
  String? _selectedSpecializationId;

  // Data lists
  List<Map<String, dynamic>> _curricula = [];
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _specializations = [];
  List<Map<String, dynamic>> _subjects = [];

  bool _isLoading = false;
  bool _isLoadingSubjects = false;

  // Available icons for subjects
  final List<IconData> _availableIcons = [
    Icons.menu_book_rounded,
    Icons.calculate_rounded,
    Icons.science_rounded,
    Icons.biotech_rounded,
    Icons.eco_rounded,
    Icons.translate_rounded,
    Icons.language_rounded,
    Icons.g_translate_rounded,
    Icons.auto_stories_rounded,
    Icons.history_edu_rounded,
    Icons.public_rounded,
    Icons.psychology_rounded,
    Icons.computer_rounded,
    Icons.architecture_rounded,
    Icons.music_note_rounded,
    Icons.palette_rounded,
    Icons.sports_soccer_rounded,
    Icons.engineering_rounded,
  ];

  // Available colors for subjects
  final List<Color> _availableColors = [
    const Color(0xFF3B82F6), // Blue
    const Color(0xFF06B6D4), // Cyan
    const Color(0xFF10B981), // Green
    const Color(0xFF8B5CF6), // Purple
    const Color(0xFFEC4899), // Pink
    const Color(0xFFEF4444), // Red
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF6366F1), // Indigo
    const Color(0xFF14B8A6), // Teal
    const Color(0xFFD946EF), // Fuchsia
  ];

  @override
  void initState() {
    super.initState();
    _loadCurricula();
  }

  /// Load all active curricula
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
      _showError('خطا في تحميل المناهج: $e');
    }
  }

  /// Load grades filtered by selected curriculum
  Future<void> _loadGrades() async {
    if (_selectedCurriculumId == null) {
      setState(() {
        _grades = [];
        _selectedGradeId = null;
        _specializations = [];
        _selectedSpecializationId = null;
        _subjects = [];
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
      });
    } catch (e) {
      debugPrint('Error loading grades: $e');
      _showError('خطا في تحميل الفصول: $e');
    }
  }

  /// Load specializations filtered by selected grade
  Future<void> _loadSpecializations() async {
    if (_selectedGradeId == null) {
      setState(() {
        _specializations = [];
        _selectedSpecializationId = null;
        _subjects = [];
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
      });

      // If no specializations exist, load subjects directly
      if (_specializations.isEmpty) {
        _loadSubjects();
      }
    } catch (e) {
      debugPrint('Error loading specializations: $e');
      // If specializations table doesn't exist or error, load subjects directly
      _loadSubjects();
    }
  }

  /// Load subjects filtered by selected grade and optionally specialization
  Future<void> _loadSubjects() async {
    if (_selectedGradeId == null) {
      setState(() => _subjects = []);
      return;
    }

    // If specializations exist but none selected, don't load
    if (_specializations.isNotEmpty && _selectedSpecializationId == null) {
      setState(() => _subjects = []);
      return;
    }

    setState(() => _isLoadingSubjects = true);
    try {
      var query = _supabase
          .from('subjects')
          .select()
          .eq('grade_id', _selectedGradeId!);

      // Filter by specialization if selected
      if (_selectedSpecializationId != null) {
        query = query.eq('specialization_id', _selectedSpecializationId!);
      }

      final response = await query.order('display_order');
      setState(() {
        _subjects = List<Map<String, dynamic>>.from(response);
        _isLoadingSubjects = false;
      });
    } catch (e) {
      setState(() => _isLoadingSubjects = false);
      _showError('خطا في تحميل المواد: $e');
    }
  }

  /// Show add/edit subject dialog
  Future<void> _showAddEditDialog({Map<String, dynamic>? subject}) async {
    // Validate selections
    if (_selectedCurriculumId == null) {
      _showError('يرجى اختيار المنهج اولا');
      return;
    }
    if (_selectedGradeId == null) {
      _showError('يرجى اختيار الفصل اولا');
      return;
    }
    if (_specializations.isNotEmpty && _selectedSpecializationId == null) {
      _showError('يرجى اختيار الشعبة اولا');
      return;
    }

    final isEdit = subject != null;
    final nameController = TextEditingController(text: subject?['name'] ?? '');
    final nameArController = TextEditingController(text: subject?['name_ar'] ?? '');
    final descriptionController = TextEditingController(text: subject?['description'] ?? '');
    final descriptionArController = TextEditingController(text: subject?['description_ar'] ?? '');
    final displayOrderController = TextEditingController(
      text: (subject?['display_order'] ?? _subjects.length + 1).toString(),
    );

    // Icon selection - parse from stored string or default
    // Read from icon_url field which stores the icon name
    int selectedIconIndex = 0;
    if (subject?['icon_url'] != null) {
      final iconName = subject!['icon_url'] as String;
      selectedIconIndex = _getIconIndexFromName(iconName);
    }

    // Color selection - parse from stored hex or default
    // Read from cover_image_url field which stores the color hex
    int selectedColorIndex = 0;
    if (subject?['cover_image_url'] != null) {
      final colorHex = subject!['cover_image_url'] as String;
      selectedColorIndex = _getColorIndexFromHex(colorHex);
    }

    bool isActive = subject?['is_active'] ?? true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AdminTheme.secondaryDark,
          title: Text(
            isEdit ? 'تحرير المادة' : 'اضافة مادة جديدة',
            style: AdminTheme.titleMedium,
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Arabic Name
                    TextFormField(
                      controller: nameArController,
                      style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'اسم المادة (عربي) *',
                        hintText: 'مثال: الرياضيات',
                        filled: true,
                        fillColor: Color(0xFF0F1419),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'اسم المادة بالعربية مطلوب' : null,
                    ),
                    const SizedBox(height: 16),

                    // English/French Name
                    TextFormField(
                      controller: nameController,
                      style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'اسم المادة (فرنسي/انجليزي)',
                        hintText: 'Example: Mathematics',
                        filled: true,
                        fillColor: Color(0xFF0F1419),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Arabic Description
                    TextFormField(
                      controller: descriptionArController,
                      style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'الوصف (عربي)',
                        hintText: 'وصف مختصر للمادة...',
                        filled: true,
                        fillColor: Color(0xFF0F1419),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // English/French Description
                    TextFormField(
                      controller: descriptionController,
                      style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'الوصف (فرنسي/انجليزي)',
                        hintText: 'Subject description...',
                        filled: true,
                        fillColor: Color(0xFF0F1419),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Display Order
                    TextFormField(
                      controller: displayOrderController,
                      style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'ترتيب العرض *',
                        hintText: '1, 2, 3...',
                        filled: true,
                        fillColor: Color(0xFF0F1419),
                      ),
                      validator: (value) =>
                          value?.isEmpty ?? true ? 'ترتيب العرض مطلوب' : null,
                    ),
                    const SizedBox(height: 20),

                    // Icon Selection
                    const Text('الايقونة:', style: AdminTheme.titleSmall),
                    const SizedBox(height: 8),
                    Container(
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1419),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableIcons.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final isSelected = selectedIconIndex == index;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedIconIndex = index),
                            child: Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AdminTheme.accentBlue
                                    : Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 2)
                                    : null,
                              ),
                              child: Icon(
                                _availableIcons[index],
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Color Selection
                    const Text('اللون:', style: AdminTheme.titleSmall),
                    const SizedBox(height: 8),
                    Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F1419),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _availableColors.length,
                        padding: const EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          final isSelected = selectedColorIndex == index;
                          return GestureDetector(
                            onTap: () => setDialogState(() => selectedColorIndex = index),
                            child: Container(
                              width: 34,
                              height: 34,
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: _availableColors[index],
                                borderRadius: BorderRadius.circular(8),
                                border: isSelected
                                    ? Border.all(color: Colors.white, width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: _availableColors[index].withOpacity(0.5),
                                          blurRadius: 8,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Active Toggle
                    Row(
                      children: [
                        const Text('الحالة:', style: AdminTheme.titleSmall),
                        const Spacer(),
                        Switch(
                          value: isActive,
                          onChanged: (value) => setDialogState(() => isActive = value),
                          activeColor: AdminTheme.accentCyan,
                        ),
                        Text(
                          isActive ? 'نشط' : 'غير نشط',
                          style: AdminTheme.bodyMedium.copyWith(
                            color: isActive ? Colors.green : Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('الغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.accentCyan,
              ),
              onPressed: () async {
                if (_formKey.currentState?.validate() ?? false) {
                  await _saveSubject(
                    id: subject?['id'],
                    name: nameController.text.trim(),
                    nameAr: nameArController.text.trim(),
                    description: descriptionController.text.trim(),
                    descriptionAr: descriptionArController.text.trim(),
                    displayOrder: int.tryParse(displayOrderController.text) ?? 1,
                    iconIndex: selectedIconIndex,
                    colorIndex: selectedColorIndex,
                    isActive: isActive,
                    isEdit: isEdit,
                  );
                  if (mounted) Navigator.pop(context);
                }
              },
              child: Text(isEdit ? 'تحديث' : 'اضافة'),
            ),
          ],
        ),
      ),
    );
  }

  /// Save subject (create or update)
  Future<void> _saveSubject({
    String? id,
    required String name,
    required String nameAr,
    required String description,
    required String descriptionAr,
    required int displayOrder,
    required int iconIndex,
    required int colorIndex,
    required bool isActive,
    required bool isEdit,
  }) async {
    setState(() => _isLoading = true);
    try {
      // Note: The database schema uses 'icon_url' not 'icon', and 'cover_image_url' not 'color'
      // We store the icon name and color hex in these URL fields as metadata for now
      final iconName = _getIconName(iconIndex);
      final colorHex = _getColorHex(colorIndex);

      final data = {
        'grade_id': _selectedGradeId,
        'name': name.isNotEmpty ? name : nameAr,
        'name_ar': nameAr,
        'description': description.isNotEmpty ? description : null,
        'description_ar': descriptionAr.isNotEmpty ? descriptionAr : null,
        'display_order': displayOrder,
        // Store icon name and color hex in the available URL fields
        // icon_url stores the icon name (e.g., "menu_book")
        // cover_image_url stores the color hex (e.g., "#3B82F6")
        'icon_url': iconName,
        'cover_image_url': colorHex,
        'is_active': isActive,
      };

      // Add specialization if selected
      if (_selectedSpecializationId != null) {
        data['specialization_id'] = _selectedSpecializationId;
      }

      if (isEdit && id != null) {
        await _supabase.from('subjects').update(data).eq('id', id);
        _showSuccess('تم تحديث المادة بنجاح');
      } else {
        await _supabase.from('subjects').insert(data);

        // Sync with BunnyCDN for new subjects
        _syncSubjectWithBunnyCDN(nameAr.isNotEmpty ? nameAr : name);

        _showSuccess('تم اضافة المادة بنجاح');
      }

      await _loadSubjects();
    } catch (e) {
      _showError('خطا: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Toggle subject active status
  Future<void> _toggleActive(String subjectId, bool currentActive) async {
    try {
      await _supabase
          .from('subjects')
          .update({'is_active': !currentActive})
          .eq('id', subjectId);
      _loadSubjects();
      _showSuccess('تم تحديث حالة المادة');
    } catch (e) {
      _showError('خطا: $e');
    }
  }

  /// Delete subject with confirmation
  Future<void> _deleteSubject(String subjectId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondaryDark,
        title: const Text('تاكيد الحذف', style: AdminTheme.titleMedium),
        content: const Text(
          'هل انت متاكد من حذف هذه المادة؟ سيتم حذف جميع المواضيع والدروس المرتبطة بها!',
          style: AdminTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('الغاء'),
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
        await _supabase.from('subjects').delete().eq('id', subjectId);
        await _loadSubjects();
        _showSuccess('تم حذف المادة');
      } catch (e) {
        _showError('خطا في الحذف: $e');
      }
    }
  }

  /// Sync subject with BunnyCDN
  Future<void> _syncSubjectWithBunnyCDN(String subjectName) async {
    try {
      final grade = _grades.firstWhere(
        (g) => g['id'] == _selectedGradeId,
        orElse: () => {},
      );
      if (grade.isEmpty) return;

      final curriculum = grade['curricula'] as Map<String, dynamic>?;
      if (curriculum == null) return;

      final curriculumName = curriculum['name_ar'] ?? curriculum['name'];
      final gradeName = grade['name_ar'] ?? grade['name'];

      final secureBunny = context.read<SecureBunnyService>();
      await secureBunny.createCollection(
        '$curriculumName › $gradeName › $subjectName',
      );
      debugPrint('BunnyCDN: Subject collection created for "$curriculumName > $gradeName > $subjectName"');
    } catch (e) {
      debugPrint('Warning: Failed to sync subject with BunnyCDN: $e');
    }
  }

  // Helper methods
  String _getIconName(int index) {
    const iconNames = [
      'menu_book', 'calculate', 'science', 'biotech', 'eco',
      'translate', 'language', 'g_translate', 'auto_stories',
      'history_edu', 'public', 'psychology', 'computer',
      'architecture', 'music_note', 'palette', 'sports_soccer', 'engineering',
    ];
    return index < iconNames.length ? iconNames[index] : 'menu_book';
  }

  int _getIconIndexFromName(String name) {
    const iconNames = [
      'menu_book', 'calculate', 'science', 'biotech', 'eco',
      'translate', 'language', 'g_translate', 'auto_stories',
      'history_edu', 'public', 'psychology', 'computer',
      'architecture', 'music_note', 'palette', 'sports_soccer', 'engineering',
    ];
    final index = iconNames.indexOf(name);
    return index >= 0 ? index : 0;
  }

  String _getColorHex(int index) {
    if (index < _availableColors.length) {
      return '#${_availableColors[index].value.toRadixString(16).substring(2).toUpperCase()}';
    }
    return '#3B82F6';
  }

  int _getColorIndexFromHex(String hex) {
    final cleanHex = hex.replaceAll('#', '').toUpperCase();
    for (int i = 0; i < _availableColors.length; i++) {
      final colorHex = _availableColors[i].value.toRadixString(16).substring(2).toUpperCase();
      if (colorHex == cleanHex) return i;
    }
    return 0;
  }

  IconData _getIconFromName(String? name) {
    if (name == null) return Icons.menu_book_rounded;
    const iconMap = {
      'menu_book': Icons.menu_book_rounded,
      'calculate': Icons.calculate_rounded,
      'science': Icons.science_rounded,
      'biotech': Icons.biotech_rounded,
      'eco': Icons.eco_rounded,
      'translate': Icons.translate_rounded,
      'language': Icons.language_rounded,
      'g_translate': Icons.g_translate_rounded,
      'auto_stories': Icons.auto_stories_rounded,
      'history_edu': Icons.history_edu_rounded,
      'public': Icons.public_rounded,
      'psychology': Icons.psychology_rounded,
      'computer': Icons.computer_rounded,
      'architecture': Icons.architecture_rounded,
      'music_note': Icons.music_note_rounded,
      'palette': Icons.palette_rounded,
      'sports_soccer': Icons.sports_soccer_rounded,
      'engineering': Icons.engineering_rounded,
    };
    return iconMap[name] ?? Icons.menu_book_rounded;
  }

  Color _getColorFromHex(String? hex) {
    if (hex == null) return AdminTheme.accentBlue;
    try {
      final cleanHex = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleanHex', radix: 16));
    } catch (e) {
      return AdminTheme.accentBlue;
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AdminTheme.accentRed,
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
        ),
      );
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
                  'ادارة المواد الدراسية',
                  style: AdminTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'اضف وادر المواد الدراسية. اختر المنهج والفصل اولا لعرض المواد المتاحة',
                  style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),

        // Row 1: Curriculum and Grade selectors
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Curriculum Selector
                Expanded(
                  child: Container(
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
                                color: AdminTheme.accentBlue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                color: AdminTheme.accentBlue,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Flexible(
                              child: Text(
                                'المنهج الدراسي',
                                style: AdminTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
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

                // Grade Selector
                Expanded(
                  child: Container(
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
                                color: AdminTheme.accentCyan.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.school_rounded,
                                color: AdminTheme.accentCyan,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Flexible(
                              child: Text(
                                'الفصل الدراسي',
                                style: AdminTheme.titleSmall,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _selectedGradeId,
                          decoration: InputDecoration(
                            hintText: _selectedCurriculumId == null
                                ? 'اختر المنهج اولا'
                                : 'اختر الفصل',
                            filled: true,
                            fillColor: const Color(0xFF1A1F25),
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
                          onChanged: _selectedCurriculumId == null
                              ? null
                              : (value) {
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

        // Row 2: Specialization (if exists) and Add Button
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                // Specialization Selector (only show if specializations exist)
                if (_specializations.isNotEmpty)
                  Expanded(
                    child: Container(
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
                                  color: AdminTheme.accentPink.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.category_rounded,
                                  color: AdminTheme.accentPink,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Flexible(
                                child: Text(
                                  'الشعبة',
                                  style: AdminTheme.titleSmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
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
                              _loadSubjects();
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                if (_specializations.isNotEmpty) const SizedBox(width: 16),

                // Statistics Card
                Expanded(
                  child: Container(
                    decoration: AdminTheme.glassCard(),
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AdminTheme.gradientPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.book_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_subjects.length}',
                                style: AdminTheme.titleLarge.copyWith(
                                  color: AdminTheme.accentCyan,
                                ),
                              ),
                              Text(
                                'مادة دراسية',
                                style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Add Subject Button
                Container(
                  height: 88,
                  decoration: AdminTheme.elevatedCard(gradient: AdminTheme.gradientCyan),
                  child: ElevatedButton(
                    onPressed: _showAddEditDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_circle_rounded, size: 24),
                        SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'اضافة مادة',
                            style: AdminTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // Subjects List
        if (_selectedGradeId == null ||
            (_specializations.isNotEmpty && _selectedSpecializationId == null))
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_rounded,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _selectedCurriculumId == null
                        ? 'اختر المنهج الدراسي اولا'
                        : _selectedGradeId == null
                            ? 'اختر الفصل الدراسي لعرض المواد'
                            : 'اختر الشعبة لعرض المواد',
                    style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                  ),
                ],
              ),
            ),
          )
        else if (_isLoadingSubjects)
          const SliverFillRemaining(
            child: Center(
              child: CircularProgressIndicator(color: AdminTheme.accentCyan),
            ),
          )
        else if (_subjects.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.book_outlined,
                    size: 80,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد مواد في هذا الفصل',
                    style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddEditDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('اضافة مادة جديدة'),
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
                childAspectRatio: 1.1,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) => _buildSubjectCard(_subjects[index]),
                childCount: _subjects.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final isActive = subject['is_active'] == true;
    // Read from the correct database columns: cover_image_url for color, icon_url for icon
    final subjectColor = _getColorFromHex(subject['cover_image_url']);
    final subjectIcon = _getIconFromName(subject['icon_url']);

    return Container(
      decoration: AdminTheme.glassCard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with color accent
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: subjectColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
          ),

          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and Actions Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: subjectColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(subjectIcon, color: subjectColor, size: 24),
                      ),
                      const Spacer(),
                      // Active Toggle
                      IconButton(
                        icon: Icon(
                          isActive ? Icons.visibility : Icons.visibility_off,
                          color: isActive ? Colors.green : Colors.grey,
                          size: 20,
                        ),
                        onPressed: () => _toggleActive(subject['id'], isActive),
                        tooltip: isActive ? 'تعطيل' : 'تفعيل',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // Edit Button
                      IconButton(
                        icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
                        onPressed: () => _showAddEditDialog(subject: subject),
                        tooltip: 'تحرير',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      // Delete Button
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: AdminTheme.accentRed, size: 20),
                        onPressed: () => _deleteSubject(subject['id']),
                        tooltip: 'حذف',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Subject Name (Arabic)
                  Text(
                    subject['name_ar'] ?? subject['name'] ?? 'بدون اسم',
                    style: AdminTheme.titleSmall.copyWith(
                      color: isActive ? Colors.white : Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Subject Name (French/English)
                  if (subject['name'] != null && subject['name'] != subject['name_ar'])
                    Text(
                      subject['name'],
                      style: AdminTheme.bodySmall.copyWith(
                        color: isActive ? Colors.white60 : Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Description
                  if (subject['description_ar'] != null || subject['description'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        subject['description_ar'] ?? subject['description'] ?? '',
                        style: AdminTheme.caption.copyWith(
                          color: Colors.white.withOpacity(0.5),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                  const Spacer(),

                  // Footer: Order and Status
                  Row(
                    children: [
                      Icon(
                        Icons.sort,
                        size: 14,
                        color: Colors.white.withOpacity(0.5),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'ترتيب: ${subject['display_order'] ?? 0}',
                          style: AdminTheme.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.green.withOpacity(0.2)
                              : AdminTheme.accentRed.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isActive ? 'نشط' : 'غير نشط',
                          style: AdminTheme.caption.copyWith(
                            color: isActive ? Colors.green : AdminTheme.accentRed,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
}
