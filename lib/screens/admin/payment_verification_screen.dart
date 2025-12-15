import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/payment_proof.dart';
import '../../utils/admin_theme.dart';
import '../../widgets/admin/payment_proof_card.dart';
import '../../widgets/admin/secure_payment_image.dart';

/// Payment Verification Screen
/// Allows admin to review and approve/reject payment proofs
class PaymentVerificationScreen extends StatefulWidget {
  final bool isEmbedded;

  const PaymentVerificationScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<PaymentVerificationScreen> createState() =>
      _PaymentVerificationScreenState();
}

class _PaymentVerificationScreenState extends State<PaymentVerificationScreen>
    with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;

  late TabController _tabController;
  List<PaymentProof> _paymentProofs = [];
  Map<String, Map<String, dynamic>> _studentProfiles = {};
  Map<String, Map<String, dynamic>> _planDetails = {};
  bool _isLoading = true;
  String _currentTab = 'pending';
  String _filterCurriculum = 'all';

  // Curricula list for filter
  List<Map<String, dynamic>> _curricula = [];

  // Pagination
  int _currentPage = 0;
  final int _itemsPerPage = 20;
  int _totalCount = 0;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCurricula();
    _loadPaymentProofs();
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
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) return;

    setState(() {
      _currentPage = 0;
      switch (_tabController.index) {
        case 0:
          _currentTab = 'pending';
          break;
        case 1:
          _currentTab = 'approved';
          break;
        case 2:
          _currentTab = 'rejected';
          break;
      }
    });
    _loadPaymentProofs();
  }

  Future<void> _loadPaymentProofs() async {
    try {
      setState(() => _isLoading = true);

      // Build and execute query with curriculum info
      final response = await _supabase
          .from('payment_proofs')
          .select('*, subscriptions(*, subscription_plans(*, curricula(id, name, name_ar)))')
          .eq('status', _currentTab)
          .order('created_at', ascending: false)
          .range(
            _currentPage * _itemsPerPage,
            (_currentPage + 1) * _itemsPerPage - 1,
          );

      var proofsList = (response as List)
          .map((json) => PaymentProof.fromJson(json))
          .toList();

      // Apply curriculum filter in Dart
      if (_filterCurriculum != 'all') {
        proofsList = proofsList.where((proof) {
          final subscription = proof.subscription;
          if (subscription == null) return false;
          final plan = subscription['subscription_plans'];
          if (plan == null) return false;
          // Check both curriculum_id and nested curricula object
          final curriculumId = plan['curriculum_id'];
          final curricula = plan['curricula'];
          final nestedCurriculumId = curricula?['id'];
          return curriculumId == _filterCurriculum || nestedCurriculumId == _filterCurriculum;
        }).toList();
      }

      _paymentProofs = proofsList;

      _totalCount = _paymentProofs.length;

      // Load student profiles
      final userIds = _paymentProofs.map((p) => p.userId).toSet().toList();
      if (userIds.isNotEmpty) {
        final profilesResponse = await _supabase
            .from('profiles')
            .select('id, full_name, phone')
            .inFilter('id', userIds);

        _studentProfiles = {
          for (var profile in profilesResponse as List)
            profile['id']: profile
        };
      }

      // Extract plan details from subscription
      for (var proof in _paymentProofs) {
        if (proof.subscription != null) {
          final subscription = proof.subscription!;
          if (subscription['subscription_plans'] != null) {
            _planDetails[proof.id] = subscription['subscription_plans'];
          }
        }
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading payment proofs: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل البيانات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approvePayment(PaymentProof proof) async {
    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) throw Exception('Admin not authenticated');

      // Get subscription details
      final subscriptionResponse = await _supabase
          .from('subscriptions')
          .select('*, subscription_plans(*)')
          .eq('id', proof.subscriptionId)
          .single();

      final plan = subscriptionResponse['subscription_plans'];
      // Get duration type and convert to months
      final durationType = plan['duration_type'] as String;
      final durationMonths = durationType == 'monthly' ? 1 : 12;

      // Calculate dates
      // IMPORTANT: Set start_date to beginning of TODAY so user can access immediately
      // Not the exact approval time, which could block access if approved late in the day
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day); // Beginning of today (00:00:00)
      final endDate = startDate.add(Duration(days: durationMonths * 30));

      // Start transaction-like updates
      // 1. Update payment proof
      await _supabase.from('payment_proofs').update({
        'status': 'approved',
        'reviewed_at': now.toIso8601String(),
        'reviewed_by': adminId,
      }).eq('id', proof.id);

      // 2. Update subscription
      await _supabase.from('subscriptions').update({
        'status': 'active',
        'start_date': startDate.toIso8601String(), // Start at beginning of day
        'end_date': endDate.toIso8601String(),
        'approved_at': now.toIso8601String(), // Record actual approval time
        'approved_by': adminId,
      }).eq('id', proof.subscriptionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم قبول الدفع وتفعيل الاشتراك بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload data
      await _loadPaymentProofs();
    } catch (e) {
      debugPrint('Error approving payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل قبول الدفع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectPayment(PaymentProof proof) async {
    // Show rejection reason dialog
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => _RejectionDialog(),
    );

    if (reason == null || reason.isEmpty) return;

    try {
      final adminId = _supabase.auth.currentUser?.id;
      if (adminId == null) throw Exception('Admin not authenticated');

      final now = DateTime.now();

      // Update payment proof
      await _supabase.from('payment_proofs').update({
        'status': 'rejected',
        'reviewed_at': now.toIso8601String(),
        'reviewed_by': adminId,
        'rejection_reason': reason,
      }).eq('id', proof.id);

      // Update subscription status
      await _supabase.from('subscriptions').update({
        'status': 'rejected',
      }).eq('id', proof.subscriptionId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم رفض الدفع'),
            backgroundColor: Colors.orange,
          ),
        );
      }

      // Reload data
      await _loadPaymentProofs();
    } catch (e) {
      debugPrint('Error rejecting payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل رفض الدفع: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewImage(String paymentProofId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: SecurePaymentImage(
                paymentProofId: paymentProofId,
                fit: BoxFit.contain,
                placeholder: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
                errorWidget: const Center(
                  child: Icon(Icons.broken_image, color: Colors.white54, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 32),
                onPressed: () => Navigator.pop(context),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.isEmbedded ? Colors.transparent : AdminTheme.primaryDark,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('مراجعة الدفعات'),
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
                        gradient: AdminTheme.gradientCyan,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مراجعة إثباتات الدفع',
                            style: AdminTheme.titleMedium,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'قبول أو رفض طلبات الاشتراك',
                            style: AdminTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _loadPaymentProofs,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'تحديث',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Search Bar and Curriculum Filter
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
                                    _loadPaymentProofs();
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
                          _loadPaymentProofs();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Tabs
          Container(
            color: AdminTheme.secondaryDark,
            child: TabBar(
              controller: _tabController,
              indicatorColor: AdminTheme.accentCyan,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white54,
              tabs: const [
                Tab(
                  icon: Icon(Icons.schedule),
                  text: 'قيد الانتظار',
                ),
                Tab(
                  icon: Icon(Icons.check_circle),
                  text: 'مقبول',
                ),
                Tab(
                  icon: Icon(Icons.cancel),
                  text: 'مرفوض',
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AdminTheme.accentCyan,
                    ),
                  )
                : _paymentProofs.isEmpty
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
                            Text(
                              'لا توجد دفعات $_currentTab',
                              style: AdminTheme.bodyLarge.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPaymentProofs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(24),
                          itemCount: _paymentProofs.length + 1,
                          itemBuilder: (context, index) {
                            if (index == _paymentProofs.length) {
                              // Pagination controls
                              return _buildPagination();
                            }

                            final proof = _paymentProofs[index];
                            return PaymentProofCard(
                              paymentProof: proof,
                              studentProfile: _studentProfiles[proof.userId],
                              planDetails: _planDetails[proof.id],
                              onApprove: () => _approvePayment(proof),
                              onReject: () => _rejectPayment(proof),
                              onViewImage: () => _viewImage(proof.id),
                            );
                          },
                        ),
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
                    _loadPaymentProofs();
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
                    _loadPaymentProofs();
                  }
                : null,
            icon: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }
}

/// Rejection Reason Dialog
class _RejectionDialog extends StatefulWidget {
  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final TextEditingController _reasonController = TextEditingController();
  String? _selectedReason;

  final List<String> _commonReasons = [
    'الصورة غير واضحة',
    'معلومات الدفع غير صحيحة',
    'المبلغ المدفوع غير مطابق',
    'إثبات الدفع مزور',
    'أخرى (اكتب السبب)',
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AdminTheme.secondaryDark,
      title: const Text('سبب الرفض', style: AdminTheme.titleSmall),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'اختر سبب رفض الدفع:',
            style: AdminTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ..._commonReasons.map((reason) {
            return RadioListTile<String>(
              value: reason,
              groupValue: _selectedReason,
              onChanged: (value) {
                setState(() => _selectedReason = value);
              },
              title: Text(
                reason,
                style: AdminTheme.bodyMedium,
              ),
              activeColor: AdminTheme.accentBlue,
            );
          }),
          if (_selectedReason == 'أخرى (اكتب السبب)') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                hintText: 'اكتب سبب الرفض...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            final reason = _selectedReason == 'أخرى (اكتب السبب)'
                ? _reasonController.text
                : _selectedReason;
            if (reason != null && reason.isNotEmpty) {
              Navigator.pop(context, reason);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
          ),
          child: const Text('رفض'),
        ),
      ],
    );
  }
}
