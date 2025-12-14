import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/admin_theme.dart';

/// شاشة إعدادات الإشعارات التلقائية للمشرف
/// Notification Settings Screen for Admin
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  final _supabase = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;

  // إعدادات الإشعارات
  bool _autoNotifyNewVideo = true;
  bool _autoNotifyLiveStream = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('notification_settings')
          .select('setting_key, setting_value');

      for (final setting in response) {
        switch (setting['setting_key']) {
          case 'auto_notify_new_video':
            _autoNotifyNewVideo = setting['setting_value'] ?? true;
            break;
          case 'auto_notify_live_stream':
            _autoNotifyLiveStream = setting['setting_value'] ?? true;
            break;
        }
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }

    setState(() => _isLoading = false);
  }

  Future<void> _updateSetting(String key, bool value) async {
    setState(() => _isSaving = true);

    try {
      await _supabase.from('notification_settings').update({
        'setting_value': value,
        'updated_at': DateTime.now().toIso8601String(),
        'updated_by': _supabase.auth.currentUser?.id,
      }).eq('setting_key', key);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text(value ? 'تم تفعيل الإشعارات' : 'تم إيقاف الإشعارات'),
              ],
            ),
            backgroundColor: value ? Colors.green.shade600 : Colors.orange.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
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

    setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.darkTheme,
      child: Scaffold(
        backgroundColor: AdminTheme.primaryDark,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AdminTheme.accentBlue,
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoCard(),
                            const SizedBox(height: 24),
                            _buildSettingsCard(),
                            const SizedBox(height: 24),
                            _buildStatsCard(),
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
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: AdminTheme.glassCard(borderRadius: 12),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AdminTheme.gradientPurple,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.settings_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إعدادات الإشعارات التلقائية',
                  style: AdminTheme.titleMedium,
                ),
                SizedBox(height: 4),
                Text(
                  'تحكم في إرسال الإشعارات التلقائية للمستخدمين',
                  style: AdminTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminTheme.accentBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AdminTheme.accentBlue,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ملاحظة',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'تؤثر هذه الإعدادات على الإشعارات التلقائية فقط. يمكنك دائماً إرسال إشعارات يدوية من شاشة إرسال الإشعارات.',
                  style: AdminTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard() {
    return Container(
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
              const Text('الإشعارات التلقائية', style: AdminTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 24),

          // إعداد إشعارات الفيديو الجديد
          _buildSettingTile(
            icon: Icons.video_library_rounded,
            gradient: AdminTheme.gradientCyan,
            title: 'إشعارات الدروس الجديدة',
            titleFr: 'Notifications des nouvelles leçons',
            description: 'إرسال إشعار تلقائي عند إضافة فيديو/درس جديد للمنصة',
            value: _autoNotifyNewVideo,
            onChanged: (value) {
              setState(() => _autoNotifyNewVideo = value);
              _updateSetting('auto_notify_new_video', value);
            },
          ),

          const SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.1)),
          const SizedBox(height: 20),

          // إعداد إشعارات البث المباشر
          _buildSettingTile(
            icon: Icons.live_tv_rounded,
            gradient: AdminTheme.gradientPink,
            title: 'إشعارات البث المباشر',
            titleFr: 'Notifications des lives',
            description: 'إرسال إشعار تلقائي عند بدء حصة/بث مباشر جديد',
            value: _autoNotifyLiveStream,
            onChanged: (value) {
              setState(() => _autoNotifyLiveStream = value);
              _updateSetting('auto_notify_live_stream', value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required LinearGradient gradient,
    required String title,
    required String titleFr,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                titleFr,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: AdminTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        _buildCustomSwitch(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _buildCustomSwitch({
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      onTap: _isSaving ? null : () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 60,
        height: 32,
        decoration: BoxDecoration(
          gradient: value ? AdminTheme.gradientGreen : null,
          color: value ? null : AdminTheme.secondaryDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: value ? Colors.transparent : Colors.white.withOpacity(0.2),
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: const Color(0xFF10B981).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              left: value ? 30 : 4,
              top: 4,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: _isSaving
                    ? const Padding(
                        padding: EdgeInsets.all(4),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(AdminTheme.accentBlue),
                        ),
                      )
                    : Icon(
                        value ? Icons.check_rounded : Icons.close_rounded,
                        size: 14,
                        color: value
                            ? const Color(0xFF10B981)
                            : AdminTheme.accentRed,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
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
                  gradient: AdminTheme.gradientPurple,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              const Text('إحصائيات سريعة', style: AdminTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 24),
          FutureBuilder<Map<String, int>>(
            future: _getStats(),
            builder: (context, snapshot) {
              final stats = snapshot.data ?? {'tokens': 0, 'notifications': 0};
              return Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.devices_rounded,
                      label: 'أجهزة مسجلة',
                      value: '${stats['tokens']}',
                      gradient: AdminTheme.gradientBlue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.notifications_active_rounded,
                      label: 'إشعارات اليوم',
                      value: '${stats['notifications']}',
                      gradient: AdminTheme.gradientPink,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AdminTheme.primaryDark,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AdminTheme.caption,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Future<Map<String, int>> _getStats() async {
    try {
      final tokensResponse = await _supabase
          .from('fcm_tokens')
          .select()
          .eq('is_active', true);

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final notificationsResponse = await _supabase
          .from('notifications')
          .select()
          .gte('created_at', startOfDay.toIso8601String());

      return {
        'tokens': (tokensResponse as List).length,
        'notifications': (notificationsResponse as List).length,
      };
    } catch (e) {
      return {'tokens': 0, 'notifications': 0};
    }
  }
}
