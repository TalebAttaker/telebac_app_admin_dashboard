import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:html' as html;
import '../../utils/admin_theme.dart';

/// Users Management Screen
/// Comprehensive user management for admins
class UsersManagementScreen extends StatefulWidget {
  final bool isEmbedded;

  const UsersManagementScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<UsersManagementScreen> createState() => _UsersManagementScreenState();
}

class _UsersManagementScreenState extends State<UsersManagementScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _users = [];
  Map<String, Map<String, dynamic>?> _userSubscriptions = {};
  Map<String, Map<String, dynamic>?> _userDevices = {};
  bool _isLoading = true;
  String _filterType = 'all'; // all, subscribers, non_subscribers, active, inactive
  String _filterCurriculum = 'all'; // Curriculum filter

  // Curricula list for filter
  List<Map<String, dynamic>> _curricula = [];

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  int _totalCount = 0;

  // Statistics
  int _totalUsers = 0;
  int _activeSubscribers = 0;
  int _expiredSubscribers = 0;
  int _nonSubscribers = 0;

  @override
  void initState() {
    super.initState();
    _loadCurricula();
    _loadUsers();
    _loadStatistics();
  }

  Future<void> _loadCurricula() async {
    try {
      final response = await _supabase
          .from('curricula')
          .select('id, name, name_ar')
          .eq('is_active', true)
          .order('display_order');

      setState(() {
        _curricula = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading curricula: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStatistics() async {
    try {
      // Total users
      final usersCount = await _supabase
          .from('profiles')
          .select('*')
          .count();
      _totalUsers = usersCount.count ?? 0;

      // Active subscribers
      final activeCount = await _supabase
          .from('subscriptions')
          .select('*')
          .eq('status', 'active')
          .count();
      _activeSubscribers = activeCount.count ?? 0;

      // Expired subscribers
      final expiredCount = await _supabase
          .from('subscriptions')
          .select('*')
          .eq('status', 'expired')
          .count();
      _expiredSubscribers = expiredCount.count ?? 0;

      // Non subscribers (users without any subscription)
      _nonSubscribers = _totalUsers - _activeSubscribers - _expiredSubscribers;
      if (_nonSubscribers < 0) _nonSubscribers = 0;

      setState(() {});
    } catch (e) {
      debugPrint('Error loading statistics: $e');
    }
  }

  Future<void> _loadUsers() async {
    try {
      setState(() => _isLoading = true);

      // Build query
      var query = _supabase
          .from('profiles')
          .select('*');

      // Apply ordering and pagination
      final response = await query
          .order('created_at', ascending: false)
          .range(
            _currentPage * _itemsPerPage,
            (_currentPage + 1) * _itemsPerPage - 1,
          );

      _users = List<Map<String, dynamic>>.from(response);
      _totalCount = _users.length;

      // Load subscriptions for each user (including curriculum info)
      final userIds = _users.map((u) => u['id']).toList();
      if (userIds.isNotEmpty) {
        final subscriptionsResponse = await _supabase
            .from('subscriptions')
            .select('*, subscription_plans(*, curricula(id, name, name_ar))')
            .inFilter('user_id', userIds)
            .order('created_at', ascending: false);

        _userSubscriptions = {};
        for (var sub in subscriptionsResponse as List) {
          final userId = sub['user_id'];
          if (!_userSubscriptions.containsKey(userId)) {
            _userSubscriptions[userId] = sub;
          }
        }

        // Load devices
        final devicesResponse = await _supabase
            .from('user_devices')
            .select()
            .inFilter('user_id', userIds)
            .eq('is_active', true);

        _userDevices = {
          for (var device in devicesResponse as List)
            device['user_id']: device
        };
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading users: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل المستخدمين: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var filtered = _users;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((user) {
        final name = user['full_name']?.toString().toLowerCase() ?? '';
        final phone = user['phone']?.toString().toLowerCase() ?? '';
        final email = user['email']?.toString().toLowerCase() ?? '';
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || phone.contains(query) || email.contains(query);
      }).toList();
    }

    // Apply curriculum filter
    if (_filterCurriculum != 'all') {
      filtered = filtered.where((user) {
        final sub = _userSubscriptions[user['id']];
        if (sub == null) return false;
        final plan = sub['subscription_plans'];
        if (plan == null) return false;
        final curriculumId = plan['curriculum_id'];
        final curricula = plan['curricula'];
        final nestedCurriculumId = curricula?['id'];
        return curriculumId == _filterCurriculum || nestedCurriculumId == _filterCurriculum;
      }).toList();
    }

    // Apply type filter
    switch (_filterType) {
      case 'subscribers':
        filtered = filtered.where((user) {
          final sub = _userSubscriptions[user['id']];
          return sub != null;
        }).toList();
        break;
      case 'non_subscribers':
        filtered = filtered.where((user) {
          final sub = _userSubscriptions[user['id']];
          return sub == null;
        }).toList();
        break;
      case 'active':
        filtered = filtered.where((user) {
          final sub = _userSubscriptions[user['id']];
          return sub != null && sub['status'] == 'active';
        }).toList();
        break;
      case 'inactive':
        filtered = filtered.where((user) {
          final sub = _userSubscriptions[user['id']];
          return sub == null || sub['status'] != 'active';
        }).toList();
        break;
    }

    return filtered;
  }

  Future<void> _createSubscriptionForUser(Map<String, dynamic> user) async {
    // Load available plans
    List<Map<String, dynamic>> plans = [];
    try {
      final response = await _supabase
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('display_order');
      plans = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading plans: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الخطط: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateSubscriptionDialog(
        userName: user['full_name'] ?? 'مستخدم',
        plans: plans,
      ),
    );

    if (result == null) return;

    try {
      final plan = result['plan'] as Map<String, dynamic>;
      final durationMonths = plan['duration_months'] ??
          (plan['duration_type'] == 'monthly' ? 1 : 12);

      final startDate = DateTime.now();
      final endDate = startDate.add(Duration(days: durationMonths * 30));

      // Call secure Edge Function to create subscription
      final response = await _supabase.functions.invoke(
        'admin-create-subscription',
        body: {
          'action': 'create',
          'user_id': user['id'],
          'plan_id': plan['id'],
          'start_date': startDate.toIso8601String(),
          'end_date': endDate.toIso8601String(),
          'status': 'active',
          'approved_at': startDate.toIso8601String(),
        },
      );

      // Check response status
      if (response.status != 200 && response.status != 201) {
        final errorData = response.data;
        String errorMessage = 'حدث خطأ غير متوقع';

        if (errorData is Map<String, dynamic> && errorData.containsKey('error')) {
          errorMessage = errorData['error'] as String;
        }

        throw Exception(errorMessage);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء اشتراك للمستخدم ${user['full_name']}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadUsers();
      await _loadStatistics();
    } catch (e) {
      debugPrint('Error creating subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إنشاء الاشتراك: ${e.toString().replaceAll("Exception:", "").trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondaryDark,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            const Text('حذف المستخدم', style: AdminTheme.titleSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'هل أنت متأكد من حذف هذا المستخدم؟',
              style: AdminTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AdminTheme.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'الاسم: ${user['full_name'] ?? 'غير معروف'}',
                    style: AdminTheme.bodyMedium,
                  ),
                  if (user['phone'] != null)
                    Text(
                      'الهاتف: ${user['phone']}',
                      style: AdminTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تحذير!',
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    'سيتم حذف جميع بيانات المستخدم بما في ذلك:\n- الاشتراكات\n- سجل الدفع\n- بيانات الجهاز\n\nهذا الإجراء لا يمكن التراجع عنه!',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Call secure Edge Function to delete user and all related data
      final response = await _supabase.functions.invoke(
        'admin-manage-user',
        body: {
          'action': 'delete',
          'user_id': user['id'],
        },
      );

      // Check response status
      if (response.status != 200 && response.status != 201) {
        final errorData = response.data;
        String errorMessage = 'حدث خطأ غير متوقع';

        if (errorData is Map<String, dynamic> && errorData.containsKey('error')) {
          errorMessage = errorData['error'] as String;
        }

        throw Exception(errorMessage);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف المستخدم بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadUsers();
      await _loadStatistics();
    } catch (e) {
      debugPrint('Error deleting user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف المستخدم: ${e.toString().replaceAll("Exception:", "").trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToCSV() async {
    try {
      List<List<dynamic>> rows = [
        [
          'الاسم',
          'رقم الهاتف',
          'البريد الإلكتروني',
          'حالة الاشتراك',
          'الخطة',
          'المنهج',
          'تاريخ انتهاء الاشتراك',
          'الجهاز المرتبط',
          'تاريخ التسجيل',
        ]
      ];

      for (var user in _filteredUsers) {
        final sub = _userSubscriptions[user['id']];
        final device = _userDevices[user['id']];

        rows.add([
          user['full_name'] ?? 'غير معروف',
          user['phone'] ?? '',
          user['email'] ?? '',
          sub != null ? _getStatusText(sub['status']) : 'غير مشترك',
          sub?['subscription_plans']?['name_ar'] ?? '',
          sub?['subscription_plans']?['curricula']?['name_ar'] ?? sub?['subscription_plans']?['curricula']?['name'] ?? '',
          sub != null && sub['end_date'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(sub['end_date'])) : '',
          device?['device_model'] ?? 'غير مرتبط',
          user['created_at'] != null
              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(user['created_at']))
              : '',
        ]);
      }

      String csv = const ListToCsvConverter().convert(rows);

      final bytes = csv.codeUnits;
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'users_${DateTime.now().millisecondsSinceEpoch}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تصدير البيانات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error exporting to CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تصدير البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getStatusText(String? status) {
    switch (status) {
      case 'active':
        return 'نشط';
      case 'pending':
        return 'قيد الانتظار';
      case 'expired':
        return 'منتهي';
      case 'cancelled':
        return 'ملغي';
      default:
        return 'غير معروف';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.isEmbedded ? Colors.transparent : AdminTheme.primaryDark,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('إدارة المستخدمين'),
              backgroundColor: AdminTheme.primaryDark,
            ),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: AdminTheme.gradientBlue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.people,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'إدارة المستخدمين',
                            style: AdminTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'إجمالي $_totalUsers مستخدم',
                            style: AdminTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        _loadUsers();
                        _loadStatistics();
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'تحديث',
                    ),
                    ElevatedButton.icon(
                      onPressed: _exportToCSV,
                      icon: const Icon(Icons.download),
                      label: const Text('تصدير CSV'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Statistics
                Row(
                  children: [
                    _buildStatCard(
                      'إجمالي المستخدمين',
                      _totalUsers.toString(),
                      Icons.people,
                      AdminTheme.accentBlue,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'مشتركين نشطين',
                      _activeSubscribers.toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'اشتراكات منتهية',
                      _expiredSubscribers.toString(),
                      Icons.schedule,
                      Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    _buildStatCard(
                      'غير مشتركين',
                      _nonSubscribers.toString(),
                      Icons.person_off,
                      Colors.grey,
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Search & Filters
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'البحث بالاسم أو رقم الهاتف أو البريد...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Curriculum Filter
                    DropdownButton<String>(
                      value: _filterCurriculum,
                      dropdownColor: AdminTheme.secondaryDark,
                      hint: const Text('المنهج'),
                      items: [
                        const DropdownMenuItem(value: 'all', child: Text('كل المناهج')),
                        ..._curricula.map((c) => DropdownMenuItem(
                              value: c['id'] as String,
                              child: Text(c['name_ar'] ?? c['name'] ?? 'غير معروف'),
                            )),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _filterCurriculum = value;
                            _currentPage = 0;
                          });
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    DropdownButton<String>(
                      value: _filterType,
                      dropdownColor: AdminTheme.secondaryDark,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('الكل')),
                        DropdownMenuItem(value: 'subscribers', child: Text('المشتركين')),
                        DropdownMenuItem(value: 'non_subscribers', child: Text('غير المشتركين')),
                        DropdownMenuItem(value: 'active', child: Text('نشط')),
                        DropdownMenuItem(value: 'inactive', child: Text('غير نشط')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _filterType = value;
                            _currentPage = 0;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AdminTheme.accentPink,
                    ),
                  )
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.people_outline,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'لا يوجد مستخدمون',
                              style: AdminTheme.bodyLarge,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: _filteredUsers.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _filteredUsers.length) {
                              return _buildPagination();
                            }

                            final user = _filteredUsers[index];
                            return _buildUserCard(user);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: AdminTheme.titleSmall.copyWith(color: color),
                ),
                Text(
                  title,
                  style: AdminTheme.caption.copyWith(color: color.withOpacity(0.8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final subscription = _userSubscriptions[user['id']];
    final device = _userDevices[user['id']];
    final hasSubscription = subscription != null;
    final isActive = subscription?['status'] == 'active';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AdminTheme.glassCard(borderRadius: 16),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(20),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: CircleAvatar(
          backgroundColor: isActive
              ? Colors.green.withOpacity(0.2)
              : hasSubscription
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.2),
          child: Icon(
            isActive
                ? Icons.verified_user
                : hasSubscription
                    ? Icons.person
                    : Icons.person_outline,
            color: isActive
                ? Colors.green
                : hasSubscription
                    ? Colors.orange
                    : Colors.grey,
          ),
        ),
        title: Text(
          user['full_name'] ?? 'مستخدم غير معروف',
          style: AdminTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            if (user['phone'] != null)
              Text(
                user['phone'],
                style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(subscription?['status']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    hasSubscription
                        ? _getStatusText(subscription?['status'])
                        : 'غير مشترك',
                    style: TextStyle(
                      color: _getStatusColor(subscription?['status']),
                      fontSize: 12,
                    ),
                  ),
                ),
                if (device != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_android, size: 12, color: Colors.blue),
                        const SizedBox(width: 4),
                        const Text(
                          'مرتبط',
                          style: TextStyle(color: Colors.blue, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        children: [
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),

          // User Info
          _buildInfoRow('البريد الإلكتروني', user['email'] ?? 'غير متوفر'),
          _buildInfoRow('رقم الهاتف', user['phone'] ?? 'غير متوفر'),
          if (user['created_at'] != null)
            _buildInfoRow(
              'تاريخ التسجيل',
              DateFormat('dd/MM/yyyy').format(DateTime.parse(user['created_at'])),
            ),

          // Subscription Info
          if (hasSubscription && subscription != null) ...[
            const SizedBox(height: 8),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(subscription['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.card_membership,
                        color: _getStatusColor(subscription['status']),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'معلومات الاشتراك',
                        style: TextStyle(
                          color: _getStatusColor(subscription['status']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(
                    'الخطة',
                    (subscription['subscription_plans'] as Map<String, dynamic>?)?['name_ar'] ?? 'غير معروفة',
                  ),
                  _buildInfoRow(
                    'المنهج',
                    (subscription['subscription_plans'] as Map<String, dynamic>?)?['curricula']?['name_ar'] ??
                    (subscription['subscription_plans'] as Map<String, dynamic>?)?['curricula']?['name'] ??
                    'غير محدد',
                  ),
                  _buildInfoRow(
                    'الحالة',
                    _getStatusText(subscription['status']),
                  ),
                  if (subscription['end_date'] != null)
                    _buildInfoRow(
                      'تاريخ الانتهاء',
                      DateFormat('dd/MM/yyyy').format(
                        DateTime.parse(subscription['end_date']),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Device Info
          if (device != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone_android, color: Colors.blue.shade300, size: 16),
                      const SizedBox(width: 8),
                      const Text(
                        'الجهاز المرتبط',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow('الجهاز', device['device_model'] ?? 'غير معروف'),
                  _buildInfoRow('النظام', device['os_version'] ?? 'غير معروف'),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Actions
          Row(
            children: [
              if (!hasSubscription)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _createSubscriptionForUser(user),
                    icon: const Icon(Icons.add_card, size: 18),
                    label: const Text('إنشاء اشتراك'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              if (hasSubscription)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Navigate to subscriptions management
                    },
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('إدارة الاشتراك'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _deleteUser(user),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('حذف'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
          ),
          Expanded(
            child: Text(
              value,
              style: AdminTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    final totalPages = (_totalCount / _itemsPerPage).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: _currentPage > 0
                ? () {
                    setState(() => _currentPage--);
                    _loadUsers();
                  }
                : null,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 16),
          Text(
            'صفحة ${_currentPage + 1} من $totalPages',
            style: AdminTheme.bodyMedium,
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: _currentPage < totalPages - 1
                ? () {
                    setState(() => _currentPage++);
                    _loadUsers();
                  }
                : null,
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}

/// Create Subscription Dialog
class _CreateSubscriptionDialog extends StatefulWidget {
  final String userName;
  final List<Map<String, dynamic>> plans;

  const _CreateSubscriptionDialog({
    required this.userName,
    required this.plans,
  });

  @override
  State<_CreateSubscriptionDialog> createState() => _CreateSubscriptionDialogState();
}

class _CreateSubscriptionDialogState extends State<_CreateSubscriptionDialog> {
  String? _selectedPlanId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.secondaryDark,
      title: Text(
        'إنشاء اشتراك لـ ${widget.userName}',
        style: AdminTheme.titleSmall,
      ),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر خطة الاشتراك:',
              style: AdminTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.plans.length,
                itemBuilder: (context, index) {
                  final plan = widget.plans[index];
                  final isSelected = plan['id'] == _selectedPlanId;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AdminTheme.accentBlue.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AdminTheme.accentBlue
                            : Colors.white.withOpacity(0.1),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: RadioListTile<String>(
                      value: plan['id'],
                      groupValue: _selectedPlanId,
                      onChanged: (value) {
                        setState(() => _selectedPlanId = value);
                      },
                      title: Text(
                        plan['name_ar'] ?? 'خطة غير معروفة',
                        style: AdminTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        '${plan['price_ouguiya'] ?? plan['price'] ?? 0} MRU - ${plan['duration_type'] == 'monthly' ? 'شهري' : 'سنوي'}',
                        style: AdminTheme.bodySmall.copyWith(
                          color: Colors.white54,
                        ),
                      ),
                      activeColor: AdminTheme.accentBlue,
                    ),
                  );
                },
              ),
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
          onPressed: _selectedPlanId == null
              ? null
              : () {
                  final selectedPlan = widget.plans.firstWhere(
                    (p) => p['id'] == _selectedPlanId,
                  );
                  Navigator.pop(context, {'plan': selectedPlan});
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('إنشاء الاشتراك'),
        ),
      ],
    );
  }
}
