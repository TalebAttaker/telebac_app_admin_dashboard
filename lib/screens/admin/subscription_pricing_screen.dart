import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../models/subscription_plan.dart';
import '../../utils/admin_theme.dart';
import '../../widgets/admin/subscription_plan_card.dart';

/// Subscription Pricing Management Screen
/// Allows admin to manage pricing for all subscription plans
class SubscriptionPricingScreen extends StatefulWidget {
  final bool isEmbedded;

  const SubscriptionPricingScreen({
    super.key,
    this.isEmbedded = false,
  });

  @override
  State<SubscriptionPricingScreen> createState() =>
      _SubscriptionPricingScreenState();
}

class _SubscriptionPricingScreenState extends State<SubscriptionPricingScreen> {
  final _supabase = Supabase.instance.client;

  List<SubscriptionPlan> _plans = [];
  Map<String, dynamic> _editedPrices = {};
  Map<String, bool> _editedActiveStatus = {};
  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isSaving = false;
  DateTime? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      setState(() => _isLoading = true);

      final response = await _supabase
          .from('subscription_plans')
          .select('*, curricula(id, name, name_ar, name_fr)')
          .order('display_order');

      _plans = (response as List)
          .map((json) => SubscriptionPlan.fromJson(json))
          .toList();

      // Get last updated timestamp (from the most recent update)
      if (_plans.isNotEmpty) {
        _lastUpdated = _plans
            .map((p) => p.createdAt)
            .reduce((a, b) => a.isAfter(b) ? a : b);
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading plans: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحميل الخطط: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_editedPrices.isEmpty && _editedActiveStatus.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد تغييرات للحفظ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminTheme.secondaryDark,
        title: const Text('تأكيد الحفظ', style: AdminTheme.titleSmall),
        content: Text(
          'هل أنت متأكد من حفظ التغييرات على الأسعار؟\n\n'
          'عدد الخطط المعدلة: ${_editedPrices.length + _editedActiveStatus.length}',
          style: AdminTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
            ),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isSaving = true);

      // Update prices
      for (final entry in _editedPrices.entries) {
        await _supabase.from('subscription_plans').update({
          'price': entry.value,
        }).eq('id', entry.key);
      }

      // Update active status
      for (final entry in _editedActiveStatus.entries) {
        await _supabase.from('subscription_plans').update({
          'is_active': entry.value,
        }).eq('id', entry.key);
      }

      setState(() {
        _isSaving = false;
        _isEditMode = false;
        _editedPrices.clear();
        _editedActiveStatus.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حفظ التغييرات بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Reload plans
      await _loadPlans();
    } catch (e) {
      debugPrint('Error saving changes: $e');
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حفظ التغييرات: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _toggleEditMode() {
    setState(() {
      _isEditMode = !_isEditMode;
      if (!_isEditMode) {
        // Cancel changes
        _editedPrices.clear();
        _editedActiveStatus.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          widget.isEmbedded ? Colors.transparent : AdminTheme.primaryDark,
      appBar: widget.isEmbedded
          ? null
          : AppBar(
              title: const Text('إدارة أسعار الاشتراكات'),
              backgroundColor: AdminTheme.primaryDark,
            ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AdminTheme.accentBlue,
              ),
            )
          : Column(
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
                              Icons.attach_money,
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
                                  'إدارة الأسعار',
                                  style: AdminTheme.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'إجمالي ${_plans.length} خطة اشتراك',
                                  style: AdminTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Last Updated & Actions
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          if (_lastUpdated != null)
                            Expanded(
                              child: Text(
                                'آخر تحديث: ${DateFormat('dd/MM/yyyy HH:mm').format(_lastUpdated!)}',
                                style: AdminTheme.bodySmall.copyWith(
                                  color: Colors.white54,
                                ),
                              ),
                            ),
                          if (_isEditMode) ...[
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _toggleEditMode,
                              icon: const Icon(Icons.cancel),
                              label: const Text('إلغاء'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveChanges,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(_isSaving ? 'جاري الحفظ...' : 'حفظ'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                            ),
                          ] else
                            ElevatedButton.icon(
                              onPressed: _toggleEditMode,
                              icon: const Icon(Icons.edit),
                              label: const Text('تعديل الأسعار'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AdminTheme.accentBlue,
                              ),
                            ),
                        ],
                      ),

                      // Stats
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          _buildStatChip(
                            'نشط',
                            _plans.where((p) => p.isActive).length.toString(),
                            Colors.green,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            'معطل',
                            _plans.where((p) => !p.isActive).length.toString(),
                            Colors.red,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            'شهري',
                            _plans
                                .where((p) => p.durationType == 'monthly')
                                .length
                                .toString(),
                            Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          _buildStatChip(
                            'سنوي',
                            _plans
                                .where((p) => p.durationType == 'annual')
                                .length
                                .toString(),
                            Colors.purple,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const Divider(color: Colors.white10, height: 1),

                // Plans Grid
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadPlans,
                    child: GridView.builder(
                      padding: const EdgeInsets.all(24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 1.2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: _plans.length,
                      itemBuilder: (context, index) {
                        final plan = _plans[index];
                        return SubscriptionPlanCard(
                          key: ValueKey(plan.id),
                          plan: plan,
                          isEditMode: _isEditMode,
                          onUpdate: (updatedPlan) {
                            // Store edited price
                            _editedPrices[plan.id] = updatedPlan.price;
                          },
                          onToggleActive: (isActive) {
                            setState(() {
                              _editedActiveStatus[plan.id] = isActive;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: AdminTheme.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: AdminTheme.bodySmall.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
