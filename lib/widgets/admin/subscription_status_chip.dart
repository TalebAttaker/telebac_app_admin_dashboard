import 'package:flutter/material.dart';
import '../../utils/admin_theme.dart';

/// Subscription Status Chip Widget
/// Colored status badges for subscription states
class SubscriptionStatusChip extends StatelessWidget {
  final String status;
  final String locale;

  const SubscriptionStatusChip({
    super.key,
    required this.status,
    this.locale = 'ar',
  });

  Color _getStatusColor() {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      case 'cancelled':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon() {
    switch (status.toLowerCase()) {
      case 'active':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'expired':
        return Icons.event_busy;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _getStatusText() {
    if (locale == 'ar') {
      switch (status.toLowerCase()) {
        case 'active':
          return 'نشط';
        case 'pending':
          return 'قيد الانتظار';
        case 'expired':
          return 'منتهي';
        case 'cancelled':
          return 'ملغي';
        default:
          return status;
      }
    } else {
      switch (status.toLowerCase()) {
        case 'active':
          return 'Actif';
        case 'pending':
          return 'En attente';
        case 'expired':
          return 'Expiré';
        case 'cancelled':
          return 'Annulé';
        default:
          return status;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getStatusIcon(),
            size: 16,
            color: color,
          ),
          const SizedBox(width: 6),
          Text(
            _getStatusText(),
            style: AdminTheme.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
