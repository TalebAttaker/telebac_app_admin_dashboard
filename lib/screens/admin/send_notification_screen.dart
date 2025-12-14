import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/admin_theme.dart';

/// Professional Notification Sender Screen for Admin
/// Allows sending push notifications to all users with customizable content

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleArController = TextEditingController();
  final _titleFrController = TextEditingController();
  final _bodyArController = TextEditingController();
  final _bodyFrController = TextEditingController();

  final _supabase = Supabase.instance.client;

  String _selectedType = 'info';
  bool _isSending = false;
  bool _showSuccess = false;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Notification types with icons and colors
  final List<Map<String, dynamic>> _notificationTypes = [
    {
      'value': 'info',
      'label': 'معلومات عامة',
      'labelFr': 'Information',
      'icon': Icons.info_outline_rounded,
      'gradient': AdminTheme.gradientBlue,
    },
    {
      'value': 'new_content',
      'label': 'محتوى جديد',
      'labelFr': 'Nouveau contenu',
      'icon': Icons.video_library_rounded,
      'gradient': AdminTheme.gradientCyan,
    },
    {
      'value': 'live_session',
      'label': 'بث مباشر',
      'labelFr': 'Live',
      'icon': Icons.live_tv_rounded,
      'gradient': AdminTheme.gradientPink,
    },
    {
      'value': 'subscription',
      'label': 'اشتراكات',
      'labelFr': 'Abonnement',
      'icon': Icons.card_membership_rounded,
      'gradient': AdminTheme.gradientPurple,
    },
    {
      'value': 'system',
      'label': 'تنبيه نظام',
      'labelFr': 'Système',
      'icon': Icons.warning_amber_rounded,
      'gradient': AdminTheme.gradientRed,
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _titleArController.dispose();
    _titleFrController.dispose();
    _bodyArController.dispose();
    _bodyFrController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _sendNotification() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSending = true);
    _animationController.forward();

    try {
      // Get project URL and anon key
      final projectUrl = _supabase.rest.url.replaceAll('/rest/v1', '');

      final response = await http.post(
        Uri.parse('$projectUrl/functions/v1/send-push-notification'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${_supabase.auth.currentSession?.accessToken}',
        },
        body: jsonEncode({
          'title': _titleArController.text.trim(),
          'title_ar': _titleArController.text.trim(),
          'title_fr': _titleFrController.text.trim(),
          'body': _bodyArController.text.trim(),
          'body_ar': _bodyArController.text.trim(),
          'body_fr': _bodyFrController.text.trim(),
          'type': _selectedType,
          'sendToAll': true,
        }),
      );

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['success'] == true) {
        setState(() {
          _showSuccess = true;
          _isSending = false;
        });

        // Show success animation
        await Future.delayed(const Duration(seconds: 2));

        if (mounted) {
          setState(() => _showSuccess = false);
          _clearForm();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'تم إرسال الإشعار إلى ${result['users_notified'] ?? 0} مستخدم',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              backgroundColor: Colors.green.shade600,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to send notification');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        _animationController.reverse();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('خطأ: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _clearForm() {
    _titleArController.clear();
    _titleFrController.clear();
    _bodyArController.clear();
    _bodyFrController.clear();
    _animationController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.darkTheme,
      child: Scaffold(
        backgroundColor: AdminTheme.primaryDark,
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(),
              ),

              // Main Content
              SliverPadding(
                padding: const EdgeInsets.all(24),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Section
                      Expanded(
                        flex: 2,
                        child: _buildFormSection(),
                      ),
                      const SizedBox(width: 24),
                      // Preview Section
                      Expanded(
                        child: _buildPreviewSection(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Back Button
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: AdminTheme.glassCard(borderRadius: 12),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AdminTheme.gradientPink,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'إرسال إشعار للمستخدمين',
                          style: AdminTheme.titleMedium,
                        ),
                        SizedBox(height: 4),
                        Text(
                          'أرسل إشعارات فورية لجميع مستخدمي التطبيق',
                          style: AdminTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Stats
          FutureBuilder<int>(
            future: _getActiveTokensCount(),
            builder: (context, snapshot) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: AdminTheme.glassCard(borderRadius: 12),
                child: Row(
                  children: [
                    const Icon(Icons.people_rounded, color: AdminTheme.accentCyan),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${snapshot.data ?? 0}',
                          style: AdminTheme.titleSmall.copyWith(
                            color: AdminTheme.accentCyan,
                          ),
                        ),
                        const Text('مستخدم نشط', style: AdminTheme.caption),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Title
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: AdminTheme.gradientBlue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                const Text('محتوى الإشعار', style: AdminTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 24),

            // Notification Type Selection
            const Text('نوع الإشعار', style: AdminTheme.bodyMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: _notificationTypes.map((type) {
                final isSelected = _selectedType == type['value'];
                return InkWell(
                  onTap: () => setState(() => _selectedType = type['value']),
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: isSelected ? type['gradient'] : null,
                      color: isSelected ? null : AdminTheme.secondaryDark,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          type['icon'],
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          type['label'],
                          style: AdminTheme.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Arabic Title
            _buildTextField(
              controller: _titleArController,
              label: 'عنوان الإشعار (بالعربية)',
              hint: 'مثال: درس جديد متاح الآن!',
              icon: Icons.title_rounded,
              isRequired: true,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 20),

            // French Title
            _buildTextField(
              controller: _titleFrController,
              label: 'عنوان الإشعار (بالفرنسية)',
              hint: 'Exemple: Nouvelle leçon disponible!',
              icon: Icons.translate_rounded,
              isRequired: false,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 20),

            // Arabic Body
            _buildTextField(
              controller: _bodyArController,
              label: 'نص الإشعار (بالعربية)',
              hint: 'اكتب رسالتك هنا...',
              icon: Icons.message_rounded,
              isRequired: true,
              maxLines: 3,
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 20),

            // French Body
            _buildTextField(
              controller: _bodyFrController,
              label: 'نص الإشعار (بالفرنسية)',
              hint: 'Écrivez votre message ici...',
              icon: Icons.translate_rounded,
              isRequired: false,
              maxLines: 3,
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 32),

            // Action Buttons
            Row(
              children: [
                // Clear Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isSending ? null : _clearForm,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.clear_rounded),
                    label: const Text('مسح'),
                  ),
                ),
                const SizedBox(width: 16),
                // Send Button
                Expanded(
                  flex: 2,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AdminTheme.gradientPink,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: AdminTheme.accentPink.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _isSending ? null : _sendNotification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          _isSending ? 'جاري الإرسال...' : 'إرسال الإشعار',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
    TextDirection textDirection = TextDirection.rtl,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Colors.white60),
            const SizedBox(width: 8),
            Text(label, style: AdminTheme.bodyMedium),
            if (isRequired)
              Text(' *', style: TextStyle(color: AdminTheme.accentPink)),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          textDirection: textDirection,
          style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
            filled: true,
            fillColor: AdminTheme.primaryDark,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminTheme.accentBlue, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AdminTheme.accentRed),
            ),
          ),
          validator: isRequired
              ? (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'هذا الحقل مطلوب';
                  }
                  return null;
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildPreviewSection() {
    final selectedType = _notificationTypes.firstWhere(
      (t) => t['value'] == _selectedType,
    );

    return Column(
      children: [
        // Preview Card
        Container(
          decoration: AdminTheme.glassCard(),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      gradient: AdminTheme.gradientCyan,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('معاينة الإشعار', style: AdminTheme.titleSmall),
                ],
              ),
              const SizedBox(height: 24),

              // Phone Mockup
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A2E),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 2,
                  ),
                ),
                child: Column(
                  children: [
                    // Status Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('9:41', style: AdminTheme.caption),
                        Row(
                          children: [
                            Icon(Icons.signal_cellular_4_bar,
                                size: 14, color: Colors.white.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Icon(Icons.wifi,
                                size: 14, color: Colors.white.withOpacity(0.6)),
                            const SizedBox(width: 4),
                            Icon(Icons.battery_full,
                                size: 14, color: Colors.white.withOpacity(0.6)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Notification Preview
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: selectedType['gradient'],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  selectedType['icon'],
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'El-Mouein',
                                          style: AdminTheme.bodySmall.copyWith(
                                            color: Colors.white70,
                                          ),
                                        ),
                                        Text(
                                          'الآن',
                                          style: AdminTheme.caption.copyWith(
                                            color: Colors.white.withOpacity(0.4),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _titleArController.text.isEmpty
                                          ? 'عنوان الإشعار'
                                          : _titleArController.text,
                                      style: AdminTheme.bodyMedium.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _bodyArController.text.isEmpty
                                ? 'نص الإشعار سيظهر هنا...'
                                : _bodyArController.text,
                            style: AdminTheme.bodySmall.copyWith(
                              color: Colors.white60,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textDirection: TextDirection.rtl,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Tips Card
        Container(
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
                      Icons.lightbulb_outline_rounded,
                      color: AdminTheme.accentCyan,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('نصائح', style: AdminTheme.bodyMedium),
                ],
              ),
              const SizedBox(height: 16),
              _buildTip(Icons.check_circle_outline,
                  'اجعل العنوان قصيراً وجذاباً'),
              const SizedBox(height: 8),
              _buildTip(Icons.check_circle_outline,
                  'استخدم رسائل واضحة ومباشرة'),
              const SizedBox(height: 8),
              _buildTip(Icons.check_circle_outline,
                  'تجنب إرسال إشعارات كثيرة'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AdminTheme.accentCyan),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: AdminTheme.caption,
          ),
        ),
      ],
    );
  }

  Future<int> _getActiveTokensCount() async {
    try {
      final response = await _supabase
          .from('fcm_tokens')
          .select()
          .eq('is_active', true);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }
}
