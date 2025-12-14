import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'connection_test_screen.dart';
import 'video_lessons_manager_screen.dart';
import 'payment_verification_screen.dart';
import 'subscription_pricing_screen.dart';
import 'subscriptions_management_screen.dart';
import 'curricula_management_screen.dart';

/// Admin Dashboard
/// Main hub for admin operations

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final _supabase = Supabase.instance.client;
  Map<String, int>? _stats;
  Map<String, dynamic>? _subscriptionStats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      setState(() => _isLoading = true);

      // Fetch statistics from database
      final gradesCount = await _supabase
          .from('grades')
          .select()
          .count();

      final subjectsCount = await _supabase
          .from('subjects')
          .select()
          .count();

      final lessonsCount = await _supabase
          .from('lessons')
          .select()
          .count();

      final videosCount = await _supabase
          .from('videos')
          .select()
          .count();

      final usersCount = await _supabase
          .from('profiles')
          .select()
          .count();

      // Load subscription statistics
      await _loadSubscriptionStats();

      setState(() {
        _stats = {
          'grades': gradesCount.count ?? 0,
          'subjects': subjectsCount.count ?? 0,
          'lessons': lessonsCount.count ?? 0,
          'videos': videosCount.count ?? 0,
          'users': usersCount.count ?? 0,
        };
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading stats: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSubscriptionStats() async {
    try {
      // Get active subscriptions count
      final activeCount = await _supabase
          .from('subscriptions')
          .select('*')
          .eq('status', 'active');

      // Get pending payments count
      final pendingPaymentsCount = await _supabase
          .from('payment_proofs')
          .select('*')
          .eq('status', 'pending');

      // Get revenue this month (approved payments)
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final approvedPaymentsThisMonth = await _supabase
          .from('payment_proofs')
          .select('*, subscriptions(*, subscription_plans(price))')
          .eq('status', 'approved')
          .gte('reviewed_at', firstDayOfMonth.toIso8601String());

      double totalRevenue = 0;
      for (var payment in approvedPaymentsThisMonth as List) {
        final subscription = payment['subscriptions'];
        if (subscription != null) {
          final plan = subscription['subscription_plans'];
          if (plan != null && plan['price'] != null) {
            totalRevenue += (plan['price'] as num).toDouble();
          }
        }
      }

      // Get subscriptions expiring in next 7 days
      final sevenDaysFromNow = now.add(const Duration(days: 7));
      final expiringCount = await _supabase
          .from('subscriptions')
          .select('*')
          .eq('status', 'active')
          .lte('end_date', sevenDaysFromNow.toIso8601String())
          .gte('end_date', now.toIso8601String());

      _subscriptionStats = {
        'active': (activeCount as List).length,
        'pending_payments': (pendingPaymentsCount as List).length,
        'revenue_this_month': totalRevenue,
        'expiring_soon': (expiringCount as List).length,
      };
    } catch (e) {
      debugPrint('Error loading subscription stats: $e');
      _subscriptionStats = {
        'active': 0,
        'pending_payments': 0,
        'revenue_this_month': 0.0,
        'expiring_soon': 0,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم المشرف'),
        actions: [
          IconButton(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: 'Test Backend Connection',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ConnectionTestScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card
                    Card(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          children: [
                            const Icon(Icons.admin_panel_settings, size: 48),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'مرحباً بك في لوحة التحكم',
                                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'إدارة المحتوى التعليمي',
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Statistics Grid
                    Text(
                      'إحصائيات المنصة',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_stats != null) ...[
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'المستويات',
                              count: _stats!['grades'] ?? 0,
                              icon: Icons.school,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'المواد',
                              count: _stats!['subjects'] ?? 0,
                              icon: Icons.book,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'الدروس',
                              count: _stats!['lessons'] ?? 0,
                              icon: Icons.video_library,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'الفيديوهات',
                              count: _stats!['videos'] ?? 0,
                              icon: Icons.play_circle,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _StatCard(
                        title: 'المستخدمون',
                        count: _stats!['users'] ?? 0,
                        icon: Icons.people,
                        color: Colors.teal,
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Subscription Overview Section
                    if (_subscriptionStats != null) ...[
                      Text(
                        'إحصائيات الاشتراكات',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'اشتراكات نشطة',
                              count: _subscriptionStats!['active'] ?? 0,
                              icon: Icons.verified,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PaymentVerificationScreen(),
                                  ),
                                );
                              },
                              child: _StatCard(
                                title: 'دفعات معلقة',
                                count: _subscriptionStats!['pending_payments'] ?? 0,
                                icon: Icons.pending_actions,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              elevation: 2,
                              color: Colors.blue.shade700,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    const Icon(Icons.attach_money, size: 40, color: Colors.white),
                                    const SizedBox(height: 8),
                                    Text(
                                      '${(_subscriptionStats!['revenue_this_month'] ?? 0).toStringAsFixed(0)} MRU',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const Text(
                                      'إيرادات هذا الشهر',
                                      style: TextStyle(color: Colors.white70),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _StatCard(
                              title: 'تنتهي قريباً',
                              count: _subscriptionStats!['expiring_soon'] ?? 0,
                              icon: Icons.warning,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Quick Actions for Subscriptions
                      Text(
                        'إجراءات سريعة',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _QuickActionCard(
                              title: 'مراجعة الدفعات',
                              icon: Icons.receipt_long,
                              color: Colors.cyan,
                              badge: _subscriptionStats!['pending_payments'] ?? 0,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const PaymentVerificationScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              title: 'إدارة الأسعار',
                              icon: Icons.attach_money,
                              color: Colors.green,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SubscriptionPricingScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _QuickActionCard(
                              title: 'عرض الاشتراكات',
                              icon: Icons.subscriptions,
                              color: Colors.purple,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SubscriptionsManagementScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],

                    // Management Options
                    Text(
                      'إدارة المحتوى',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    _ManagementTile(
                      title: 'المناهج الدراسية',
                      subtitle: 'إدارة المناهج والبرامج التعليمية',
                      icon: Icons.library_books,
                      color: Colors.indigo,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CurriculaManagementScreen(),
                          ),
                        );
                      },
                    ),

                    _ManagementTile(
                      title: 'دروس مرئية',
                      subtitle: 'رفع وإدارة الفيديوهات التعليمية',
                      icon: Icons.video_library,
                      color: Colors.red,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const VideoLessonsManagerScreen(),
                          ),
                        );
                      },
                    ),

                    _ManagementTile(
                      title: 'المستويات الدراسية',
                      subtitle: 'إدارة المستويات التعليمية',
                      icon: Icons.school,
                      color: Colors.blue,
                      onTap: () {
                        // TODO: Navigate to grades management
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('قريباً: إدارة المستويات')),
                        );
                      },
                    ),

                    _ManagementTile(
                      title: 'المواد الدراسية',
                      subtitle: 'إضافة وتعديل المواد',
                      icon: Icons.book,
                      color: Colors.green,
                      onTap: () {
                        // TODO: Navigate to subjects management
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('قريباً: إدارة المواد')),
                        );
                      },
                    ),

                    _ManagementTile(
                      title: 'الحصص المباشرة',
                      subtitle: 'جدولة الحصص الحية',
                      icon: Icons.live_tv,
                      color: Colors.orange,
                      onTap: () {
                        // TODO: Navigate to live sessions management
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('قريباً: إدارة الحصص المباشرة')),
                        );
                      },
                    ),

                    _ManagementTile(
                      title: 'المستخدمون',
                      subtitle: 'إدارة الطلاب والمعلمين',
                      icon: Icons.people,
                      color: Colors.teal,
                      onTap: () {
                        // TODO: Navigate to users management
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('قريباً: إدارة المستخدمين')),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Statistics Card Widget
class _StatCard extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Management Tile Widget
class _ManagementTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ManagementTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}

/// Quick Action Card Widget
class _QuickActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final int? badge;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.title,
    required this.icon,
    required this.color,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        elevation: 3,
        color: color.withOpacity(0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: 36, color: color),
                  if (badge != null && badge! > 0)
                    Positioned(
                      top: -8,
                      right: -8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          badge.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
