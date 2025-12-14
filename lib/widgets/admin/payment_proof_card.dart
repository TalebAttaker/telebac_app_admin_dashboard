import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/payment_proof.dart';
import '../../utils/admin_theme.dart';

/// Payment Proof Card Widget
/// Displays payment proof with approve/reject actions for admin
class PaymentProofCard extends StatelessWidget {
  final PaymentProof paymentProof;
  final Map<String, dynamic>? studentProfile;
  final Map<String, dynamic>? planDetails;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onViewImage;

  const PaymentProofCard({
    super.key,
    required this.paymentProof,
    this.studentProfile,
    this.planDetails,
    this.onApprove,
    this.onReject,
    this.onViewImage,
  });

  String _formatDate(DateTime date) {
    // Format without locale to avoid initialization issues
    return DateFormat('dd/MM/yyyy HH:mm').format(date);
  }

  Color _getStatusColor() {
    switch (paymentProof.status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon() {
    switch (paymentProof.status) {
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.schedule;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AdminTheme.glassCard(borderRadius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Status
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  statusColor.withOpacity(0.2),
                  statusColor.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _getStatusIcon(),
                  color: statusColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentProfile?['full_name'] ?? 'طالب غير معروف',
                        style: AdminTheme.titleSmall,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        studentProfile?['phone'] ??
                        studentProfile?['phone_number'] ?? 'لا يوجد رقم',
                        style: AdminTheme.bodySmall.copyWith(
                          color: Colors.white54,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor, width: 1),
                    ),
                    child: Text(
                      paymentProof.getStatusText('ar'),
                      style: AdminTheme.bodySmall.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan Details
                _buildInfoRow(
                  icon: Icons.school,
                  label: 'الخطة',
                  value: planDetails?['name_ar'] ?? 'غير محدد',
                  color: AdminTheme.accentBlue,
                ),
                const SizedBox(height: 12),
                // Curriculum Name
                _buildInfoRow(
                  icon: Icons.menu_book,
                  label: 'المنهج',
                  value: planDetails?['curricula']?['name_ar'] ??
                         planDetails?['curricula']?['name'] ??
                         'غير محدد',
                  color: Colors.purple,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.calendar_today,
                  label: 'المدة',
                  value: planDetails?['duration_type'] == 'monthly'
                      ? 'شهري'
                      : 'سنوي',
                  color: AdminTheme.accentCyan,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.attach_money,
                  label: 'السعر',
                  value: '${planDetails?['price_ouguiya']?.toString() ?? planDetails?['price']?.toString() ?? '0'} MRU',
                  color: Colors.green,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  icon: Icons.access_time,
                  label: 'تاريخ التقديم',
                  value: _formatDate(paymentProof.createdAt),
                  color: Colors.grey,
                ),

                // Student Notes
                if (paymentProof.notes != null &&
                    paymentProof.notes!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.note,
                        color: Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ملاحظة الطالب:',
                              style: AdminTheme.bodySmall.copyWith(
                                color: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              paymentProof.notes!,
                              style: AdminTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],

                // Payment Proof Image
                const SizedBox(height: 16),
                const Divider(color: Colors.white10),
                const SizedBox(height: 12),
                Text(
                  'إثبات الدفع:',
                  style: AdminTheme.bodySmall.copyWith(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onViewImage,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: paymentProof.imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            errorWidget: (context, url, error) => Container(
                              color: AdminTheme.secondaryDark,
                              child: const Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.broken_image,
                                      size: 48,
                                      color: Colors.white24,
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'فشل تحميل الصورة',
                                      style: TextStyle(
                                        color: Colors.white54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Overlay with zoom icon
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                ],
                              ),
                            ),
                            child: const Align(
                              alignment: Alignment.bottomRight,
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(
                                  Icons.zoom_in,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Action Buttons (only for pending payments)
                if (paymentProof.isPending) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onReject,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.cancel, size: 18),
                          label: const Text(
                            'رفض',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: onApprove,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 8,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle, size: 18),
                          label: const Text(
                            'قبول',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // Rejection Reason (if rejected)
                if (paymentProof.isRejected &&
                    paymentProof.rejectionReason != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.red.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سبب الرفض:',
                                style: AdminTheme.bodySmall.copyWith(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                paymentProof.rejectionReason!,
                                style: AdminTheme.bodySmall.copyWith(
                                  color: Colors.red.shade200,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: AdminTheme.bodySmall.copyWith(
                    color: Colors.white54,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: AdminTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
