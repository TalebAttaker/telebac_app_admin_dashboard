import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';

/// Admin Guard Widget
/// Protects routes that require admin access
/// Shows loading while checking, redirects if not admin

class AdminGuard extends StatefulWidget {
  final Widget child;
  final String? redirectRoute;

  const AdminGuard({
    super.key,
    required this.child,
    this.redirectRoute,
  });

  @override
  State<AdminGuard> createState() => _AdminGuardState();
}

class _AdminGuardState extends State<AdminGuard> {
  bool _isChecking = true;
  bool _hasAccess = false;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final adminService = context.read<AdminService>();

    setState(() => _isChecking = true);

    final hasAccess = await adminService.checkAdminAccess();

    if (!mounted) return;

    setState(() {
      _hasAccess = hasAccess;
      _isChecking = false;
    });

    // Redirect if no access
    if (!hasAccess && mounted) {
      Navigator.of(context).pushReplacementNamed(
        widget.redirectRoute ?? '/home',
      );

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('غير مصرح: يجب أن تكون مشرفاً للوصول إلى هذه الصفحة'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1419),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                color: Color(0xFF3B82F6),
              ),
              const SizedBox(height: 24),
              Text(
                'جاري التحقق من الصلاحيات...',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F1419),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_rounded,
                size: 80,
                color: Colors.red.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                'غير مصرح',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ليس لديك صلاحيات الوصول لهذه الصفحة',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return widget.child;
  }
}

/// Admin Guard for specific widgets
/// Shows error widget instead of redirecting
class AdminProtectedWidget extends StatelessWidget {
  final Widget child;
  final Widget? errorWidget;

  const AdminProtectedWidget({
    super.key,
    required this.child,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AdminService>(
      builder: (context, adminService, _) {
        if (adminService.isLoading) {
          return const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF3B82F6),
            ),
          );
        }

        if (!adminService.isAdmin) {
          return errorWidget ??
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_rounded,
                      size: 60,
                      color: Colors.red.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'غير مصرح',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
        }

        return child;
      },
    );
  }
}
