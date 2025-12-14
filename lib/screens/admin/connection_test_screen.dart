import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Connection Test Screen
/// Verifies Supabase backend connection

class ConnectionTestScreen extends StatefulWidget {
  const ConnectionTestScreen({super.key});

  @override
  State<ConnectionTestScreen> createState() => _ConnectionTestScreenState();
}

class _ConnectionTestScreenState extends State<ConnectionTestScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _connectionStatus = 'Not tested';
  Map<String, dynamic>? _testResults;

  @override
  void initState() {
    super.initState();
    _runConnectionTest();
  }

  Future<void> _runConnectionTest() async {
    setState(() {
      _isLoading = true;
      _connectionStatus = 'Testing...';
    });

    final results = <String, dynamic>{};

    try {
      // Test 1: Check Supabase URL
      final supabaseUrl = Supabase.instance.client.supabaseUrl;
      results['Supabase URL'] = supabaseUrl;
      results['URL Valid'] = supabaseUrl.isNotEmpty;

      // Test 2: Fetch grades (public data)
      try {
        final gradesResponse = await _supabase
            .from('grades')
            .select('id, name, display_order')
            .eq('is_active', true)
            .limit(5);

        results['Grades Fetch'] = '✅ Success';
        results['Grades Count'] = gradesResponse.length;
        results['Sample Grades'] = gradesResponse;
      } catch (e) {
        results['Grades Fetch'] = '❌ Failed: $e';
      }

      // Test 3: Fetch subjects
      try {
        final subjectsResponse = await _supabase
            .from('subjects')
            .select('id, name, grade_id')
            .eq('is_active', true)
            .limit(5);

        results['Subjects Fetch'] = '✅ Success';
        results['Subjects Count'] = subjectsResponse.length;
      } catch (e) {
        results['Subjects Fetch'] = '❌ Failed: $e';
      }

      // Test 4: Check authentication state
      final user = _supabase.auth.currentUser;
      results['Auth Status'] = user != null ? '✅ Logged In' : '⚠️ Not Logged In';
      if (user != null) {
        results['User ID'] = user.id;
        results['User Email'] = user.email;
      }

      // Test 5: Fetch user profile (if authenticated)
      if (user != null) {
        try {
          final profileResponse = await _supabase
              .from('profiles')
              .select()
              .eq('id', user.id)
              .maybeSingle();

          if (profileResponse != null) {
            results['Profile Fetch'] = '✅ Success';
            results['User Role'] = profileResponse['role'];
          } else {
            results['Profile Fetch'] = '⚠️ No profile found';
          }
        } catch (e) {
          results['Profile Fetch'] = '❌ Failed: $e';
        }
      }

      setState(() {
        _connectionStatus = '✅ All Tests Completed';
        _testResults = results;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _connectionStatus = '❌ Connection Failed: $e';
        _testResults = results;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backend Connection Test'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _runConnectionTest,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Card(
                    color: _connectionStatus.startsWith('✅')
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _connectionStatus.startsWith('✅')
                                ? Icons.check_circle
                                : Icons.warning,
                            color: _connectionStatus.startsWith('✅')
                                ? Colors.green
                                : Colors.orange,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _connectionStatus,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Test Results
                  if (_testResults != null) ...[
                    Text(
                      'Test Results',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),

                    ..._testResults!.entries.map((entry) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            entry.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            _formatValue(entry.value),
                            style: TextStyle(
                              color: _getValueColor(entry.value),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],

                  const SizedBox(height: 24),

                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _runConnectionTest,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Run Test Again'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  String _formatValue(dynamic value) {
    if (value is List) {
      return 'List with ${value.length} items';
    }
    return value.toString();
  }

  Color _getValueColor(dynamic value) {
    final valueStr = value.toString();
    if (valueStr.startsWith('✅')) return Colors.green;
    if (valueStr.startsWith('❌')) return Colors.red;
    if (valueStr.startsWith('⚠️')) return Colors.orange;
    return Colors.black87;
  }
}
