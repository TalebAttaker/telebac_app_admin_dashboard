import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/secure_image_service.dart';

/// Secure Payment Image Widget
/// Loads payment proof images using time-limited signed URLs
///
/// SECURITY:
/// - Uses SecureImageService to get admin-only signed URLs
/// - Handles errors gracefully
/// - Shows loading state while fetching signed URL
class SecurePaymentImage extends StatefulWidget {
  /// Payment proof ID to load image for
  final String paymentProofId;

  /// How to fit the image within its container
  final BoxFit fit;

  /// Widget to show while loading
  final Widget? placeholder;

  /// Widget to show on error
  final Widget? errorWidget;

  /// Width of the image (optional)
  final double? width;

  /// Height of the image (optional)
  final double? height;

  const SecurePaymentImage({
    super.key,
    required this.paymentProofId,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.width,
    this.height,
  });

  @override
  State<SecurePaymentImage> createState() => _SecurePaymentImageState();
}

class _SecurePaymentImageState extends State<SecurePaymentImage> {
  final _secureImageService = SecureImageService();

  String? _signedUrl;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  @override
  void didUpdateWidget(SecurePaymentImage oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reload if payment proof ID changed
    if (oldWidget.paymentProofId != widget.paymentProofId) {
      _loadSignedUrl();
    }
  }

  Future<void> _loadSignedUrl() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _signedUrl = null;
    });

    try {
      final url = await _secureImageService.getSecureImageUrl(
        widget.paymentProofId,
      );

      if (!mounted) return;

      setState(() {
        _signedUrl = url;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[SecurePaymentImage] Error loading image: $e');

      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_isLoading) {
      return widget.placeholder ??
          const Center(
            child: CircularProgressIndicator(),
          );
    }

    // Error state
    if (_error != null) {
      return widget.errorWidget ??
          Container(
            color: Colors.grey.shade900,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'فشل تحميل الصورة',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'خطأ: $_error',
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _loadSignedUrl,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('إعادة المحاولة'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.blue,
                    ),
                  ),
                ],
              ),
            ),
          );
    }

    // Success state - show image with signed URL
    if (_signedUrl != null) {
      return CachedNetworkImage(
        imageUrl: _signedUrl!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
        placeholder: (context, url) => widget.placeholder ??
            const Center(
              child: CircularProgressIndicator(),
            ),
        errorWidget: (context, url, error) => widget.errorWidget ??
            Container(
              color: Colors.grey.shade900,
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
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      );
    }

    // Fallback (should never reach here)
    return const SizedBox.shrink();
  }

  @override
  void dispose() {
    // Note: We don't clear cache here because it's shared across widgets
    // Cache expiry is handled by SecureImageService
    super.dispose();
  }
}
