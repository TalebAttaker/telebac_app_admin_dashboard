/// Subscription Model
/// Represents a user's subscription to a plan

class Subscription {
  final String id;
  final String userId;
  final String planId;
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'pending', 'active', 'expired', 'cancelled'
  final DateTime createdAt;
  final DateTime? approvedAt;
  final String? approvedBy;

  // Populated fields (not in database)
  Map<String, dynamic>? plan;

  Subscription({
    required this.id,
    required this.userId,
    required this.planId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.plan,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id'],
      userId: json['user_id'],
      planId: json['plan_id'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
      approvedAt: json['approved_at'] != null
          ? DateTime.parse(json['approved_at'])
          : null,
      approvedBy: json['approved_by'],
      plan: json['subscription_plans'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'plan_id': planId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'approved_at': approvedAt?.toIso8601String(),
      'approved_by': approvedBy,
    };
  }

  // Check if subscription is currently active
  bool get isActive {
    return status == 'active' &&
        DateTime.now().isBefore(endDate) &&
        DateTime.now().isAfter(startDate);
  }

  // Check if subscription is expired
  bool get isExpired {
    return status == 'expired' || DateTime.now().isAfter(endDate);
  }

  // Check if subscription is pending approval
  bool get isPending {
    return status == 'pending';
  }

  // Days remaining until expiration
  int get daysRemaining {
    if (isExpired) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }

  // Format status for display
  String getStatusText(String locale) {
    switch (status) {
      case 'pending':
        return locale == 'ar' ? 'قيد الانتظار' : 'En attente';
      case 'active':
        return locale == 'ar' ? 'نشط' : 'Actif';
      case 'expired':
        return locale == 'ar' ? 'منتهي' : 'Expiré';
      case 'cancelled':
        return locale == 'ar' ? 'ملغي' : 'Annulé';
      default:
        return status;
    }
  }
}
