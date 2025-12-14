import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/subscription_plan.dart';
import '../../utils/admin_theme.dart';

/// Subscription Plan Card Widget
/// Displays plan details with edit mode for admin
class SubscriptionPlanCard extends StatefulWidget {
  final SubscriptionPlan plan;
  final bool isEditMode;
  final Function(SubscriptionPlan)? onUpdate;
  final Function(bool)? onToggleActive;

  const SubscriptionPlanCard({
    super.key,
    required this.plan,
    this.isEditMode = false,
    this.onUpdate,
    this.onToggleActive,
  });

  @override
  State<SubscriptionPlanCard> createState() => _SubscriptionPlanCardState();
}

class _SubscriptionPlanCardState extends State<SubscriptionPlanCard> {
  late TextEditingController _priceController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
      text: widget.plan.price.toStringAsFixed(0),
    );
    _isActive = widget.plan.isActive;
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Color _getGradeColor() {
    // Color coding based on grade
    if (widget.plan.nameAr.contains('الرابعة')) {
      return Colors.green;
    } else if (widget.plan.nameAr.contains('الثانية')) {
      return Colors.blue;
    } else if (widget.plan.nameAr.contains('الثالثة')) {
      return Colors.purple;
    }
    return AdminTheme.accentBlue;
  }

  String _getDurationLabel() {
    return widget.plan.durationType == 'monthly' ? 'شهري' : 'سنوي';
  }

  @override
  Widget build(BuildContext context) {
    final gradeColor = _getGradeColor();

    return Container(
      decoration: AdminTheme.glassCard(borderRadius: 16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Plan Name & Status
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.plan.nameAr,
                      style: AdminTheme.titleSmall.copyWith(
                        color: gradeColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.plan.nameFr,
                      style: AdminTheme.bodySmall.copyWith(
                        color: Colors.white54,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.isEditMode)
                Switch(
                  value: _isActive,
                  onChanged: (value) {
                    setState(() => _isActive = value);
                    widget.onToggleActive?.call(value);
                  },
                  activeColor: Colors.green,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _isActive
                        ? Colors.green.withOpacity(0.2)
                        : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isActive ? Colors.green : Colors.red,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _isActive ? 'نشط' : 'معطل',
                    style: AdminTheme.bodySmall.copyWith(
                      color: _isActive ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(color: Colors.white10),
          const SizedBox(height: 16),

          // Curriculum Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.purple.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book, size: 14, color: Colors.purple),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.plan.getCurriculumName(locale: 'ar'),
                    style: AdminTheme.bodySmall.copyWith(
                      color: Colors.purple,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Duration Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: gradeColor == Colors.green
                      ? AdminTheme.gradientGreen
                      : gradeColor == Colors.blue
                          ? AdminTheme.gradientBlue
                          : AdminTheme.gradientPurple,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.plan.durationType == 'monthly'
                          ? Icons.calendar_today
                          : Icons.calendar_month,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getDurationLabel(),
                      style: AdminTheme.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.plan.durationMonths} ${widget.plan.durationMonths == 1 ? "شهر" : "أشهر"}',
                style: AdminTheme.bodyMedium,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Price Section
          Row(
            children: [
              Icon(
                Icons.attach_money_rounded,
                color: gradeColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: widget.isEditMode
                    ? TextField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: AdminTheme.titleMedium.copyWith(
                          color: gradeColor,
                        ),
                        decoration: InputDecoration(
                          suffix: Text(
                            'MRU',
                            style: AdminTheme.bodyMedium,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onChanged: (value) {
                          // Notify parent of price change
                          final newPrice = double.tryParse(value) ?? 0;
                          if (newPrice > 0) {
                            // Create updated plan (we'll handle this in parent)
                          }
                        },
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.plan.price.toStringAsFixed(0)} MRU',
                            style: AdminTheme.titleMedium.copyWith(
                              color: gradeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (widget.plan.durationMonths > 1)
                            Text(
                              '${widget.plan.monthlyPrice.toStringAsFixed(0)} MRU/شهر',
                              style: AdminTheme.bodySmall.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                        ],
                      ),
              ),
            ],
          ),

          // Display Order (for admin reference)
          if (widget.isEditMode) ...[
            const SizedBox(height: 12),
            Text(
              'ترتيب العرض: ${widget.plan.displayOrder}',
              style: AdminTheme.caption,
            ),
          ],
        ],
      ),
    );
  }

  double get currentPrice {
    return double.tryParse(_priceController.text) ?? widget.plan.price;
  }
}
