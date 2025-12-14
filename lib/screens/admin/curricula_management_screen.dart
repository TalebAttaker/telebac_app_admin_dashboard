import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../../models/curriculum.dart';
import '../../services/secure_bunny_service.dart';
import '../../utils/admin_theme.dart';

/// شاشة إدارة المناهج الدراسية
/// Curricula Management Screen for Admin Panel
class CurriculaManagementScreen extends StatefulWidget {
  final bool isEmbedded;

  const CurriculaManagementScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<CurriculaManagementScreen> createState() =>
      _CurriculaManagementScreenState();
}

class _CurriculaManagementScreenState extends State<CurriculaManagementScreen> {
  final _supabase = Supabase.instance.client;

  List<Curriculum> _curricula = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurricula();
  }

  Future<void> _loadCurricula() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('curricula')
          .select()
          .order('display_order');

      _curricula = (response as List)
          .map((json) => Curriculum.fromJson(json))
          .toList();

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل المناهج: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _addCurriculum() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _CurriculumDialog(),
    );

    if (result != null) {
      try {
        await _supabase.from('curricula').insert(result);
        _loadCurricula();

        // Sync with BunnyCDN - create collection for the new curriculum
        // This runs in the background and doesn't block the UI
        _syncCurriculumWithBunnyCDN(result['name_ar'] ?? result['name']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إضافة المنهج بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Sync curriculum with BunnyCDN by creating a collection
  /// This is non-blocking and won't affect the main operation
  Future<void> _syncCurriculumWithBunnyCDN(String curriculumName) async {
    try {
      final secureBunny = context.read<SecureBunnyService>();
      await secureBunny.createCollection(curriculumName);
      debugPrint('BunnyCDN: Curriculum collection created for "$curriculumName"');
    } catch (e) {
      // Log warning but don't show error to user - this is a background sync
      debugPrint('Warning: Failed to sync curriculum with BunnyCDN: $e');
    }
  }

  Future<void> _editCurriculum(Curriculum curriculum) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CurriculumDialog(curriculum: curriculum),
    );

    if (result != null) {
      try {
        await _supabase
            .from('curricula')
            .update(result)
            .eq('id', curriculum.id);
        _loadCurricula();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث المنهج بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteCurriculum(Curriculum curriculum) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المنهج'),
        content: Text('هل أنت متأكد من حذف "${curriculum.nameAr ?? curriculum.name}"؟\n\nسيتم فك ارتباط جميع السنوات الدراسية المرتبطة.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // فك ارتباط السنوات أولاً
        await _supabase
            .from('grades')
            .update({'curriculum_id': null})
            .eq('curriculum_id', curriculum.id);

        // ثم حذف المنهج
        await _supabase.from('curricula').delete().eq('id', curriculum.id);
        _loadCurricula();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم حذف المنهج بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('خطأ: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _toggleActive(Curriculum curriculum) async {
    try {
      await _supabase
          .from('curricula')
          .update({'is_active': !curriculum.isActive})
          .eq('id', curriculum.id);
      _loadCurricula();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _curricula.isEmpty
            ? _buildEmptyState()
            : _buildCurriculaList();

    if (widget.isEmbedded) {
      return Column(
        children: [
          _buildHeader(),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      backgroundColor: AdminTheme.primaryDark,
      appBar: AppBar(
        title: const Text('إدارة المناهج الدراسية'),
        backgroundColor: AdminTheme.secondaryDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCurricula,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCurriculum,
        icon: const Icon(Icons.add),
        label: const Text('إضافة منهج'),
        backgroundColor: AdminTheme.accentBlue,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AdminTheme.secondaryDark,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.accentBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: AdminTheme.accentBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'المناهج الدراسية',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_curricula.length} منهج',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          if (widget.isEmbedded)
            ElevatedButton.icon(
              onPressed: _addCurriculum,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AdminTheme.accentBlue,
                foregroundColor: Colors.white,
              ),
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
            Icons.school_outlined,
            size: 80,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد مناهج',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'اضغط على زر الإضافة لإنشاء منهج جديد',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurriculaList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _curricula.length,
      itemBuilder: (context, index) {
        final curriculum = _curricula[index];
        return _CurriculumCard(
          curriculum: curriculum,
          onEdit: () => _editCurriculum(curriculum),
          onDelete: () => _deleteCurriculum(curriculum),
          onToggleActive: () => _toggleActive(curriculum),
        );
      },
    );
  }
}

/// بطاقة المنهج
class _CurriculumCard extends StatelessWidget {
  final Curriculum curriculum;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleActive;

  const _CurriculumCard({
    required this.curriculum,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleActive,
  });

  Color _getColor() {
    try {
      final colorStr = curriculum.color;
      if (colorStr.startsWith('#')) {
        return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
    } catch (_) {}
    return AdminTheme.accentBlue;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AdminTheme.secondaryDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: curriculum.isActive ? color.withValues(alpha: 0.3) : Colors.white10,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            curriculum.nameAr ?? curriculum.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: curriculum.isActive
                                  ? Colors.green.withValues(alpha: 0.1)
                                  : Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              curriculum.isActive ? 'نشط' : 'غير نشط',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: curriculum.isActive
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (curriculum.nameFr != null && curriculum.nameFr!.isNotEmpty)
                        Text(
                          curriculum.nameFr!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white60,
                          ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        onEdit();
                        break;
                      case 'toggle':
                        onToggleActive();
                        break;
                      case 'delete':
                        onDelete();
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('تعديل'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle',
                      child: Row(
                        children: [
                          Icon(
                            curriculum.isActive
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(curriculum.isActive ? 'إخفاء' : 'إظهار'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('حذف', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (curriculum.descriptionAr != null &&
                curriculum.descriptionAr!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                curriculum.descriptionAr!,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white60,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(
                  icon: Icons.sort,
                  label: 'ترتيب: ${curriculum.displayOrder}',
                ),
                const SizedBox(width: 8),
                _InfoChip(
                  icon: Icons.color_lens,
                  label: curriculum.color,
                  color: color,
                ),
              ],
            ),
            // Contact information row
            if (curriculum.phone != null || curriculum.whatsapp != null || curriculum.email != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (curriculum.phone != null && curriculum.phone!.isNotEmpty)
                    _InfoChip(
                      icon: Icons.phone,
                      label: curriculum.phone!,
                    ),
                  if (curriculum.whatsapp != null && curriculum.whatsapp!.isNotEmpty)
                    _InfoChip(
                      icon: Icons.chat,
                      label: curriculum.whatsapp!,
                      color: Colors.green,
                    ),
                  if (curriculum.email != null && curriculum.email!.isNotEmpty)
                    _InfoChip(
                      icon: Icons.email,
                      label: curriculum.email!,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// شريحة معلومات
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.white60),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white60,
            ),
          ),
        ],
      ),
    );
  }
}

/// نافذة إضافة/تعديل المنهج
class _CurriculumDialog extends StatefulWidget {
  final Curriculum? curriculum;

  const _CurriculumDialog({this.curriculum});

  @override
  State<_CurriculumDialog> createState() => _CurriculumDialogState();
}

class _CurriculumDialogState extends State<_CurriculumDialog> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  late TextEditingController _nameController;
  late TextEditingController _nameArController;
  late TextEditingController _nameFrController;
  late TextEditingController _descriptionController;
  late TextEditingController _descriptionArController;
  late TextEditingController _descriptionFrController;
  late TextEditingController _colorController;
  late TextEditingController _orderController;
  // Contact fields
  late TextEditingController _phoneController;
  late TextEditingController _whatsappController;
  late TextEditingController _emailController;
  bool _isActive = true;
  // Logo upload
  String? _logoUrl;
  Uint8List? _selectedLogoBytes;
  String? _selectedLogoName;
  bool _isUploadingLogo = false;

  @override
  void initState() {
    super.initState();
    final c = widget.curriculum;
    _nameController = TextEditingController(text: c?.name ?? '');
    _nameArController = TextEditingController(text: c?.nameAr ?? '');
    _nameFrController = TextEditingController(text: c?.nameFr ?? '');
    _descriptionController = TextEditingController(text: c?.description ?? '');
    _descriptionArController = TextEditingController(text: c?.descriptionAr ?? '');
    _descriptionFrController = TextEditingController(text: c?.descriptionFr ?? '');
    _colorController = TextEditingController(text: c?.color ?? '#4CAF50');
    _orderController = TextEditingController(text: (c?.displayOrder ?? 0).toString());
    _phoneController = TextEditingController(text: c?.phone ?? '');
    _whatsappController = TextEditingController(text: c?.whatsapp ?? '');
    _emailController = TextEditingController(text: c?.email ?? '');
    _isActive = c?.isActive ?? true;
    _logoUrl = c?.logoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameArController.dispose();
    _nameFrController.dispose();
    _descriptionController.dispose();
    _descriptionArController.dispose();
    _descriptionFrController.dispose();
    _colorController.dispose();
    _orderController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Pick and validate SVG file
  Future<void> _pickLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['svg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;

        // Validate file extension
        if (!file.name.toLowerCase().endsWith('.svg')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('يجب أن يكون الملف بصيغة SVG فقط'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Validate file content starts with SVG tag
        if (file.bytes != null) {
          final content = String.fromCharCodes(file.bytes!);
          if (!content.contains('<svg') && !content.contains('<?xml')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('الملف ليس ملف SVG صالح'),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }

        setState(() {
          _selectedLogoBytes = file.bytes;
          _selectedLogoName = file.name;
        });
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

  /// Upload logo to Supabase storage
  Future<String?> _uploadLogo() async {
    if (_selectedLogoBytes == null || _selectedLogoName == null) {
      return _logoUrl;
    }

    try {
      setState(() => _isUploadingLogo = true);

      final fileName = 'curriculum_${DateTime.now().millisecondsSinceEpoch}.svg';
      final path = 'curricula-logos/$fileName';

      await _supabase.storage.from('public').uploadBinary(
        path,
        _selectedLogoBytes!,
        fileOptions: const FileOptions(
          contentType: 'image/svg+xml',
          upsert: true,
        ),
      );

      final publicUrl = _supabase.storage.from('public').getPublicUrl(path);

      setState(() => _isUploadingLogo = false);
      return publicUrl;
    } catch (e) {
      setState(() => _isUploadingLogo = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في رفع الشعار: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return _logoUrl;
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;

    // Upload logo if selected
    String? finalLogoUrl = _logoUrl;
    if (_selectedLogoBytes != null) {
      finalLogoUrl = await _uploadLogo();
    }

    if (!mounted) return;

    Navigator.pop(context, {
      'name': _nameController.text.trim(),
      'name_ar': _nameArController.text.trim(),
      'name_fr': _nameFrController.text.trim(),
      'description': _descriptionController.text.trim(),
      'description_ar': _descriptionArController.text.trim(),
      'description_fr': _descriptionFrController.text.trim(),
      'color': _colorController.text.trim(),
      'display_order': int.tryParse(_orderController.text) ?? 0,
      'is_active': _isActive,
      'phone': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'whatsapp': _whatsappController.text.trim().isEmpty ? null : _whatsappController.text.trim(),
      'email': _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      'logo_url': finalLogoUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.curriculum != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add,
                    color: AdminTheme.accentBlue,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'تعديل المنهج' : 'إضافة منهج جديد',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم (English)',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) =>
                            v?.trim().isEmpty == true ? 'مطلوب' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameArController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم بالعربية',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _nameFrController,
                        decoration: const InputDecoration(
                          labelText: 'الاسم بالفرنسية',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionArController,
                        decoration: const InputDecoration(
                          labelText: 'الوصف بالعربية',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _colorController,
                              decoration: const InputDecoration(
                                labelText: 'اللون (Hex)',
                                border: OutlineInputBorder(),
                                hintText: '#4CAF50',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _orderController,
                              decoration: const InputDecoration(
                                labelText: 'الترتيب',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: const Text('نشط'),
                        subtitle: const Text('سيظهر للمستخدمين'),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const Divider(height: 24),
                      // Contact Information Section
                      const Text(
                        'معلومات التواصل',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.accentBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'رقم الهاتف',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                          hintText: '+222 XX XX XX XX',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _whatsappController,
                        decoration: const InputDecoration(
                          labelText: 'رقم الواتساب',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.chat, color: Colors.green),
                          hintText: '+222 XX XX XX XX',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'البريد الإلكتروني',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.email),
                          hintText: 'example@domain.com',
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v != null && v.isNotEmpty && !v.contains('@')) {
                            return 'بريد إلكتروني غير صالح';
                          }
                          return null;
                        },
                      ),
                      const Divider(height: 24),
                      // Logo Upload Section
                      const Text(
                        'شعار المنهج (SVG فقط)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AdminTheme.accentBlue,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            if (_selectedLogoName != null) ...[
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedLogoName!,
                                      style: const TextStyle(color: Colors.green),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => setState(() {
                                      _selectedLogoBytes = null;
                                      _selectedLogoName = null;
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ] else if (_logoUrl != null) ...[
                              Row(
                                children: [
                                  const Icon(Icons.image, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'شعار موجود',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close, color: Colors.red),
                                    onPressed: () => setState(() {
                                      _logoUrl = null;
                                    }),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            OutlinedButton.icon(
                              onPressed: _isUploadingLogo ? null : _pickLogo,
                              icon: _isUploadingLogo
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.upload_file),
                              label: Text(_isUploadingLogo ? 'جاري الرفع...' : 'اختر ملف SVG'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'يُسمح فقط بملفات SVG',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isUploadingLogo ? null : () => Navigator.pop(context),
                    child: const Text('إلغاء'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _isUploadingLogo ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AdminTheme.accentBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isUploadingLogo
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(isEditing ? 'حفظ التغييرات' : 'إضافة'),
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
