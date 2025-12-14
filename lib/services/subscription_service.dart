import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../models/subscription_plan.dart';
import '../models/subscription.dart';
import '../models/payment_proof.dart';

/// Subscription Service
/// Handles all subscription-related operations

class SubscriptionService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get available subscription plans
  /// Filter by grade and/or specialization
  /// When specializationId is provided, returns only plans matching that specialization
  /// or plans without a specialization (general plans for the grade)
  Future<List<SubscriptionPlan>> getSubscriptionPlans({
    String? gradeId,
    String? specializationId,
  }) async {
    try {
      // Fetch all active plans first, then filter in Dart
      final response = await _supabase
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('display_order');

      var plans = (response as List);

      // Filter by grade if specified
      if (gradeId != null) {
        plans = plans.where((json) {
          final planGradeId = json['grade_id'];
          return planGradeId == null || planGradeId == gradeId;
        }).toList();
      }

      // Filter by specialization if specified
      // Show plans that match the specialization OR have no specialization (general plans)
      if (specializationId != null) {
        plans = plans.where((json) {
          final planSpecId = json['specialization_id'];
          // Include if: no specialization (general plan) OR matches the requested specialization
          return planSpecId == null || planSpecId == specializationId;
        }).toList();
      }

      return plans.map((json) => SubscriptionPlan.fromJson(json)).toList();
    } catch (e) {
      debugPrint('Error fetching subscription plans: $e');
      rethrow;
    }
  }

  /// Get current user's active subscription
  /// Includes curriculum information for proper display
  /// If curriculumId is provided, returns subscription for that specific curriculum
  Future<Subscription?> getCurrentSubscription({String? curriculumId}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      // If curriculumId is provided, get subscription for that curriculum
      if (curriculumId != null) {
        return await getSubscriptionForCurriculum(curriculumId);
      }

      // Otherwise, get the most recent active/pending subscription
      final response = await _supabase
          .from('subscriptions')
          .select('*, subscription_plans(*, curricula(id, name, name_ar, name_fr))')
          .eq('user_id', userId)
          .inFilter('status', ['active', 'pending'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return Subscription.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching current subscription: $e');
      return null;
    }
  }

  /// Get subscription for a specific curriculum
  /// Returns the active or pending subscription for the given curriculum
  Future<Subscription?> getSubscriptionForCurriculum(String curriculumId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      // First, get all subscription plans for this curriculum
      final plansResponse = await _supabase
          .from('subscription_plans')
          .select('id')
          .eq('curriculum_id', curriculumId);

      final planIds = (plansResponse as List).map((p) => p['id'] as String).toList();

      if (planIds.isEmpty) return null;

      // Then get user's subscription for any of these plans
      final response = await _supabase
          .from('subscriptions')
          .select('*, subscription_plans(*, curricula(id, name, name_ar, name_fr))')
          .eq('user_id', userId)
          .inFilter('plan_id', planIds)
          .inFilter('status', ['active', 'pending'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return Subscription.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching subscription for curriculum: $e');
      return null;
    }
  }

  /// Get all active subscriptions for the current user
  /// Returns list of all active subscriptions across all curricula
  Future<List<Subscription>> getAllActiveSubscriptions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('subscriptions')
          .select('*, subscription_plans(*, curricula(id, name, name_ar, name_fr))')
          .eq('user_id', userId)
          .inFilter('status', ['active', 'pending'])
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Subscription.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching all active subscriptions: $e');
      return [];
    }
  }

  /// Get all user's subscriptions (history)
  Future<List<Subscription>> getUserSubscriptions() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await _supabase
          .from('subscriptions')
          .select('*, subscription_plans(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Subscription.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error fetching user subscriptions: $e');
      return [];
    }
  }

  /// Create a new subscription (pending approval)
  Future<Subscription> createSubscription({
    required String planId,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Get the plan to calculate end date
      final planResponse = await _supabase
          .from('subscription_plans')
          .select()
          .eq('id', planId)
          .single();

      final plan = SubscriptionPlan.fromJson(planResponse);

      // Calculate start and end dates
      // Set start_date to beginning of today for consistency
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day); // Beginning of today (00:00:00)
      final endDate = startDate.add(Duration(days: plan.durationMonths * 30));

      // Create subscription with pending status
      final response = await _supabase.from('subscriptions').insert({
        'user_id': userId,
        'plan_id': planId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'status': 'pending',
      }).select('*, subscription_plans(*)').single();

      notifyListeners();
      return Subscription.fromJson(response);
    } catch (e) {
      debugPrint('Error creating subscription: $e');
      rethrow;
    }
  }

  /// Upload payment proof
  /// Upload image to Supabase Storage and create payment_proof record
  Future<PaymentProof> uploadPaymentProof({
    required String subscriptionId,
    required File imageFile,
    String? notes,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      // Generate unique filename (no payment_proofs prefix - bucket already named payment-proofs)
      final fileName =
          '$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // Upload image to Supabase Storage
      await _supabase.storage.from('payment-proofs').upload(
            fileName,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
            ),
          );

      // Get public URL
      final imageUrl =
          _supabase.storage.from('payment-proofs').getPublicUrl(fileName);

      // Create payment_proof record
      // Split insert and select to avoid join failures after successful insert
      final insertResponse = await _supabase.from('payment_proofs').insert({
        'subscription_id': subscriptionId,
        'user_id': userId,
        'image_url': imageUrl,
        'status': 'pending',
      }).select().single();

      // Fetch the full record with subscription details separately
      final response = await _supabase
          .from('payment_proofs')
          .select('*, subscriptions(*)')
          .eq('id', insertResponse['id'])
          .single();

      notifyListeners();
      return PaymentProof.fromJson(response);
    } catch (e) {
      debugPrint('Error uploading payment proof: $e');
      rethrow;
    }
  }

  /// Upload payment proof from picked file
  /// Helper method that handles file picking and upload
  Future<PaymentProof?> pickAndUploadPaymentProof({
    required String subscriptionId,
    String? notes,
  }) async {
    try {
      // Pick image file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);

        // Upload the file
        return await uploadPaymentProof(
          subscriptionId: subscriptionId,
          imageFile: file,
          notes: notes,
        );
      }

      return null;
    } catch (e) {
      debugPrint('Error picking and uploading payment proof: $e');
      rethrow;
    }
  }

  /// Get payment proof for a subscription
  Future<PaymentProof?> getPaymentProof(String subscriptionId) async {
    try {
      final response = await _supabase
          .from('payment_proofs')
          .select('*, subscriptions(*)')
          .eq('subscription_id', subscriptionId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return PaymentProof.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching payment proof: $e');
      return null;
    }
  }

  /// Check if user has active subscription
  /// Admin users bypass subscription checks
  Future<bool> hasActiveSubscription() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      // First check if user is admin
      final isAdmin = await _checkIfUserIsAdmin(userId);
      if (isAdmin) {
        debugPrint('[SUBSCRIPTION] User is admin - bypassing subscription check');
        return true; // Admins always have access
      }

      // For regular users: check subscription
      final subscription = await getCurrentSubscription();
      final hasActive = subscription?.isActive ?? false;
      debugPrint('[SUBSCRIPTION] Checking subscription for user: $userId');
      debugPrint('[SUBSCRIPTION] Has active subscription: $hasActive');
      return hasActive;
    } catch (e) {
      debugPrint('[SUBSCRIPTION] Error checking subscription: $e');
      return false;
    }
  }

  /// Check if user is admin
  /// Returns true if user has admin role
  Future<bool> _checkIfUserIsAdmin(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      if (response == null) return false;
      return response['role'] == 'admin';
    } catch (e) {
      debugPrint('[SUBSCRIPTION] Error checking admin role: $e');
      return false;
    }
  }

  /// Get subscription status message
  String getSubscriptionStatusMessage(Subscription? subscription,
      {String locale = 'fr'}) {
    if (subscription == null) {
      return locale == 'ar'
          ? 'لا يوجد اشتراك نشط'
          : 'Aucun abonnement actif';
    }

    if (subscription.isPending) {
      return locale == 'ar'
          ? 'الاشتراك قيد المراجعة'
          : 'Abonnement en attente d\'approbation';
    }

    if (subscription.isActive) {
      final daysRemaining = subscription.daysRemaining;
      if (locale == 'ar') {
        return 'الاشتراك نشط - $daysRemaining يوم متبقي';
      } else {
        return 'Abonnement actif - $daysRemaining jours restants';
      }
    }

    if (subscription.isExpired) {
      return locale == 'ar' ? 'الاشتراك منتهي' : 'Abonnement expiré';
    }

    return subscription.getStatusText(locale);
  }

  /// Cancel subscription
  Future<void> cancelSubscription(String subscriptionId) async {
    try {
      await _supabase.from('subscriptions').update({
        'status': 'cancelled',
      }).eq('id', subscriptionId);

      notifyListeners();
    } catch (e) {
      debugPrint('Error cancelling subscription: $e');
      rethrow;
    }
  }

  /// Renew subscription
  /// Creates a new subscription based on the same plan
  Future<Subscription> renewSubscription(String oldSubscriptionId) async {
    try {
      // Get the old subscription to get plan details
      final oldSubResponse = await _supabase
          .from('subscriptions')
          .select('plan_id')
          .eq('id', oldSubscriptionId)
          .single();

      // Create new subscription with the same plan
      return await createSubscription(
        planId: oldSubResponse['plan_id'],
      );
    } catch (e) {
      debugPrint('Error renewing subscription: $e');
      rethrow;
    }
  }

  /// Get all curricula with their subscription status for the current user
  /// Returns a list of CurriculumSubscriptionInfo objects
  /// This is scalable and works with any number of curricula
  Future<List<CurriculumSubscriptionInfo>> getAllCurriculaWithSubscriptions() async {
    final userId = _supabase.auth.currentUser?.id;

    try {
      // 1. Get all curricula from database (scalable - works with any number)
      final curriculaResponse = await _supabase
          .from('curricula')
          .select('id, name, name_ar, name_fr')
          .order('created_at');

      final curricula = curriculaResponse as List;

      // 2. Get all user's active/pending subscriptions
      List<dynamic> userSubscriptions = [];
      if (userId != null) {
        final subsResponse = await _supabase
            .from('subscriptions')
            .select('*, subscription_plans(*, curricula(id, name, name_ar, name_fr))')
            .eq('user_id', userId)
            .inFilter('status', ['active', 'pending'])
            .order('created_at', ascending: false);
        userSubscriptions = subsResponse as List;
      }

      // 3. Map curricula to their subscriptions
      final result = <CurriculumSubscriptionInfo>[];

      for (final curriculum in curricula) {
        final curriculumId = curriculum['id'] as String;

        // Find subscription for this curriculum
        Subscription? subscription;
        for (final sub in userSubscriptions) {
          final plan = sub['subscription_plans'];
          if (plan != null && plan['curriculum_id'] == curriculumId) {
            subscription = Subscription.fromJson(sub);
            break;
          }
        }

        result.add(CurriculumSubscriptionInfo(
          curriculumId: curriculumId,
          curriculumName: curriculum['name'] as String,
          curriculumNameAr: curriculum['name_ar'] as String?,
          curriculumNameFr: curriculum['name_fr'] as String?,
          subscription: subscription,
        ));
      }

      return result;
    } catch (e) {
      debugPrint('Error fetching curricula with subscriptions: $e');
      return [];
    }
  }
}

/// Information about a curriculum and its subscription status
class CurriculumSubscriptionInfo {
  final String curriculumId;
  final String curriculumName;
  final String? curriculumNameAr;
  final String? curriculumNameFr;
  final Subscription? subscription;

  CurriculumSubscriptionInfo({
    required this.curriculumId,
    required this.curriculumName,
    this.curriculumNameAr,
    this.curriculumNameFr,
    this.subscription,
  });

  /// Get display name based on locale
  String getDisplayName({String locale = 'ar'}) {
    if (locale == 'ar' && curriculumNameAr != null) {
      return curriculumNameAr!;
    } else if (locale == 'fr' && curriculumNameFr != null) {
      return curriculumNameFr!;
    }
    return curriculumName;
  }

  /// Check if user has active subscription for this curriculum
  bool get hasActiveSubscription => subscription?.isActive ?? false;

  /// Check if subscription is pending
  bool get hasPendingSubscription => subscription?.isPending ?? false;

  /// Check if subscription is expired
  bool get hasExpiredSubscription {
    if (subscription == null) return false;
    return subscription!.isExpired;
  }

  /// Check if user never subscribed to this curriculum
  bool get neverSubscribed => subscription == null;

  /// Get days remaining for subscription
  int get daysRemaining => subscription?.daysRemaining ?? 0;

  /// Get subscription end date
  DateTime? get endDate => subscription?.endDate;
}
