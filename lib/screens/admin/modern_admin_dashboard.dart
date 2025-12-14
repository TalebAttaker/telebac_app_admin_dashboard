import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/admin_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'send_notification_screen.dart';
import 'notification_settings_screen.dart';
import 'curricula_management_screen.dart';

/// Modern Professional Admin Dashboard
/// Inspired by glossy dark UI design

class ModernAdminDashboard extends StatefulWidget {
  final bool isEmbedded; // If true, don't show sidebar (will be in AdminLayout)

  const ModernAdminDashboard({super.key, this.isEmbedded = false});

  @override
  State<ModernAdminDashboard> createState() => _ModernAdminDashboardState();
}

class _ModernAdminDashboardState extends State<ModernAdminDashboard> {
  final _supabase = Supabase.instance.client;
  Map<String, int> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      setState(() => _isLoading = true);

      // Load stats with proper null safety
      final gradesResponse = await _supabase.from('grades').select().count();
      final subjectsResponse = await _supabase.from('subjects').select().count();
      final lessonsResponse = await _supabase.from('lessons').select().count();
      final videosResponse = await _supabase.from('videos').select().count();
      final usersResponse = await _supabase.from('profiles').select().count();

      if (mounted) {
        setState(() {
          _stats = {
            'grades': gradesResponse.count ?? 0,
            'subjects': subjectsResponse.count ?? 0,
            'lessons': lessonsResponse.count ?? 0,
            'videos': videosResponse.count ?? 0,
            'users': usersResponse.count ?? 0,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[ADMIN DASHBOARD] Error loading stats: $e');
      if (mounted) {
        setState(() {
          _stats = {
            'grades': 0,
            'subjects': 0,
            'lessons': 0,
            'videos': 0,
            'users': 0,
          };
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If embedded, just return the main content without sidebar
    if (widget.isEmbedded) {
      return _buildMainContent();
    }

    // Standalone mode: show sidebar + content
    return Theme(
      data: AdminTheme.darkTheme,
      child: Scaffold(
        backgroundColor: AdminTheme.primaryDark,
        body: SafeArea(
          child: Row(
            children: [
              // Sidebar
              _buildSidebar(),

              // Main Content
              Expanded(
                child: _buildMainContent(),
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
                  isSelected: true,
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.library_books_rounded,
                  title: 'المناهج الدراسية',
                  onTap: _navigateToCurriculaManagement,
                ),
                _MenuItem(
                  icon: Icons.video_library_rounded,
                  title: 'دروس مرئية',
                  onTap: () => _navigateToVideoLessons(),
                ),
                _MenuItem(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'دروس مكتوبة',
                  onTap: () => _navigateToPDFLessons(),
                ),
                _MenuItem(
                  icon: Icons.school_rounded,
                  title: 'المستويات',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.book_rounded,
                  title: 'المواد',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.live_tv_rounded,
                  title: 'حصص مباشرة',
                  onTap: () {},
                ),
                _MenuItem(
                  icon: Icons.notifications_active_rounded,
                  title: 'إرسال إشعار',
                  onTap: _navigateToSendNotification,
                ),
                _MenuItem(
                  icon: Icons.tune_rounded,
                  title: 'إعدادات الإشعارات',
                  onTap: _navigateToNotificationSettings,
                ),
                const SizedBox(height: 16),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Text(
                    'الإعدادات',
                    style: AdminTheme.caption,
                  ),
                ),
                _MenuItem(
                  icon: Icons.people_rounded,
                  title: 'المستخدمون',
                  onTap: () {},
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

  Widget _buildMainContent() {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: _buildHeader(),
        ),

        // Statistics Cards
        SliverPadding(
          padding: const EdgeInsets.all(24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 20,
              crossAxisSpacing: 20,
              childAspectRatio: 1.5,
            ),
            delegate: SliverChildListDelegate([
              _StatCard(
                title: 'إجمالي المستويات',
                value: '${_stats['grades'] ?? 0}',
                icon: Icons.school_rounded,
                gradient: AdminTheme.gradientCyan,
                trend: '+12%',
                isPositive: true,
              ),
              _StatCard(
                title: 'إجمالي المواد',
                value: '${_stats['subjects'] ?? 0}',
                icon: Icons.book_rounded,
                gradient: AdminTheme.gradientBlue,
                trend: '+8%',
                isPositive: true,
              ),
              _StatCard(
                title: 'إجمالي الدروس',
                value: '${_stats['lessons'] ?? 0}',
                icon: Icons.video_library_rounded,
                gradient: AdminTheme.gradientPink,
                trend: '+23%',
                isPositive: true,
              ),
              _StatCard(
                title: 'إجمالي الطلاب',
                value: '${_stats['users'] ?? 0}',
                icon: Icons.people_rounded,
                gradient: AdminTheme.gradientPurple,
                trend: '+15%',
                isPositive: true,
              ),
            ]),
          ),
        ),

        // Activity Chart and Quick Actions
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Activity Chart
                Expanded(
                  flex: 2,
                  child: _buildActivityChart(),
                ),
                const SizedBox(width: 20),
                // Quick Actions
                Expanded(
                  child: _buildQuickActions(),
                ),
              ],
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // Recent Activity
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: _buildRecentActivity(),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مرحباً بك، المشرف',
                  style: AdminTheme.titleLarge,
                ),
                SizedBox(height: 4),
                Text(
                  'إليك نظرة عامة على نشاط المنصة اليوم',
                  style: AdminTheme.bodyMedium,
                ),
              ],
            ),
          ),
          // Search
          Container(
            width: 300,
            height: 50,
            decoration: AdminTheme.glassCard(),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'ابحث...',
                prefixIcon: const Icon(Icons.search, color: Colors.white60),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
              style: AdminTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 16),
          // Notifications
          Container(
            width: 50,
            height: 50,
            decoration: AdminTheme.glassCard(),
            child: Stack(
              children: [
                const Center(
                  child: Icon(Icons.notifications_rounded, color: Colors.white),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AdminTheme.accentRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Profile
          Container(
            width: 50,
            height: 50,
            decoration: AdminTheme.glassCard(
              gradient: AdminTheme.gradientBlue,
            ),
            child: const Icon(Icons.person, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityChart() {
    return Container(
      height: 350,
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('نشاط الطلاب', style: AdminTheme.titleSmall),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AdminTheme.accentBlue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'هذا الأسبوع',
                  style: AdminTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 500,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.white.withOpacity(0.05),
                      strokeWidth: 1,
                    );
                  },
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: AdminTheme.caption,
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد'];
                        if (value.toInt() >= 0 && value.toInt() < days.length) {
                          return Text(days[value.toInt()], style: AdminTheme.caption);
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: [
                      const FlSpot(0, 800),
                      const FlSpot(1, 1200),
                      const FlSpot(2, 950),
                      const FlSpot(3, 1400),
                      const FlSpot(4, 1100),
                      const FlSpot(5, 1600),
                      const FlSpot(6, 1800),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.4,
                    gradient: AdminTheme.gradientCyan,
                    barWidth: 4,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 6,
                          color: AdminTheme.accentCyan,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          AdminTheme.accentCyan.withOpacity(0.3),
                          AdminTheme.accentCyan.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      height: 350,
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('إجراءات سريعة', style: AdminTheme.titleSmall),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                _QuickActionButton(
                  icon: Icons.video_library_rounded,
                  title: 'رفع درس مرئي',
                  gradient: AdminTheme.gradientBlue,
                  onTap: _navigateToVideoLessons,
                ),
                const SizedBox(height: 12),
                _QuickActionButton(
                  icon: Icons.picture_as_pdf_rounded,
                  title: 'رفع درس مكتوب (PDF)',
                  gradient: AdminTheme.gradientPink,
                  onTap: _navigateToPDFLessons,
                ),
                const SizedBox(height: 12),
                _QuickActionButton(
                  icon: Icons.live_tv_rounded,
                  title: 'جدولة حصة مباشرة',
                  gradient: AdminTheme.gradientPurple,
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _QuickActionButton(
                  icon: Icons.notifications_active_rounded,
                  title: 'إرسال إشعار للمستخدمين',
                  gradient: AdminTheme.gradientGreen,
                  onTap: _navigateToSendNotification,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Container(
      decoration: AdminTheme.glassCard(),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('النشاط الأخير', style: AdminTheme.titleSmall),
              TextButton(
                onPressed: () {},
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 5,
            separatorBuilder: (_, __) => const Divider(color: Colors.white10),
            itemBuilder: (context, index) {
              return _ActivityItem(
                icon: Icons.video_library_rounded,
                title: 'تم رفع درس جديد',
                subtitle: 'الرياضيات - الصف السادس',
                time: 'منذ ساعتين',
                iconGradient: AdminTheme.gradientBlue,
              );
            },
          ),
        ],
      ),
    );
  }

  void _navigateToVideoLessons() {
    Navigator.pushNamed(context, '/admin/videos');
  }

  void _navigateToPDFLessons() {
    Navigator.pushNamed(context, '/admin/pdfs');
  }

  void _navigateToSendNotification() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SendNotificationScreen(),
      ),
    );
  }

  void _navigateToNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationSettingsScreen(),
      ),
    );
  }

  void _navigateToCurriculaManagement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CurriculaManagementScreen(),
      ),
    );
  }
}

// Stat Card Widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final String trend;
  final bool isPositive;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    required this.trend,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AdminTheme.elevatedCard(gradient: gradient),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                      color: Colors.white,
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(trend, style: AdminTheme.caption.copyWith(color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AdminTheme.titleLarge.copyWith(fontSize: 36),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: AdminTheme.bodySmall.copyWith(color: Colors.white70),
              ),
            ],
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
  final bool isSelected;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.isSelected = false,
    required this.onTap,
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
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// Quick Action Button Widget
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final Gradient gradient;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.title,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: AdminTheme.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

// Activity Item Widget
class _ActivityItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final Gradient iconGradient;

  const _ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.iconGradient,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: iconGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title, style: AdminTheme.bodyMedium.copyWith(color: Colors.white)),
      subtitle: Text(subtitle, style: AdminTheme.bodySmall),
      trailing: Text(time, style: AdminTheme.caption),
    );
  }
}
