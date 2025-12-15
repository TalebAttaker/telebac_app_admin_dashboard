import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure Image Service
/// Generates time-limited signed URLs for payment proof images
///
/// SECURITY FEATURES:
/// - Admin-only access (server-side verification)
/// - Signed URLs expire after 1 hour
/// - All access is logged in Edge Function
/// - Private storage bucket protection
class SecureImageService {
  final _supabase = Supabase.instance.client;

  // Cache signed URLs to avoid unnecessary API calls
  // Format: {payment_proof_id: {url: String, expiresAt: DateTime}}
  final Map<String, Map<String, dynamic>> _urlCache = {};

  /// Get secure signed URL for payment proof image
  ///
  /// [paymentProofId] - ID of the payment proof
  ///
  /// Returns a signed URL that expires in 1 hour
  ///
  /// Throws exception if:
  /// - User is not authenticated
  /// - User is not an active admin
  /// - Payment proof not found
  /// - Image generation fails
  Future<String> getSecureImageUrl(String paymentProofId) async {
    try {
      // Check cache first
      if (_isCacheValid(paymentProofId)) {
        debugPrint('[SecureImage] Using cached signed URL for: $paymentProofId');
        return _urlCache[paymentProofId]!['url'] as String;
      }

      debugPrint('[SecureImage] Generating new signed URL for: $paymentProofId');

      // Call Edge Function to generate signed URL
      final response = await _supabase.functions.invoke(
        'admin-get-payment-image',
        body: {
          'payment_proof_id': paymentProofId,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to get signed URL: ${response.status}');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Unknown error');
      }

      final result = data['data'] as Map<String, dynamic>;
      final signedUrl = result['signed_url'] as String;
      final expiresAt = DateTime.parse(result['expires_at'] as String);

      // Cache the URL
      _urlCache[paymentProofId] = {
        'url': signedUrl,
        'expiresAt': expiresAt,
      };

      debugPrint('[SecureImage] ✅ Generated signed URL (expires: $expiresAt)');

      return signedUrl;
    } catch (e) {
      debugPrint('[SecureImage] ❌ Error getting signed URL: $e');
      rethrow;
    }
  }

  /// Check if cached URL is still valid
  /// Returns true if URL exists in cache and hasn't expired
  bool _isCacheValid(String paymentProofId) {
    if (!_urlCache.containsKey(paymentProofId)) {
      return false;
    }

    final cached = _urlCache[paymentProofId]!;
    final expiresAt = cached['expiresAt'] as DateTime;

    // Add 5 minute buffer before expiry to avoid edge cases
    final bufferTime = expiresAt.subtract(const Duration(minutes: 5));
    final isValid = DateTime.now().isBefore(bufferTime);

    if (!isValid) {
      debugPrint('[SecureImage] Cache expired for: $paymentProofId');
      _urlCache.remove(paymentProofId);
    }

    return isValid;
  }

  /// Clear all cached URLs
  void clearCache() {
    _urlCache.clear();
    debugPrint('[SecureImage] Cache cleared');
  }

  /// Clear specific cached URL
  void clearCacheFor(String paymentProofId) {
    _urlCache.remove(paymentProofId);
    debugPrint('[SecureImage] Cache cleared for: $paymentProofId');
  }

  /// Get cache status for debugging
  Map<String, dynamic> getCacheStatus() {
    return {
      'total_cached': _urlCache.length,
      'cached_ids': _urlCache.keys.toList(),
    };
  }
}
