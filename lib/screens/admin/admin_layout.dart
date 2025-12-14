import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/admin_theme.dart';
import 'modern_admin_dashboard.dart';
import 'modern_video_upload_screen.dart';
import 'topic_management_screen.dart';
import 'grade_subject_management_screen.dart';
import 'grade_management_screen.dart';
import 'specializations_management_screen.dart';
import 'subjects_management_screen.dart';
import 'enhanced_video_manager_screen.dart';
import 'payment_verification_screen.dart';
import 'subscription_pricing_screen.dart';
import 'subscriptions_management_screen.dart';
import 'live_stream_management_screen.dart';
import 'users_management_screen.dart';
import 'curricula_management_screen.dart';
import 'send_notification_screen.dart';

/// Admin Layout with Persistent Sidebar
/// The sidebar stays visible at all times, content area changes

class AdminLayout extends StatefulWidget {
  const AdminLayout({super.key});

  @override
  State<AdminLayout> createState() => _AdminLayoutState();
}

class _AdminLayoutState extends State<AdminLayout> {
  final _supabase = Supabase.instance.client;
  int _selectedIndex = 0;
  int _pendingPaymentsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPendingPaymentsCount();
  }

  Future<void> _loadPendingPaymentsCount() async {
    try {
      final response = await _supabase
          .from('payment_proofs')
          .select('*')
          .eq('status', 'pending');

      if (mounted) {
        setState(() {
          _pendingPaymentsCount = (response as List).length;
        });
      }
    } catch (e) {
      debugPrint('Error loading pending payments count: $e');
    }
  }

  // All admin screens - Unified video upload for all content types
  // Note: PDF upload is now integrated directly into video upload screen
  final List<Widget> _screens = [
    const ModernAdminDashboard(isEmbedded: true), // Dashboard home - index 0
    const CurriculaManagementScreen(), // Curricula management - index 1
    const GradeManagementScreen(), // Grade management - index 2
    const SpecializationsManagementScreen(), // Specializations management - index 3 (NEW)
    const SubjectsManagementScreen(), // Subjects management - index 4
    const TopicManagementScreen(), // Topic management - index 5
    const EnhancedVideoManagerScreen(isEmbedded: true), // Video management - index 6
    const ModernVideoUploadScreen(isEmbedded: true), // Unified video upload - index 7
    const GradeSubjectManagementScreen(), // Grades & Subjects view - index 8
    const PaymentVerificationScreen(isEmbedded: true), // Payment verification - index 9
    const SubscriptionPricingScreen(isEmbedded: true), // Pricing management - index 10
    const SubscriptionsManagementScreen(isEmbedded: true), // Subscriptions - index 11
    const LiveStreamManagementScreen(isEmbedded: true), // Live streaming - index 12
    const UsersManagementScreen(isEmbedded: true), // Users management - index 13
    const SendNotificationScreen(), // Send notifications - index 14
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AdminTheme.darkTheme,
      child: Scaffold(
        backgroundColor: AdminTheme.primaryDark,
        body: SafeArea(
          child: Row(
            children: [
              // ✅ PERSISTENT SIDEBAR - Always visible
              _buildSidebar(),

              // ✅ CONTENT AREA - Changes based on selection
              Expanded(
                child: _screens[_selectedIndex],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        color: AdminTheme.secondaryDark,
        border: Border(
          right: BorderSide(
            color: Colors.white.withOpacity(0.05),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: AdminTheme.gradientBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school, color: Colors.white),
                ),
                const SizedBox(width: 12),
                const Text(
                  'تعليم موريتانيا',
                  style: AdminTheme.titleSmall,
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 16),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _MenuItem(
                  icon: Icons.dashboard_rounded,
                  title: 'لوحة التحكم',
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'إدارة المحتوى',
                    style: AdminTheme.caption,
                  ),
                ),
                _MenuItem(
                  icon: Icons.menu_book_rounded,
                  title: 'إدارة المناهج',
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                _MenuItem(
                  icon: Icons.grade_rounded,
                  title: 'إدارة الفصول',
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _MenuItem(
                  icon: Icons.category_rounded,
                  title: 'إدارة الشعب',
                  subtitle: 'التخصصات داخل السنوات الدراسية',
                  isSelected: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
                _MenuItem(
                  icon: Icons.book_rounded,
                  title: 'إدارة المواد',
                  subtitle: 'إضافة وتعديل المواد الدراسية',
                  isSelected: _selectedIndex == 4,
                  onTap: () => setState(() => _selectedIndex = 4),
                ),
                _MenuItem(
                  icon: Icons.topic_rounded,
                  title: 'إدارة المواضيع',
                  isSelected: _selectedIndex == 5,
                  onTap: () => setState(() => _selectedIndex = 5),
                ),
                _MenuItem(
                  icon: Icons.video_settings_rounded,
                  title: 'إدارة الفيديوهات',
                  isSelected: _selectedIndex == 6,
                  onTap: () => setState(() => _selectedIndex = 6),
                ),
                _MenuItem(
                  icon: Icons.school_rounded,
                  title: 'عرض جميع البيانات',
                  isSelected: _selectedIndex == 8,
                  onTap: () => setState(() => _selectedIndex = 8),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'رفع المحتوى',
                    style: AdminTheme.caption,
                  ),
                ),
                _MenuItem(
                  icon: Icons.video_library_rounded,
                  title: 'رفع فيديو (موحد)',
                  subtitle: 'دروس، تمارين، ملخصات، باكالوريا + PDF',
                  isSelected: _selectedIndex == 7,
                  onTap: () => setState(() => _selectedIndex = 7),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'إدارة الاشتراكات',
                    style: AdminTheme.caption,
                  ),
                ),
                _MenuItem(
                  icon: Icons.receipt_long_rounded,
                  title: 'مراجعة الدفعات',
                  isSelected: _selectedIndex == 9,
                  badge: _pendingPaymentsCount > 0 ? _pendingPaymentsCount : null,
                  onTap: () {
                    setState(() => _selectedIndex = 9);
                    _loadPendingPaymentsCount();
                  },
                ),
                _MenuItem(
                  icon: Icons.attach_money_rounded,
                  title: 'إدارة الأسعار',
                  isSelected: _selectedIndex == 10,
                  onTap: () => setState(() => _selectedIndex = 10),
                ),
                _MenuItem(
                  icon: Icons.subscriptions_rounded,
                  title: 'إدارة الاشتراكات',
                  isSelected: _selectedIndex == 11,
                  onTap: () => setState(() => _selectedIndex = 11),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'البث المباشر',
                    style: AdminTheme.caption,
                  ),
                ),
                _MenuItem(
                  icon: Icons.video_camera_back_rounded,
                  title: 'إدارة البث المباشر',
                  isSelected: _selectedIndex == 12,
                  onTap: () => setState(() => _selectedIndex = 12),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'إدارة المستخدمين',
                    style: AdminTheme.caption,
                  ),
                ),
                _MenuItem(
                  icon: Icons.people_rounded,
                  title: 'المستخدمون والمشتركون',
                  subtitle: 'إدارة شاملة للمستخدمين',
                  isSelected: _selectedIndex == 13,
                  onTap: () => setState(() => _selectedIndex = 13),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'الإشعارات',
                    style: AdminTheme.caption,
                  ),
                ),
                _MenuItem(
                  icon: Icons.notifications_active_rounded,
                  title: 'إرسال إشعار',
                  subtitle: 'إرسال إشعارات للمستخدمين',
                  isSelected: _selectedIndex == 14,
                  onTap: () => setState(() => _selectedIndex = 14),
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(
                    'الإعدادات',
                    style: AdminTheme.caption,
                  ),
                ),
                _MenuItem(
                  icon: Icons.analytics_rounded,
                  title: 'التحليلات',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.settings_rounded,
                  title: 'الإعدادات',
                  onTap: () {},
                ),
              ],
            ),
          ),

          // Logout
          Padding(
            padding: const EdgeInsets.all(12),
            child: _MenuItem(
              icon: Icons.logout_rounded,
              title: 'تسجيل الخروج',
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }
}

// Menu Item Widget
class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badge;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.subtitle,
    this.isSelected = false,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        gradient: isSelected ? AdminTheme.gradientBlue : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(title, style: AdminTheme.bodyMedium.copyWith(color: Colors.white)),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                ),
              )
            : null,
        trailing: badge != null && badge! > 0
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
