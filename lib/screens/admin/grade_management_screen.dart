import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/secure_bunny_service.dart';
import '../../utils/admin_theme.dart';

class GradeManagementScreen extends StatefulWidget {
  const GradeManagementScreen({super.key});

  @override
  State<GradeManagementScreen> createState() => _GradeManagementScreenState();
}

class _GradeManagementScreenState extends State<GradeManagementScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _curricula = [];
  bool _isLoading = true;
  String? _selectedCurriculumId; // Filter by curriculum

  /// Get grades filtered by selected curriculum
  List<Map<String, dynamic>> get _filteredGrades {
    if (_selectedCurriculumId == null) {
      return _grades;
    }
    return _grades.where((grade) => grade['curriculum_id'] == _selectedCurriculumId).toList();
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
        _loadGrades(),
        _loadCurricula(),
      ]);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGrades() async {
    try {
      final response = await _supabase
          .from('grades')
          .select('*, curricula(name, name_ar)')
          .order('display_order');
      setState(() {
        _grades = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل الفصول: $e')),
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

  Future<void> _toggleActive(String gradeId, bool currentActive) async {
    try {
      await _supabase
          .from('grades')
          .update({'is_active': !currentActive})
          .eq('id', gradeId);
      _loadGrades();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حالة الفصل')),
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

  Future<void> _deleteGrade(String gradeId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل أنت متأكد من حذف هذا الفصل؟ سيتم حذف جميع المواد والمواضيع والدروس المرتبطة به!'),
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
      await _supabase.from('grades').delete().eq('id', gradeId);
      _loadGrades();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم حذف الفصل')),
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

  Future<void> _showAddEditDialog({Map<String, dynamic>? grade}) async {
    final isEdit = grade != null;
    final existingId = grade?['id'] ?? '';
    final nameController = TextEditingController(text: grade?['name'] ?? '');
    final nameArController = TextEditingController(text: grade?['name_ar'] ?? '');
    final displayOrderController = TextEditingController(
      text: (grade?['display_order'] ?? 1).toString(),
    );
    // Pre-select curriculum: use existing value for edit, or current filter for new
    String? selectedCurriculumId = grade?['curriculum_id'] ?? _selectedCurriculumId;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'تحرير الفصل' : 'إضافة فصل جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Curriculum Selector
                DropdownButtonFormField<String>(
                  value: selectedCurriculumId,
                  decoration: const InputDecoration(
                    labelText: 'المنهج الدراسي *',
                    helperText: 'اختر المنهج الذي ينتمي إليه الفصل',
                  ),
                  items: _curricula.map((curriculum) {
                    return DropdownMenuItem<String>(
                      value: curriculum['id'] as String,
                      child: Text(curriculum['name_ar'] ?? curriculum['name']),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() => selectedCurriculumId = value);
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
                          'معرف الفصل (ID)',
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
                    helperText: 'مثال: 4th Preparatory',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameArController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم بالعربية *',
                    helperText: 'مثال: الرابع اعدادي',
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
              ],
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
                final displayOrder = int.tryParse(displayOrderController.text) ?? 1;

                if (nameAr.isEmpty || selectedCurriculumId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('يجب ملء جميع الحقول المطلوبة')),
                  );
                  return;
                }

                try {
                  if (isEdit) {
                    await _supabase.from('grades').update({
                      'name': name,
                      'name_ar': nameAr,
                      'display_order': displayOrder,
                      'curriculum_id': selectedCurriculumId,
                    }).eq('id', existingId);
                  } else {
                    // Let Supabase auto-generate UUID for the new grade
                    await _supabase.from('grades').insert({
                      'name': name,
                      'name_ar': nameAr,
                      'display_order': displayOrder,
                      'curriculum_id': selectedCurriculumId,
                      'is_active': true,
                    });

                    // Sync with BunnyCDN - create collection for the new grade
                    final curriculum = _curricula.firstWhere(
                      (c) => c['id'] == selectedCurriculumId,
                      orElse: () => {},
                    );
                    if (curriculum.isNotEmpty) {
                      _syncGradeWithBunnyCDN(
                        curriculum['name_ar'] ?? curriculum['name'],
                        nameAr.isNotEmpty ? nameAr : name,
                      );
                    }
                  }

                  Navigator.pop(context);
                  _loadGrades();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isEdit ? 'تم تحديث الفصل' : 'تم إضافة الفصل')),
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
        ),
      ),
    );
  }

  /// Sync grade with BunnyCDN by creating a collection
  /// This is non-blocking and won't affect the main operation
  Future<void> _syncGradeWithBunnyCDN(String curriculumName, String gradeName) async {
    try {
      final secureBunny = context.read<SecureBunnyService>();
      await secureBunny.createCollection('$curriculumName › $gradeName');
      debugPrint('BunnyCDN: Grade collection created for "$curriculumName › $gradeName"');
    } catch (e) {
      // Log warning but don't show error to user - this is a background sync
      debugPrint('Warning: Failed to sync grade with BunnyCDN: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.primaryDark,
      appBar: AppBar(
        title: const Text('إدارة الفصول'),
        backgroundColor: AdminTheme.secondaryDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle),
            onPressed: () => _showAddEditDialog(),
            tooltip: 'إضافة فصل جديد',
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
                // Curriculum Filter Dropdown - Responsive layout
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: AdminTheme.glassCard(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.filter_list, color: AdminTheme.accentCyan, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'تصفية حسب المنهج:',
                              style: AdminTheme.bodyMedium,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white.withOpacity(0.1)),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String?>(
                                  value: _selectedCurriculumId,
                                  isExpanded: true,
                                  dropdownColor: AdminTheme.secondaryDark,
                                  style: AdminTheme.bodyMedium,
                                  hint: Text('جميع المناهج', style: AdminTheme.bodyMedium),
                                  items: [
                                    DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('جميع المناهج', style: AdminTheme.bodyMedium),
                                    ),
                                    ..._curricula.map((curriculum) {
                                      return DropdownMenuItem<String?>(
                                        value: curriculum['id'] as String,
                                        child: Text(
                                          curriculum['name_ar'] ?? curriculum['name'],
                                          style: AdminTheme.bodyMedium,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      );
                                    }),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedCurriculumId = value);
                                  },
                                ),
                              ),
                            ),
                          ),
                          if (_selectedCurriculumId != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white54),
                              onPressed: () {
                                setState(() => _selectedCurriculumId = null);
                              },
                              tooltip: 'مسح الفلتر',
                              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              padding: EdgeInsets.zero,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Grades List
                Expanded(
                  child: _filteredGrades.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.school, size: 64, color: Colors.white.withOpacity(0.3)),
                              const SizedBox(height: 16),
                              Text(
                                _selectedCurriculumId != null
                                    ? 'لا توجد فصول في هذا المنهج'
                                    : 'لا توجد فصول',
                                style: AdminTheme.titleMedium,
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => _showAddEditDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('إضافة فصل جديد'),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          itemCount: _filteredGrades.length,
                          itemBuilder: (context, index) {
                            final grade = _filteredGrades[index];
                            final isActive = grade['is_active'] == true;
                            final curriculumData = grade['curricula'] as Map<String, dynamic>?;
                            final curriculumName = curriculumData?['name_ar'] ?? curriculumData?['name'] ?? 'غير محدد';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: AdminTheme.glassCard(),
                              child: ListTile(
                                leading: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? AdminTheme.accentCyan.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      grade['display_order'].toString(),
                                      style: AdminTheme.titleMedium.copyWith(
                                        color: isActive ? AdminTheme.accentCyan : Colors.grey,
                                      ),
                                    ),
                                  ),
                                ),
                                title: Text(
                                  grade['name_ar'] ?? grade['name'] ?? 'بدون اسم',
                                  style: AdminTheme.titleSmall.copyWith(
                                    color: isActive ? Colors.white : Colors.grey,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if ((grade['name'] ?? '').isNotEmpty)
                                      Text(
                                        grade['name'],
                                        style: AdminTheme.bodySmall.copyWith(
                                          color: isActive
                                              ? Colors.white.withOpacity(0.7)
                                              : Colors.grey,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    const SizedBox(height: 4),
                                    // Curriculum badge only (no ID display to avoid overflow)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AdminTheme.accentBlue.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: AdminTheme.accentBlue.withOpacity(0.5),
                                        ),
                                      ),
                                      child: Text(
                                        curriculumName,
                                        style: AdminTheme.bodySmall.copyWith(
                                          color: AdminTheme.accentBlue,
                                          fontSize: 10,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        isActive ? Icons.visibility : Icons.visibility_off,
                                        color: isActive ? Colors.green : Colors.grey,
                                      ),
                                      onPressed: () => _toggleActive(grade['id'], isActive),
                                      tooltip: isActive ? 'تعطيل' : 'تفعيل',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit, color: Colors.blue),
                                      onPressed: () => _showAddEditDialog(grade: grade),
                                      tooltip: 'تحرير',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteGrade(grade['id']),
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
