import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'device_binding_service.dart';

/// Authentication Service
/// Handles all user authentication operations

class AuthService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final DeviceBindingService _deviceBindingService = DeviceBindingService();

  User? get currentUser => _supabase.auth.currentUser;
  bool get isAuthenticated => currentUser != null;

  // Device binding
  DeviceBindingService get deviceBindingService => _deviceBindingService;
  bool get isDeviceBound => _deviceBindingService.isDeviceBound;

  // Realtime subscription
  RealtimeChannel? _subscriptionChannel;
  bool _hasActiveSubscription = false;
  bool _isInitializingSubscription = false;
  bool get hasActiveSubscriptionStatus => _hasActiveSubscription;

  // Subscription cache (5 minutes TTL)
  DateTime? _subscriptionCacheTime;
  bool? _cachedSubscriptionStatus;
  static const _subscriptionCacheDuration = Duration(minutes: 5);

  /// Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
        },
      );

      if (response.user != null) {
        // Create profile in database
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'email': email,
          'full_name': fullName,
          'phone': phone,
          'role': 'student',
        });
      }

      notifyListeners();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign in with email and password
  /// Returns AuthResponse on success
  /// Throws DeviceBindingException if device mismatch
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Start device initialization in parallel with sign-in for better performance
      final deviceInitFuture = _deviceBindingService.initialize();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // Wait for device initialization to complete
      await deviceInitFuture;

      // Check device binding
      final bindingResult = await _deviceBindingService.checkAndBindDevice();

      if (!bindingResult.isSuccess) {
        // Sign out the user since device doesn't match
        await _supabase.auth.signOut();
        throw DeviceBindingException(bindingResult.message ?? 'فشل التحقق من الجهاز');
      }

      // Initialize realtime subscription listener (non-blocking)
      // Using unawaited pattern - subscription init doesn't need to block sign-in completion
      initializeRealtimeSubscription();

      notifyListeners();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Sign out - Secure 100% logout
  /// Deletes JWT from localStorage, refresh tokens, and sessions from server
  Future<void> signOut() async {
    try {
      debugPrint('[AUTH] Starting secure logout process');

      // Dispose realtime subscription before signing out
      _disposeRealtimeSubscription();
      _hasActiveSubscription = false;

      // Clear subscription cache
      invalidateSubscriptionCache();

      // SECURITY: Server-side cleanup before local logout
      // This ensures refresh tokens and sessions are invalidated
      if (isAuthenticated) {
        try {
          final userId = currentUser!.id;

          // Delete all refresh tokens for this user from server
          debugPrint('[AUTH] Deleting refresh tokens from server...');
          await _supabase
              .from('auth.refresh_tokens')
              .delete()
              .eq('user_id', userId);

          // Delete all sessions for this user from server
          debugPrint('[AUTH] Deleting sessions from server...');
          await _supabase
              .from('auth.sessions')
              .delete()
              .eq('user_id', userId);

          debugPrint('[AUTH] Server-side cleanup completed');
        } catch (e) {
          debugPrint('[AUTH] Server cleanup failed (non-critical): $e');
          // Continue with logout even if server cleanup fails
        }
      }

      // SECURITY: Delete JWT from localStorage (Supabase handles this)
      debugPrint('[AUTH] Clearing localStorage...');
      await _supabase.auth.signOut();

      debugPrint('[AUTH] Logout completed successfully');
      notifyListeners();
    } catch (e) {
      debugPrint('[AUTH] Error during logout: $e');
      rethrow;
    }
  }

  /// Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  /// Get user profile
  /// Returns the profile data or null if not found
  /// Throws ProfileNotFoundException if profile doesn't exist (user deleted from DB)
  Future<Map<String, dynamic>?> getUserProfile() async {
    if (!isAuthenticated) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();

      return response;
    } on PostgrestException catch (e) {
      debugPrint('Error fetching profile: $e');
      // PGRST116: "Cannot coerce the result to a single JSON object" means 0 rows returned
      // This happens when user is deleted from database but session still exists locally
      if (e.code == 'PGRST116') {
        debugPrint('[AUTH] Profile not found - user may have been deleted from database');
        throw ProfileNotFoundException(
          'Profile not found for user ${currentUser!.id}. User may have been deleted.',
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  /// Check if current session is valid (profile exists in database)
  /// Returns true if session is valid, false if user should be signed out
  /// Automatically signs out if profile is not found
  Future<bool> validateSessionAndProfile() async {
    if (!isAuthenticated) return false;

    try {
      await getUserProfile();
      return true;
    } on ProfileNotFoundException {
      debugPrint('[AUTH] Session invalid - profile not found, signing out automatically');
      await signOut();
      return false;
    } catch (e) {
      debugPrint('[AUTH] Error validating session: $e');
      // For other errors, don't sign out - could be network issue
      return true;
    }
  }

  /// Update user profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    if (!isAuthenticated) return;

    try {
      await _supabase.from('profiles').update({
        if (fullName != null) 'full_name': fullName,
        if (phone != null) 'phone': phone,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      }).eq('id', currentUser!.id);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Check if user has active subscription
  /// Uses caching with 5-minute TTL to improve performance
  Future<bool> hasActiveSubscription({bool forceRefresh = false}) async {
    if (!isAuthenticated) {
      debugPrint('[SUBSCRIPTION] User not authenticated');
      return false;
    }

    // Check cache validity (5 minutes TTL)
    if (!forceRefresh &&
        _cachedSubscriptionStatus != null &&
        _subscriptionCacheTime != null &&
        DateTime.now().difference(_subscriptionCacheTime!) < _subscriptionCacheDuration) {
      debugPrint('[SUBSCRIPTION] Using cached status: $_cachedSubscriptionStatus');
      return _cachedSubscriptionStatus!;
    }

    try {
      final userId = currentUser!.id;
      final now = DateTime.now().toIso8601String();

      debugPrint('[SUBSCRIPTION] Checking subscription for user: $userId');
      debugPrint('[SUBSCRIPTION] Current time: $now');

      final response = await _supabase
          .from('subscriptions')
          .select('id, status, end_date, created_at')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gt('end_date', now)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      debugPrint('[SUBSCRIPTION] Query response: $response');

      final hasActive = response != null;
      debugPrint('[SUBSCRIPTION] Has active subscription: $hasActive');

      // Update cache
      _cachedSubscriptionStatus = hasActive;
      _subscriptionCacheTime = DateTime.now();

      return hasActive;
    } catch (e) {
      debugPrint('[SUBSCRIPTION] Error checking subscription: $e');
      return false;
    }
  }

  /// Check if user has active subscription for a specific curriculum
  /// Returns true only if subscription is for the specified curriculum
  Future<bool> hasActiveSubscriptionForCurriculum(String? curriculumId) async {
    if (!isAuthenticated) {
      debugPrint('[SUBSCRIPTION] User not authenticated');
      return false;
    }

    // If no curriculum specified, fall back to general check
    if (curriculumId == null || curriculumId.isEmpty) {
      debugPrint('[SUBSCRIPTION] No curriculum ID provided, using general check');
      return await hasActiveSubscription();
    }

    try {
      final userId = currentUser!.id;
      final now = DateTime.now().toIso8601String();

      debugPrint('[SUBSCRIPTION] Checking subscription for curriculum: $curriculumId');

      // Query subscriptions with plan's curriculum_id
      final response = await _supabase
          .from('subscriptions')
          .select('id, status, end_date, subscription_plans!inner(curriculum_id)')
          .eq('user_id', userId)
          .eq('status', 'active')
          .gt('end_date', now);

      if ((response as List).isEmpty) {
        debugPrint('[SUBSCRIPTION] No active subscription found');
        return false;
      }

      // Check if any subscription matches the curriculum
      for (final subscription in response) {
        final plan = subscription['subscription_plans'];
        if (plan != null && plan['curriculum_id'] == curriculumId) {
          debugPrint('[SUBSCRIPTION] Found matching subscription for curriculum');
          return true;
        }
      }

      debugPrint('[SUBSCRIPTION] No subscription matches curriculum $curriculumId');
      return false;
    } catch (e) {
      debugPrint('[SUBSCRIPTION] Error checking curriculum subscription: $e');
      return false;
    }
  }

  /// Invalidate subscription cache (call when subscription changes)
  void invalidateSubscriptionCache() {
    _cachedSubscriptionStatus = null;
    _subscriptionCacheTime = null;
    debugPrint('[SUBSCRIPTION] Cache invalidated');
  }

  /// Resend verification email
  Future<void> resendVerificationEmail() async {
    if (!isAuthenticated) throw Exception('User not authenticated');

    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: currentUser!.email!,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Convert phone number to email format
  /// +222 XX XX XX XX -> student22226135601@telebac.com
  String phoneToEmail(String phoneNumber) {
    // Remove all spaces, dashes, and special characters
    String cleaned = phoneNumber.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');

    // Ensure it starts with 222
    if (!cleaned.startsWith('222')) {
      cleaned = '222$cleaned';
    }

    // Use 'student' prefix with .com domain (Supabase accepts .com TLD)
    return 'student${cleaned.toLowerCase()}@telebac.com';
  }

  /// Register with phone number
  /// Creates a pending registration that will be completed after OTP verification
  Future<Map<String, dynamic>> registerWithPhone({
    required String fullName,
    required String phoneNumber,
    required String birthDate,
    required String wilayaId,
  }) async {
    try {
      // Convert phone to email format
      final email = phoneToEmail(phoneNumber);

      // Store registration data temporarily (will be completed after OTP)
      return {
        'email': email,
        'full_name': fullName,
        'phone': phoneNumber,
        'date_of_birth': birthDate,  // Changed from birth_date to date_of_birth
        'wilaya_id': wilayaId,
      };
    } catch (e) {
      rethrow;
    }
  }

  /// Verify OTP and create account
  /// After OTP is verified, create the Supabase Auth account
  Future<AuthResponse> verifyOTPAndCreateAccount({
    required String email,
    required String fullName,
    required String phone,
    required String birthDate,
    required String wilayaId,
    required String otp,
    required String password,
  }) async {
    try {
      // Start device initialization early for better performance
      final deviceInitFuture = _deviceBindingService.initialize();

      // Create Supabase Auth account with user's password
      // Database trigger will automatically create profile from metadata
      // signUp automatically signs in the user, no need for separate signIn
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': fullName,
          'phone': phone,
          'date_of_birth': birthDate,  // Changed from birth_date to date_of_birth
          'wilaya_id': wilayaId,
        },
      );

      // Auto-confirm email since user registered via WhatsApp OTP
      // The email is fake (@telebac.com) so we need to confirm it automatically
      if (response.user != null) {
        await _confirmEmailAfterOTP();
      }

      // Wait for device initialization to complete
      await deviceInitFuture;

      // Bind device for new account
      final bindingResult = await _deviceBindingService.checkAndBindDevice();

      if (!bindingResult.isSuccess) {
        // This shouldn't happen for new accounts, but handle it anyway
        await _supabase.auth.signOut();
        throw DeviceBindingException(bindingResult.message ?? 'فشل ربط الجهاز');
      }

      // Initialize realtime subscription listener (non-blocking)
      initializeRealtimeSubscription();

      notifyListeners();
      return response;
    } catch (e) {
      debugPrint('Error verifying OTP and creating account: $e');
      rethrow;
    }
  }

  /// Auto-confirm email after OTP verification
  /// Since users register via WhatsApp OTP (not email), their fake emails
  /// need to be confirmed automatically via Edge Function
  Future<void> _confirmEmailAfterOTP() async {
    try {
      final response = await _supabase.functions.invoke(
        'confirm-email-after-otp',
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        debugPrint('Warning: Failed to auto-confirm email: ${response.data}');
        // Don't throw - this is not critical for the registration flow
        // The user can still use the app, and we can retry later if needed
      } else {
        debugPrint('Email auto-confirmed successfully: ${response.data}');
      }
    } catch (e) {
      debugPrint('Warning: Error calling confirm-email-after-otp: $e');
      // Don't throw - this is not critical for the registration flow
    }
  }

  /// Generate secure password from OTP and phone
  String _generateSecurePassword(String otp, String phone) {
    // Combine OTP with phone for a secure password
    // User won't need to remember this
    return 'ElMouein+_${otp}_${phone.replaceAll(RegExp(r'\D'), '')}_2025';
  }

  /// Sign in with phone number
  /// Users can sign in using their phone number
  Future<AuthResponse> signInWithPhone({
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final email = phoneToEmail(phoneNumber);
      final password = _generateSecurePassword(otp, phoneNumber);

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      notifyListeners();
      return response;
    } catch (e) {
      rethrow;
    }
  }

  /// Update user profile with wilaya
  Future<void> updateProfileWithWilaya({
    required String wilayaId,
  }) async {
    if (!isAuthenticated) return;

    try {
      await _supabase.from('profiles').update({
        'wilaya_id': wilayaId,
      }).eq('id', currentUser!.id);

      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Get user's wilaya
  Future<String?> getUserWilaya() async {
    if (!isAuthenticated) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select('wilaya_id')
          .eq('id', currentUser!.id)
          .single();

      return response['wilaya_id'];
    } catch (e) {
      debugPrint('Error fetching wilaya: $e');
      return null;
    }
  }

  /// Initialize realtime subscription listener
  /// Listens for changes to the user's subscription in real-time
  Future<void> initializeRealtimeSubscription() async {
    debugPrint('[REALTIME] initializeRealtimeSubscription() called');

    if (!isAuthenticated) {
      debugPrint('[REALTIME] User not authenticated, skipping initialization');
      return;
    }

    if (_isInitializingSubscription) {
      debugPrint('[REALTIME] Already initializing, skipping duplicate call');
      return;
    }

    if (_subscriptionChannel != null) {
      debugPrint('[REALTIME] Channel already exists, skipping duplicate initialization');
      return;
    }

    try {
      _isInitializingSubscription = true;
      debugPrint('[REALTIME] Starting initialization for user ${currentUser!.id}');

      // First, check current subscription status
      _hasActiveSubscription = await hasActiveSubscription();
      debugPrint('[REALTIME] Initial subscription status: $_hasActiveSubscription');

      // Notify listeners so UI updates with the current subscription status
      notifyListeners();

      // Remove any existing channel
      _disposeRealtimeSubscription();

      // Create a new realtime channel for the subscriptions table
      _subscriptionChannel = _supabase
          .channel('subscription_changes_${currentUser!.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'subscriptions',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: currentUser!.id,
            ),
            callback: (payload) async {
              debugPrint('[REALTIME] Subscription changed: ${payload.eventType}');

              // Invalidate cache first, then re-check subscription status
              invalidateSubscriptionCache();
              final hasSubscription = await hasActiveSubscription(forceRefresh: true);

              if (_hasActiveSubscription != hasSubscription) {
                _hasActiveSubscription = hasSubscription;
                debugPrint('[REALTIME] Subscription status updated: $_hasActiveSubscription');
                notifyListeners();
              }
            },
          )
          .subscribe();

      debugPrint('[REALTIME] Subscription listener initialized successfully for user ${currentUser!.id}');
    } catch (e) {
      debugPrint('[REALTIME] Error initializing realtime subscription: $e');
    } finally {
      _isInitializingSubscription = false;
    }
  }

  /// Dispose realtime subscription listener
  /// Note: This is sync to properly work with ChangeNotifier.dispose()
  void _disposeRealtimeSubscription() {
    if (_subscriptionChannel != null) {
      _supabase.removeChannel(_subscriptionChannel!);
      _subscriptionChannel = null;
      debugPrint('Realtime subscription listener disposed');
    }
  }

  @override
  void dispose() {
    _disposeRealtimeSubscription();
    super.dispose();
  }

  /// Delete the current user's account permanently
  /// This calls the delete-account Edge Function which handles all data cleanup
  /// Returns DeleteAccountResult with success status and message
  Future<DeleteAccountResult> deleteAccount() async {
    if (!isAuthenticated) {
      return DeleteAccountResult(
        success: false,
        message: 'User not authenticated',
      );
    }

    try {
      debugPrint('[AUTH] Starting account deletion process');

      // Call the Edge Function to delete the account
      final response = await _supabase.functions.invoke(
        'delete-account',
        method: HttpMethod.post,
        body: {'confirmation': 'DELETE_MY_ACCOUNT'},
      );

      debugPrint('[AUTH] Delete account response status: ${response.status}');
      debugPrint('[AUTH] Delete account response data: ${response.data}');

      if (response.status == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        if (data['success'] == true) {
          // Clean up local state
          _disposeRealtimeSubscription();
          _hasActiveSubscription = false;
          invalidateSubscriptionCache();

          // Sign out locally (server already deleted the auth user)
          try {
            await _supabase.auth.signOut();
          } catch (e) {
            // Ignore sign out errors since user is already deleted
            debugPrint('[AUTH] Sign out after deletion (expected): $e');
          }

          notifyListeners();

          return DeleteAccountResult(
            success: true,
            message: data['message'] ?? 'Account deleted successfully',
            deletedData: data['deletedData'] != null
                ? List<String>.from(data['deletedData'])
                : null,
          );
        } else {
          return DeleteAccountResult(
            success: false,
            message: data['message'] ?? 'Unknown error occurred',
          );
        }
      } else {
        final errorMessage = response.data?['message'] ?? 'Failed to delete account';
        return DeleteAccountResult(
          success: false,
          message: errorMessage,
        );
      }
    } catch (e) {
      debugPrint('[AUTH] Error deleting account: $e');
      return DeleteAccountResult(
        success: false,
        message: 'Error: ${e.toString()}',
      );
    }
  }
}

/// Exception thrown when device binding fails
class DeviceBindingException implements Exception {
  final String message;

  DeviceBindingException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when user profile is not found in database
/// This typically happens when a user is deleted from the database
/// but their local session still exists
class ProfileNotFoundException implements Exception {
  final String message;

  ProfileNotFoundException(this.message);

  @override
  String toString() => message;
}

/// Result of account deletion operation
class DeleteAccountResult {
  final bool success;
  final String message;
  final List<String>? deletedData;

  DeleteAccountResult({
    required this.success,
    required this.message,
    this.deletedData,
  });
}
