import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/admin_theme.dart';

/// شاشة إدارة الشعب (التخصصات)
/// Specializations Management Screen
/// الشعب تنتمي إلى السنوات الدراسية (مثل: آداب أصلية، آداب عصرية، Bac C، Bac D)
class SpecializationsManagementScreen extends StatefulWidget {
  const SpecializationsManagementScreen({super.key});

  @override
  State<SpecializationsManagementScreen> createState() =>
      _SpecializationsManagementScreenState();
}

class _SpecializationsManagementScreenState
    extends State<SpecializationsManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _specializations = [];
  List<Map<String, dynamic>> _curricula = [];
  List<Map<String, dynamic>> _grades = [];
  bool _isLoading = true;
  String? _selectedCurriculumId;
  String? _selectedGradeId;

  /// Get grades filtered by selected curriculum
  List<Map<String, dynamic>> get _filteredGrades {
    if (_selectedCurriculumId == null) {
      return _grades;
    }
    return _grades
        .where((grade) => grade['curriculum_id'] == _selectedCurriculumId)
        .toList();
  }

  /// Get specializations filtered by selected grade
  List<Map<String, dynamic>> get _filteredSpecializations {
    if (_selectedGradeId == null) {
      // If no grade selected but curriculum is selected, show all specs for that curriculum
      if (_selectedCurriculumId != null) {
        final gradeIds =
            _filteredGrades.map((g) => g['id'] as String).toSet();
        return _specializations
            .where((spec) => gradeIds.contains(spec['grade_id']))
            .toList();
      }
      return _specializations;
    }
    return _specializations
        .where((spec) => spec['grade_id'] == _selectedGradeId)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadSpecializations(),
        _loadCurricula(),
        _loadGrades(),
      ]);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSpecializations() async {
    try {
      final response = await _supabase
          .from('specializations')
          .select('*, grades(name, name_ar, curriculum_id, curricula(name, name_ar))')
          .order('display_order');
      setState(() {
        _specializations = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الشعب: $e')),
        );
      }
    }
  }

  Future<void> _loadCurricula() async {
    try {
      final response = await _supabase
          .from('curricula')
          .select()
          .eq('is_active', true)
          .order('display_order');
      setState(() {
        _curricula = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading curricula: $e');
    }
  }

  Future<void> _loadGrades() async {
    try {
      final response = await _supabase
          .from('grades')
          .select()
          .eq('is_active', true)
          .order('display_order');
      setState(() {
        _grades = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading grades: $e');
    }
  }

  Future<void> _toggleActive(String specId, bool currentActive) async {
    try {
      await _supabase
          .from('specializations')
          .update({'is_active': !currentActive})
          .eq('id', specId);
      _loadSpecializations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة الشعبة')),
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

  Future<void> _deleteSpecialization(String specId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text(
            'هل أنت متأكد من حذف هذه الشعبة؟ سيتم حذف جميع المواد المرتبطة بها!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('specializations').delete().eq('id', specId);
      _loadSpecializations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الشعبة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الحذف: $e')),
        );
      }
    }
  }

  Future<void> _showAddEditDialog({Map<String, dynamic>? specialization}) async {
    final isEdit = specialization != null;
    final existingId = specialization?['id'] ?? '';
    final nameController =
        TextEditingController(text: specialization?['name'] ?? '');
    final nameArController =
        TextEditingController(text: specialization?['name_ar'] ?? '');
    final nameFrController =
        TextEditingController(text: specialization?['name_fr'] ?? '');
    final displayOrderController = TextEditingController(
      text: (specialization?['display_order'] ?? 1).toString(),
    );
    final colorController =
        TextEditingController(text: specialization?['color_hex'] ?? '#3B82F6');

    // Pre-select grade: use existing value for edit, or current filter for new
    String? selectedGradeId = specialization?['grade_id'] ?? _selectedGradeId;

    // Get curriculum from grade if editing
    String? dialogCurriculumId = _selectedCurriculumId;
    if (isEdit && specialization?['grades'] != null) {
      dialogCurriculumId = specialization!['grades']['curriculum_id'];
    }

    // Available icons for specializations
    final availableIcons = [
      'school',
      'science',
      'calculate',
      'menu_book',
      'biotech',
      'psychology',
      'architecture',
      'engineering',
      'code',
      'language',
      'history_edu',
      'public',
    ];
    String selectedIcon = specialization?['icon_name'] ?? 'school';

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Filter grades based on selected curriculum in dialog
          final dialogGrades = dialogCurriculumId != null
              ? _grades
                  .where((g) => g['curriculum_id'] == dialogCurriculumId)
                  .toList()
              : _grades;

          return AlertDialog(
            title: Text(isEdit ? 'تحرير الشعبة' : 'إضافة شعبة جديدة'),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Curriculum Selector
                    DropdownButtonFormField<String>(
                      value: dialogCurriculumId,
                      decoration: const InputDecoration(
                        labelText: 'المنهج الدراسي *',
                        helperText: 'اختر المنهج أولاً',
                      ),
                      items: _curricula.map((curriculum) {
                        return DropdownMenuItem<String>(
                          value: curriculum['id'] as String,
                          child:
                              Text(curriculum['name_ar'] ?? curriculum['name']),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          dialogCurriculumId = value;
                          selectedGradeId = null; // Reset grade selection
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Grade Selector (filtered by curriculum)
                    DropdownButtonFormField<String>(
                      value: dialogGrades.any((g) => g['id'] == selectedGradeId)
                          ? selectedGradeId
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'السنة الدراسية *',
                        helperText: 'اختر السنة التي تنتمي إليها الشعبة',
                      ),
                      items: dialogGrades.map((grade) {
                        return DropdownMenuItem<String>(
                          value: grade['id'] as String,
                          child: Text(grade['name_ar'] ?? grade['name']),
                        );
                      }).toList(),
                      onChanged: dialogCurriculumId == null
                          ? null
                          : (value) {
                              setDialogState(() => selectedGradeId = value);
                            },
                    ),
                    const SizedBox(height: 16),

                    // Show ID as read-only text only in edit mode
                    if (isEdit) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'معرف الشعبة (ID)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              existingId,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالإنجليزية',
                        helperText: 'مثال: Science',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameArController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالعربية *',
                        helperText: 'مثال: آداب أصلية',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: nameFrController,
                      decoration: const InputDecoration(
                        labelText: 'الاسم بالفرنسية',
                        helperText: 'مثال: Lettres Originales',
                      ),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: displayOrderController,
                      decoration: const InputDecoration(
                        labelText: 'ترتيب العرض',
                        helperText: '1, 2, 3, ...',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),

                    // Color picker
                    TextField(
                      controller: colorController,
                      decoration: InputDecoration(
                        labelText: 'اللون (Hex)',
                        helperText: 'مثال: #3B82F6',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _parseColor(colorController.text),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                      ),
                      onChanged: (value) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),

                    // Icon selector
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('الأيقونة:'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: availableIcons.map((iconName) {
                            final isSelected = selectedIcon == iconName;
                            return InkWell(
                              onTap: () {
                                setDialogState(() => selectedIcon = iconName);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AdminTheme.accentBlue.withOpacity(0.3)
                                      : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(color: AdminTheme.accentBlue)
                                      : null,
                                ),
                                child: Icon(
                                  _getIconData(iconName),
                                  color: isSelected
                                      ? AdminTheme.accentBlue
                                      : Colors.grey,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
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
                onPressed: () async {
                  final name = nameController.text.trim();
                  final nameAr = nameArController.text.trim();
                  final nameFr = nameFrController.text.trim();
                  final displayOrder =
                      int.tryParse(displayOrderController.text) ?? 1;
                  final colorHex = colorController.text.trim();

                  if (nameAr.isEmpty || selectedGradeId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('يجب ملء جميع الحقول المطلوبة')),
                    );
                    return;
                  }

                  try {
                    if (isEdit) {
                      await _supabase.from('specializations').update({
                        'name': name,
                        'name_ar': nameAr,
                        'name_fr': nameFr,
                        'display_order': displayOrder,
                        'grade_id': selectedGradeId,
                        'icon_name': selectedIcon,
                        'color_hex': colorHex,
                      }).eq('id', existingId);
                    } else {
                      await _supabase.from('specializations').insert({
                        'name': name,
                        'name_ar': nameAr,
                        'name_fr': nameFr,
                        'display_order': displayOrder,
                        'grade_id': selectedGradeId,
                        'icon_name': selectedIcon,
                        'color_hex': colorHex,
                        'is_active': true,
                      });
                    }

                    Navigator.pop(context);
                    _loadSpecializations();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(isEdit ? 'تم تحديث الشعبة' : 'تم إضافة الشعبة')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e')),
                    );
                  }
                },
                child: Text(isEdit ? 'تحديث' : 'إضافة'),
              ),
            ],
          );
        },
      ),
    );
  }

  Color _parseColor(String hexColor) {
    try {
      if (hexColor.startsWith('#')) {
        return Color(int.parse('FF${hexColor.substring(1)}', radix: 16));
      }
    } catch (_) {}
    return AdminTheme.accentBlue;
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'school':
        return Icons.school;
      case 'science':
        return Icons.science;
      case 'calculate':
        return Icons.calculate;
      case 'menu_book':
        return Icons.menu_book;
      case 'biotech':
        return Icons.biotech;
      case 'psychology':
        return Icons.psychology;
      case 'architecture':
        return Icons.architecture;
      case 'engineering':
        return Icons.engineering;
      case 'code':
        return Icons.code;
      case 'language':
        return Icons.language;
      case 'history_edu':
        return Icons.history_edu;
      case 'public':
        return Icons.public;
      default:
        return Icons.school;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.primaryDark,
      appBar: AppBar(
        title: const Text('إدارة الشعب'),
        backgroundColor: AdminTheme.secondaryDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'إضافة شعبة جديدة',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Section
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: AdminTheme.glassCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_list,
                              color: AdminTheme.accentCyan, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'تصفية الشعب:',
                              style: AdminTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Curriculum filter
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _selectedCurriculumId,
                                  isExpanded: true,
                                  dropdownColor: AdminTheme.secondaryDark,
                                  style: AdminTheme.bodyMedium,
                                  hint: Text('جميع المناهج',
                                      style: AdminTheme.bodyMedium),
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('جميع المناهج',
                                          style: AdminTheme.bodyMedium),
                                    ),
                                    ..._curricula.map((curriculum) {
                                      return DropdownMenuItem<String?>(
                                        value: curriculum['id'] as String,
                                        child: Text(
                                          curriculum['name_ar'] ??
                                              curriculum['name'],
                                          style: AdminTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedCurriculumId = value;
                                      _selectedGradeId =
                                          null; // Reset grade when curriculum changes
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (_selectedCurriculumId != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon:
                                  const Icon(Icons.clear, color: Colors.white54),
                              onPressed: () {
                                setState(() {
                                  _selectedCurriculumId = null;
                                  _selectedGradeId = null;
                                });
                              },
                              tooltip: 'مسح الفلتر',
                              constraints: const BoxConstraints(
                                  minWidth: 40, minHeight: 40),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Grade filter (only shown when curriculum is selected)
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.white.withOpacity(0.1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _filteredGrades
                                          .any((g) => g['id'] == _selectedGradeId)
                                      ? _selectedGradeId
                                      : null,
                                  isExpanded: true,
                                  dropdownColor: AdminTheme.secondaryDark,
                                  style: AdminTheme.bodyMedium,
                                  hint: Text('جميع السنوات',
                                      style: AdminTheme.bodyMedium),
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('جميع السنوات',
                                          style: AdminTheme.bodyMedium),
                                    ),
                                    ..._filteredGrades.map((grade) {
                                      return DropdownMenuItem<String?>(
                                        value: grade['id'] as String,
                                        child: Text(
                                          grade['name_ar'] ?? grade['name'],
                                          style: AdminTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedGradeId = value);
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (_selectedGradeId != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon:
                                  const Icon(Icons.clear, color: Colors.white54),
                              onPressed: () {
                                setState(() => _selectedGradeId = null);
                              },
                              tooltip: 'مسح فلتر السنة',
                              constraints: const BoxConstraints(
                                  minWidth: 40, minHeight: 40),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Specializations List
                Expanded(
                  child: _filteredSpecializations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.category,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                _selectedGradeId != null
                                    ? 'لا توجد شعب في هذه السنة'
                                    : _selectedCurriculumId != null
                                        ? 'لا توجد شعب في هذا المنهج'
                                        : 'لا توجد شعب',
                                style: AdminTheme.titleMedium,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('إضافة شعبة جديدة'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                          itemCount: _filteredSpecializations.length,
                          itemBuilder: (context, index) {
                            final spec = _filteredSpecializations[index];
                            final isActive = spec['is_active'] == true;
                            final gradeData =
                                spec['grades'] as Map<String, dynamic>?;
                            final gradeName = gradeData?['name_ar'] ??
                                gradeData?['name'] ??
                                'غير محدد';
                            final curriculumData = gradeData?['curricula']
                                as Map<String, dynamic>?;
                            final curriculumName = curriculumData?['name_ar'] ??
                                curriculumData?['name'] ??
                                '';
                            final colorHex =
                                spec['color_hex'] as String? ?? '#3B82F6';
                            final iconName =
                                spec['icon_name'] as String? ?? 'school';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: AdminTheme.glassCard(),
                              child: ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? _parseColor(colorHex).withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      _getIconData(iconName),
                                      color: isActive
                                          ? _parseColor(colorHex)
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  spec['name_ar'] ?? spec['name'] ?? 'بدون اسم',
                                  style: AdminTheme.titleSmall.copyWith(
                                    color: isActive ? Colors.white : Colors.grey,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((spec['name'] ?? '').isNotEmpty)
                                      Text(
                                        spec['name'],
                                        style: AdminTheme.bodySmall.copyWith(
                                          color: isActive
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 4),
                                    // Grade and Curriculum badges
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AdminTheme.accentCyan
                                                .withOpacity(0.3),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: AdminTheme.accentCyan
                                                  .withOpacity(0.5),
                                            ),
                                          ),
                                          child: Text(
                                            gradeName,
                                            style:
                                                AdminTheme.bodySmall.copyWith(
                                              color: AdminTheme.accentCyan,
                                              fontSize: 10,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (curriculumName.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AdminTheme.accentBlue
                                                  .withOpacity(0.3),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AdminTheme.accentBlue
                                                    .withOpacity(0.5),
                                              ),
                                            ),
                                            child: Text(
                                              curriculumName,
                                              style:
                                                  AdminTheme.bodySmall.copyWith(
                                                color: AdminTheme.accentBlue,
                                                fontSize: 10,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isActive
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color:
                                            isActive ? Colors.green : Colors.grey,
                                      ),
                                      onPressed: () =>
                                          _toggleActive(spec['id'], isActive),
                                      tooltip: isActive ? 'تعطيل' : 'تفعيل',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blue),
                                      onPressed: () =>
                                          _showAddEditDialog(specialization: spec),
                                      tooltip: 'تحرير',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () =>
                                          _deleteSpecialization(spec['id']),
                                      tooltip: 'حذف',
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
