import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Service
/// Handles admin authentication and permission checks

class AdminService extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  Map<String, dynamic>? _currentProfile;
  bool _isAdmin = false;
  bool _isLoading = false;

  bool get isAdmin => _isAdmin;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get currentProfile => _currentProfile;

  /// Check if current user is admin
  Future<bool> checkAdminAccess() async {
    try {
      _isLoading = true;
      // Don't notify immediately - wait until end to avoid setState during build

      final user = _supabase.auth.currentUser;
      if (user == null) {
        _isAdmin = false;
        _currentProfile = null;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get user profile
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      _currentProfile = response;

      // Check if user has admin role and is active
      _isAdmin = response['role'] == 'admin' &&
                 response['is_active'] == true;

      _isLoading = false;
      notifyListeners();

      return _isAdmin;
    } catch (e) {
      debugPrint('Error checking admin access: $e');
      _isAdmin = false;
      _currentProfile = null;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Verify admin access and throw exception if not admin
  Future<void> requireAdminAccess() async {
    final hasAccess = await checkAdminAccess();
    if (!hasAccess) {
      throw Exception('Unauthorized: Admin access required');
    }
  }

  /// Get admin profile info
  Future<Map<String, dynamic>?> getAdminProfile() async {
    if (_currentProfile != null) {
      return _currentProfile;
    }

    await checkAdminAccess();
    return _currentProfile;
  }

  /// Clear admin session
  void clearAdminSession() {
    _isAdmin = false;
    _currentProfile = null;
    notifyListeners();
  }

  /// Listen to auth changes
  void listenToAuthChanges() {
    _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session == null) {
        clearAdminSession();
      } else {
        checkAdminAccess();
      }
    });
  }
}
