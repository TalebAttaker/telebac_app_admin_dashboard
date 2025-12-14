import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/content_service.dart';
import 'services/video_service.dart';
import 'services/progress_service.dart';
import 'services/secure_bunny_service.dart';
import 'services/admin_service.dart';
import 'screens/admin/admin_layout.dart';
import 'screens/auth/admin_login_screen.dart';
import 'utils/app_theme.dart';

/// Admin Dashboard Application
/// Secure admin-only application with authentication
/// IMPORTANT: Requires admin role to access

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  runApp(const AdminDashboardApp());
}

class AdminDashboardApp extends StatelessWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ContentService()),
        ChangeNotifierProvider(create: (_) => VideoService()),
        ChangeNotifierProvider(create: (_) => ProgressService()),
        ChangeNotifierProvider(create: (_) => SecureBunnyService()),
        ChangeNotifierProvider(create: (_) => AdminService()),
      ],
      child: MaterialApp(
        title: 'Admin Dashboard - El-Mouein',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark, // Force dark mode for admin
        home: const AdminAuthWrapper(), // Protected with authentication
      ),
    );
  }
}

/// Authentication wrapper for admin dashboard
/// Checks if user is authenticated and has admin role
class AdminAuthWrapper extends StatefulWidget {
  const AdminAuthWrapper({super.key});

  @override
  State<AdminAuthWrapper> createState() => _AdminAuthWrapperState();
}

class _AdminAuthWrapperState extends State<AdminAuthWrapper> {
  @override
  void initState() {
    super.initState();
    // Schedule the check after the current frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAdminStatus();
    });
  }

  Future<void> _checkAdminStatus() async {
    if (!mounted) return;
    final adminService = context.read<AdminService>();
    await adminService.checkAdminAccess();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Show loading indicator while waiting for initial state
        if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
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
                    'جاري التحميل...',
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

        // Check if user is authenticated
        final session = snapshot.data?.session ?? Supabase.instance.client.auth.currentSession;

        if (session == null) {
          // Not logged in - show login screen
          return const AdminLoginScreen();
        }

        // User is logged in - check if admin
        return Consumer<AdminService>(
          builder: (context, adminService, _) {
            if (adminService.isLoading) {
              // Checking admin status
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

            if (!adminService.isAdmin) {
              // Not an admin - show error and logout button
              return Scaffold(
                backgroundColor: const Color(0xFF0F1419),
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.red.shade900.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.block_rounded,
                            size: 80,
                            color: Colors.red.shade400,
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'غير مصرح',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'هذا الحساب لا يملك صلاحيات الوصول\nإلى لوحة تحكم المشرفين',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 200,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await context.read<AuthService>().signOut();
                              adminService.clearAdminSession();
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text(
                              'تسجيل الخروج',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.shade700,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // User is admin - show dashboard
            return const AdminLayout();
          },
        );
      },
    );
  }
}
