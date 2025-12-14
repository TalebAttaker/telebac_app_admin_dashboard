import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:html' as html;
import '../../models/subscription.dart';
import '../../utils/admin_theme.dart';
import '../../widgets/admin/subscription_status_chip.dart';
import '../../services/device_binding_service.dart';

/// Subscriptions Management Screen
/// View and manage all subscriptions
class SubscriptionsManagementScreen extends StatefulWidget {
  final bool isEmbedded;

  const SubscriptionsManagementScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<SubscriptionsManagementScreen> createState() =>
      _SubscriptionsManagementScreenState();
}

class _SubscriptionsManagementScreenState
    extends State<SubscriptionsManagementScreen> {
  final _supabase = Supabase.instance.client;
  final _deviceBindingService = DeviceBindingService();

  List<Subscription> _subscriptions = [];
  Map<String, Map<String, dynamic>> _studentProfiles = {};
  Map<String, Map<String, dynamic>?> _userDevices = {};
  bool _isLoading = true;
  String _filterStatus = 'all';
  String _filterCurriculum = 'all';

  // Curricula list for filter
  List<Map<String, dynamic>> _curricula = [];

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCurricula();
    _loadSubscriptions();
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

  Future<void> _loadSubscriptions() async {
    try {
      setState(() => _isLoading = true);

      // Build base query with curriculum info
      var query = _supabase
          .from('subscriptions')
          .select('*, subscription_plans(*, curricula(id, name, name_ar))');

      // Apply status filter if needed
      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus) as dynamic;
      }

      // Apply ordering and pagination
      final response = await (query as dynamic)
          .order('created_at', ascending: false)
          .range(
            _currentPage * _itemsPerPage,
            (_currentPage + 1) * _itemsPerPage - 1,
          );

      var subscriptionsList = (response as List)
          .map((json) => Subscription.fromJson(json))
          .toList();

      // Apply curriculum filter in Dart (since it's a nested relation)
      if (_filterCurriculum != 'all') {
        subscriptionsList = subscriptionsList.where((sub) {
          // Check both curriculum_id and nested curricula object
          final curriculumId = sub.plan?['curriculum_id'];
          final curricula = sub.plan?['curricula'];
          final nestedCurriculumId = curricula?['id'];
          return curriculumId == _filterCurriculum || nestedCurriculumId == _filterCurriculum;
        }).toList();
      }

      _subscriptions = subscriptionsList;

      _totalCount = _subscriptions.length;

      // Load student profiles
      final userIds = _subscriptions.map((s) => s.userId).toSet().toList();
      if (userIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('id, full_name, phone')
            .inFilter('id', userIds);

        _studentProfiles = {
          for (var profile in profilesResponse as List)
            profile['id']: profile
        };

        // Load user devices
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
      debugPrint('Error loading subscriptions: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الاشتراكات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _extendSubscription(Subscription subscription) async {
    final days = await showDialog<int>(
      context: context,
      builder: (context) => _ExtendSubscriptionDialog(),
    );

    if (days == null) return;

    try {
      final newEndDate = subscription.endDate.add(Duration(days: days));

      // Call secure Edge Function to update subscription
      final response = await _supabase.functions.invoke(
        'admin-create-subscription',
        body: {
          'action': 'update',
          'subscription_id': subscription.id,
          'updates': {
            'end_date': newEndDate.toIso8601String(),
          },
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
            content: Text('تم تمديد الاشتراك لمدة $days يوم'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadSubscriptions();
    } catch (e) {
      debugPrint('Error extending subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تمديد الاشتراك: ${e.toString().replaceAll("Exception:", "").trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _cancelSubscription(Subscription subscription) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _CancelSubscriptionDialog(),
    );

    if (reason == null) return;

    try {
      // Call secure Edge Function to update subscription
      final response = await _supabase.functions.invoke(
        'admin-create-subscription',
        body: {
          'action': 'update',
          'subscription_id': subscription.id,
          'updates': {
            'status': 'cancelled',
          },
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
            content: Text('تم إلغاء الاشتراك'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      await _loadSubscriptions();
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إلغاء الاشتراك: ${e.toString().replaceAll("Exception:", "").trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _changePlan(Subscription subscription) async {
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
      builder: (context) => _ChangePlanDialog(
        currentPlanId: subscription.planId,
        plans: plans,
      ),
    );

    if (result == null) return;

    try {
      final newPlan = result['plan'] as Map<String, dynamic>;
      final adjustEndDate = result['adjustEndDate'] as bool;

      Map<String, dynamic> updateData = {
        'plan_id': newPlan['id'],
      };

      if (adjustEndDate) {
        // Calculate new end date based on the new plan duration
        final durationMonths = newPlan['duration_months'] ??
            (newPlan['duration_type'] == 'monthly' ? 1 : 12);
        final newEndDate = DateTime.now().add(Duration(days: durationMonths * 30));
        updateData['end_date'] = newEndDate.toIso8601String();
      }

      // Call secure Edge Function to update subscription
      final response = await _supabase.functions.invoke(
        'admin-create-subscription',
        body: {
          'action': 'update',
          'subscription_id': subscription.id,
          'updates': updateData,
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
            content: Text('تم تغيير الخطة إلى: ${newPlan['name_ar']}'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadSubscriptions();
    } catch (e) {
      debugPrint('Error changing plan: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تغيير الخطة: ${e.toString().replaceAll("Exception:", "").trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _activateSubscription(Subscription subscription) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondaryDark,
        title: const Text('تفعيل الاشتراك', style: AdminTheme.titleSmall),
        content: const Text(
          'هل أنت متأكد من تفعيل هذا الاشتراك؟',
          style: AdminTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('تفعيل'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Call secure Edge Function to update subscription
      final response = await _supabase.functions.invoke(
        'admin-create-subscription',
        body: {
          'action': 'update',
          'subscription_id': subscription.id,
          'updates': {
            'status': 'active',
            'approved_at': DateTime.now().toIso8601String(),
          },
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
            content: Text('تم تفعيل الاشتراك بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadSubscriptions();
    } catch (e) {
      debugPrint('Error activating subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تفعيل الاشتراك: ${e.toString().replaceAll("Exception:", "").trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteSubscription(Subscription subscription) async {
    final profile = _studentProfiles[subscription.userId];
    final studentName = profile?['full_name'] ?? 'طالب غير معروف';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondaryDark,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            const Text('حذف الاشتراك', style: AdminTheme.titleSmall),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'هل أنت متأكد من حذف اشتراك الطالب:',
              style: AdminTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              studentName,
              style: AdminTheme.titleSmall.copyWith(color: Colors.red),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'هذا الإجراء لا يمكن التراجع عنه!',
                      style: TextStyle(color: Colors.red, fontSize: 13),
                    ),
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
      // Call secure Edge Function to delete subscription
      final response = await _supabase.functions.invoke(
        'admin-create-subscription',
        body: {
          'action': 'delete',
          'subscription_id': subscription.id,
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
            content: Text('تم حذف الاشتراك بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadSubscriptions();
    } catch (e) {
      debugPrint('Error deleting subscription: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف الاشتراك: ${e.toString().replaceAll("Exception:", "").trim()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _unbindDevice(String userId, String? deviceName) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _UnbindDeviceDialog(deviceName: deviceName),
    );

    if (reason == null) return;

    try {
      final success = await _deviceBindingService.unbindDevice(
        userId: userId,
        reason: reason,
      );

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم فك ارتباط الجهاز بنجاح'),
              backgroundColor: Colors.green,
            ),
          );
        }
        await _loadSubscriptions();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('فشل فك ارتباط الجهاز - تأكد من صلاحيات المشرف'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error unbinding device: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل فك ارتباط الجهاز: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportToCSV() async {
    try {
      // Prepare CSV data
      List<List<dynamic>> rows = [
        [
          'اسم الطالب',
          'رقم الهاتف',
          'الخطة',
          'الحالة',
          'تاريخ البداية',
          'تاريخ النهاية',
          'الأيام المتبقية'
        ]
      ];

      for (var subscription in _subscriptions) {
        final profile = _studentProfiles[subscription.userId];
        final plan = subscription.plan;

        rows.add([
          profile?['full_name'] ?? 'غير معروف',
          profile?['phone'] ?? '',
          plan?['name_ar'] ?? '',
          subscription.getStatusText('ar'),
          DateFormat('dd/MM/yyyy').format(subscription.startDate),
          DateFormat('dd/MM/yyyy').format(subscription.endDate),
          subscription.daysRemaining.toString(),
        ]);
      }

      // Convert to CSV
      String csv = ListToCsvConverter().convert(rows);

      // Download file
      final bytes = csv.codeUnits;
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'subscriptions_${DateTime.now().millisecondsSinceEpoch}.csv')
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.isEmbedded ? Colors.transparent : AdminTheme.primaryDark,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('إدارة الاشتراكات'),
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
                        gradient: AdminTheme.gradientPurple,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.subscriptions,
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
                            'إدارة الاشتراكات',
                            style: AdminTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'إجمالي $_totalCount اشتراك',
                            style: AdminTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loadSubscriptions,
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

                const SizedBox(height: 16),

                // Search & Filters
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'البحث باسم الطالب أو رقم الهاتف...',
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
                          _loadSubscriptions();
                        }
                      },
                    ),
                    const SizedBox(width: 16),
                    // Status Filter
                    DropdownButton<String>(
                      value: _filterStatus,
                      dropdownColor: AdminTheme.secondaryDark,
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('الكل')),
                        DropdownMenuItem(value: 'active', child: Text('نشط')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('قيد الانتظار')),
                        DropdownMenuItem(value: 'expired', child: Text('منتهي')),
                        DropdownMenuItem(
                            value: 'cancelled', child: Text('ملغي')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _filterStatus = value;
                            _currentPage = 0;
                          });
                          _loadSubscriptions();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(color: Colors.white10, height: 1),

          // Subscriptions List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AdminTheme.accentPink,
                    ),
                  )
                : _subscriptions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.inbox,
                              size: 64,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'لا توجد اشتراكات',
                              style: AdminTheme.bodyLarge,
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadSubscriptions,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: _subscriptions.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _subscriptions.length) {
                              return _buildPagination();
                            }

                            final subscription = _subscriptions[index];
                            final profile =
                                _studentProfiles[subscription.userId];
                            final plan = subscription.plan;

                            return _buildSubscriptionCard(
                              subscription,
                              profile,
                              plan,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(
    Subscription subscription,
    Map<String, dynamic>? profile,
    Map<String, dynamic>? plan,
  ) {
    final device = _userDevices[subscription.userId];
    final filtered = _searchQuery.isNotEmpty &&
        !(profile?['full_name']
                ?.toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ??
            false) &&
        !(profile?['phone']
                ?.toString()
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ??
            false);

    if (filtered) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AdminTheme.glassCard(borderRadius: 16),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(20),
        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        leading: CircleAvatar(
          backgroundColor: subscription.isActive
              ? Colors.green.withOpacity(0.2)
              : subscription.isPending
                  ? Colors.orange.withOpacity(0.2)
                  : Colors.red.withOpacity(0.2),
          child: Icon(
            subscription.isActive
                ? Icons.check_circle
                : subscription.isPending
                    ? Icons.schedule
                    : Icons.cancel,
            color: subscription.isActive
                ? Colors.green
                : subscription.isPending
                    ? Colors.orange
                    : Colors.red,
          ),
        ),
        title: Text(
          profile?['full_name'] ?? 'طالب غير معروف',
          style: AdminTheme.titleSmall,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              plan?['name_ar'] ?? 'خطة غير معروفة',
              style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
            ),
            // Show curriculum name
            if (plan?['curricula'] != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  plan!['curricula']['name_ar'] ?? plan['curricula']['name'] ?? '',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            SubscriptionStatusChip(status: subscription.status),
          ],
        ),
        trailing: subscription.isActive
            ? SizedBox(
                width: 70,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${subscription.daysRemaining}',
                      style: AdminTheme.titleSmall.copyWith(
                        color: subscription.daysRemaining < 7
                            ? Colors.red
                            : Colors.green,
                      ),
                    ),
                    Text(
                      'يوم متبقي',
                      style: AdminTheme.caption.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              )
            : null,
        children: [
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          _buildInfoRow('رقم الهاتف', profile?['phone'] ?? 'غير متوفر'),
          _buildInfoRow(
            'تاريخ البداية',
            DateFormat('dd/MM/yyyy').format(subscription.startDate),
          ),
          _buildInfoRow(
            'تاريخ النهاية',
            DateFormat('dd/MM/yyyy').format(subscription.endDate),
          ),
          _buildInfoRow(
            'السعر',
            '${plan?['price']?.toString() ?? '0'} MRU',
          ),
          if (subscription.approvedAt != null)
            _buildInfoRow(
              'تاريخ الموافقة',
              DateFormat('dd/MM/yyyy').format(subscription.approvedAt!),
            ),
          // Device info section
          if (device != null) ...[
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
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
                  if (device['bound_at'] != null)
                    _buildInfoRow(
                      'مرتبط منذ',
                      DateFormat('dd/MM/yyyy').format(
                        DateTime.parse(device['bound_at']),
                      ),
                    ),
                  if (device['last_seen_at'] != null)
                    _buildInfoRow(
                      'آخر ظهور',
                      DateFormat('dd/MM/yyyy HH:mm').format(
                        DateTime.parse(device['last_seen_at']),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_android, color: Colors.grey.shade400, size: 16),
                  const SizedBox(width: 8),
                  Text(
                    'لم يتم ربط جهاز بعد',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          // First row of actions
          Row(
            children: [
              if (subscription.isActive) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _extendSubscription(subscription),
                    icon: const Icon(Icons.add_circle_outline, size: 18),
                    label: const Text('تمديد'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _cancelSubscription(subscription),
                    icon: const Icon(Icons.pause_circle_outline, size: 18),
                    label: const Text('إيقاف'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                    ),
                  ),
                ),
              ],
              if (subscription.isPending || subscription.status == 'cancelled' || subscription.status == 'expired') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _activateSubscription(subscription),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('تفعيل'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Second row of actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _changePlan(subscription),
                  icon: const Icon(Icons.swap_horiz, size: 18),
                  label: const Text('تغيير الخطة'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.cyan,
                    side: const BorderSide(color: Colors.cyan),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (device != null)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _unbindDevice(
                      subscription.userId,
                      device['device_model'],
                    ),
                    icon: const Icon(Icons.link_off, size: 18),
                    label: const Text('فك الارتباط'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.purple,
                      side: const BorderSide(color: Colors.purple),
                    ),
                  ),
                )
              else
                const Expanded(child: SizedBox()),
            ],
          ),
          const SizedBox(height: 8),
          // Delete button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _deleteSubscription(subscription),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('حذف الاشتراك'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
              ),
            ),
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
                    _loadSubscriptions();
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
                    _loadSubscriptions();
                  }
                : null,
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}

/// Extend Subscription Dialog
class _ExtendSubscriptionDialog extends StatefulWidget {
  @override
  State<_ExtendSubscriptionDialog> createState() =>
      _ExtendSubscriptionDialogState();
}

class _ExtendSubscriptionDialogState extends State<_ExtendSubscriptionDialog> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.secondaryDark,
      title: const Text('تمديد الاشتراك', style: AdminTheme.titleSmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'عدد الأيام للتمديد:',
            style: AdminTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  if (_days > 1) setState(() => _days--);
                },
                icon: const Icon(Icons.remove),
              ),
              Expanded(
                child: Text(
                  '$_days يوم',
                  style: AdminTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _days++);
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [7, 30, 60, 90, 365].map((days) {
              return ChoiceChip(
                label: Text('$days يوم'),
                selected: _days == days,
                onSelected: (selected) {
                  if (selected) setState(() => _days = days);
                },
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _days),
          child: const Text('تمديد'),
        ),
      ],
    );
  }
}

/// Cancel Subscription Dialog
class _CancelSubscriptionDialog extends StatefulWidget {
  @override
  State<_CancelSubscriptionDialog> createState() =>
      _CancelSubscriptionDialogState();
}

class _CancelSubscriptionDialogState extends State<_CancelSubscriptionDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.secondaryDark,
      title: const Text('إلغاء الاشتراك', style: AdminTheme.titleSmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'سبب الإلغاء (اختياري):',
            style: AdminTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: 'اكتب سبب الإلغاء...',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _reasonController.text),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('إلغاء الاشتراك'),
        ),
      ],
    );
  }
}

/// Unbind Device Dialog
class _UnbindDeviceDialog extends StatefulWidget {
  final String? deviceName;

  const _UnbindDeviceDialog({this.deviceName});

  @override
  State<_UnbindDeviceDialog> createState() => _UnbindDeviceDialogState();
}

class _UnbindDeviceDialogState extends State<_UnbindDeviceDialog> {
  final TextEditingController _reasonController = TextEditingController();

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.secondaryDark,
      title: const Text('فك ارتباط الجهاز', style: AdminTheme.titleSmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'سيتمكن المستخدم من تسجيل الدخول من جهاز جديد بعد فك الارتباط',
                    style: AdminTheme.bodySmall.copyWith(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
          if (widget.deviceName != null) ...[
            const SizedBox(height: 16),
            Text(
              'الجهاز: ${widget.deviceName}',
              style: AdminTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'سبب فك الارتباط:',
            style: AdminTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonController,
            decoration: const InputDecoration(
              hintText: 'مثال: تغيير الجهاز، فقدان الجهاز...',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_reasonController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('يرجى كتابة سبب فك الارتباط'),
                  backgroundColor: Colors.orange,
                ),
              );
              return;
            }
            Navigator.pop(context, _reasonController.text.trim());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
          ),
          child: const Text('فك الارتباط'),
        ),
      ],
    );
  }
}

/// Change Plan Dialog
class _ChangePlanDialog extends StatefulWidget {
  final String currentPlanId;
  final List<Map<String, dynamic>> plans;

  const _ChangePlanDialog({
    required this.currentPlanId,
    required this.plans,
  });

  @override
  State<_ChangePlanDialog> createState() => _ChangePlanDialogState();
}

class _ChangePlanDialogState extends State<_ChangePlanDialog> {
  String? _selectedPlanId;
  bool _adjustEndDate = true;

  @override
  void initState() {
    super.initState();
    _selectedPlanId = widget.currentPlanId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.secondaryDark,
      title: const Text('تغيير خطة الاشتراك', style: AdminTheme.titleSmall),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'اختر الخطة الجديدة:',
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
                  final isCurrentPlan = plan['id'] == widget.currentPlanId;
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
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              plan['name_ar'] ?? 'خطة غير معروفة',
                              style: AdminTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (isCurrentPlan)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'الحالية',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                        ],
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
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 8),
            CheckboxListTile(
              value: _adjustEndDate,
              onChanged: (value) {
                setState(() => _adjustEndDate = value ?? true);
              },
              title: const Text(
                'تعديل تاريخ الانتهاء',
                style: AdminTheme.bodyMedium,
              ),
              subtitle: Text(
                _adjustEndDate
                    ? 'سيتم حساب تاريخ انتهاء جديد بناءً على مدة الخطة'
                    : 'سيبقى تاريخ الانتهاء كما هو',
                style: AdminTheme.bodySmall.copyWith(color: Colors.white54),
              ),
              activeColor: AdminTheme.accentBlue,
              contentPadding: EdgeInsets.zero,
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
          onPressed: _selectedPlanId == widget.currentPlanId
              ? null
              : () {
                  final selectedPlan = widget.plans.firstWhere(
                    (p) => p['id'] == _selectedPlanId,
                  );
                  Navigator.pop(context, {
                    'plan': selectedPlan,
                    'adjustEndDate': _adjustEndDate,
                  });
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminTheme.accentBlue,
          ),
          child: const Text('تغيير الخطة'),
        ),
      ],
    );
  }
}
