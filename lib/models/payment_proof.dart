/// Payment Proof Model
/// Represents proof of payment uploaded by user

class PaymentProof {
  final String id;
  final String subscriptionId;
  final String userId;
  final String imageUrl;
  final String? notes;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;

  // Populated fields (not in database)
  Map<String, dynamic>? subscription;

  PaymentProof({
    required this.id,
    required this.subscriptionId,
    required this.userId,
    required this.imageUrl,
    this.notes,
    required this.status,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.subscription,
  });

  factory PaymentProof.fromJson(Map<String, dynamic> json) {
    return PaymentProof(
      id: json['id'],
      subscriptionId: json['subscription_id'],
      userId: json['user_id'],
      imageUrl: json['image_url'],
      notes: json['notes'],
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      reviewedAt: json['reviewed_at'] != null
          ? DateTime.parse(json['reviewed_at'])
          : null,
      reviewedBy: json['reviewed_by'],
      rejectionReason: json['rejection_reason'],
      subscription: json['subscriptions'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscription_id': subscriptionId,
      'user_id': userId,
      'image_url': imageUrl,
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'rejection_reason': rejectionReason,
    };
  }

  // Check if payment proof is pending review
  bool get isPending => status == 'pending';

  // Check if payment proof is approved
  bool get isApproved => status == 'approved';

  // Check if payment proof is rejected
  bool get isRejected => status == 'rejected';

  // Format status for display
  String getStatusText(String locale) {
    switch (status) {
      case 'pending':
        return locale == 'ar' ? 'قيد المراجعة' : 'En révision';
      case 'approved':
        return locale == 'ar' ? 'مقبول' : 'Approuvé';
      case 'rejected':
        return locale == 'ar' ? 'مرفوض' : 'Rejeté';
      default:
        return status;
    }
  }
}
