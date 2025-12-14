import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/admin_theme.dart';

/// Grade and Subject Management Screen
/// Manage grades (الفصول) and subjects (المواد)

class GradeSubjectManagementScreen extends StatefulWidget {
  const GradeSubjectManagementScreen({super.key});

  @override
  State<GradeSubjectManagementScreen> createState() => _GradeSubjectManagementScreenState();
}

class _GradeSubjectManagementScreenState extends State<GradeSubjectManagementScreen> {
  final _supabase = Supabase.instance.client;
  int _selectedTab = 0; // 0 = Grades, 1 = Subjects

  List<Map<String, dynamic>> _grades = [];
  List<Map<String, dynamic>> _subjects = [];
  String? _selectedGradeId;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      await _loadGrades();
      if (_selectedGradeId != null) {
        await _loadSubjects(_selectedGradeId!);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGrades() async {
    final response = await _supabase
        .from('grades')
        .select()
        .order('display_order');
    setState(() => _grades = List<Map<String, dynamic>>.from(response));
  }

  Future<void> _loadSubjects(String gradeId) async {
    final response = await _supabase
        .from('subjects')
        .select()
        .eq('grade_id', gradeId)
        .order('display_order');
    setState(() => _subjects = List<Map<String, dynamic>>.from(response));
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إدارة المستويات والمواد',
                  style: AdminTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'أضف وأدر المستويات الدراسية والمواد',
                  style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),

        // Tab Selector
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: AdminTheme.glassCard(),
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: _TabButton(
                      title: 'المستويات',
                      icon: Icons.school_rounded,
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _TabButton(
                      title: 'المواد',
                      icon: Icons.book_rounded,
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // Content
        if (_selectedTab == 0)
          _buildGradesContent()
        else
          _buildSubjectsContent(),
      ],
    );
  }

  Widget _buildGradesContent() {
    if (_isLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: AdminTheme.accentCyan),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 20,
          crossAxisSpacing: 20,
          childAspectRatio: 1.3,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildGradeCard(_grades[index]),
          childCount: _grades.length,
        ),
      ),
    );
  }

  Widget _buildSubjectsContent() {
    return SliverPadding(
      padding: const EdgeInsets.all(24),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // Grade Selector
          Container(
            decoration: AdminTheme.glassCard(),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, color: AdminTheme.accentBlue),
                const SizedBox(width: 12),
                const Text('اختر الفصل:', style: AdminTheme.titleSmall),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGradeId,
                    decoration: const InputDecoration(
                      filled: true,
                      fillColor: Color(0xFF1A1F25),
                    ),
                    dropdownColor: AdminTheme.secondaryDark,
                    items: _grades.map((grade) {
                      return DropdownMenuItem<String>(
                        value: grade['id'] as String,
                        child: Text(
                          grade['name_ar'] ?? grade['name'],
                          style: AdminTheme.bodyMedium.copyWith(color: Colors.white),
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedGradeId = value);
                      if (value != null) _loadSubjects(value);
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Subjects Grid
          if (_selectedGradeId != null && _subjects.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                childAspectRatio: 1.3,
              ),
              itemCount: _subjects.length,
              itemBuilder: (context, index) => _buildSubjectCard(_subjects[index]),
            )
          else if (_selectedGradeId != null && _subjects.isEmpty)
            Container(
              height: 300,
              decoration: AdminTheme.glassCard(),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.book_outlined,
                      size: 80,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد مواد في هذا الفصل',
                      style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 300,
              decoration: AdminTheme.glassCard(),
              child: Center(
                child: Text(
                  'اختر الفصل لعرض المواد',
                  style: AdminTheme.bodyMedium.copyWith(color: Colors.white60),
                ),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _buildGradeCard(Map<String, dynamic> grade) {
    return Container(
      decoration: AdminTheme.elevatedCard(gradient: AdminTheme.gradientPurple),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.school_rounded, color: Colors.white),
          ),
          const Spacer(),
          Text(
            grade['name_ar'] ?? grade['name'],
            style: AdminTheme.titleMedium.copyWith(color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.sort,
                size: 16,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                'ترتيب: ${grade['display_order']}',
                style: AdminTheme.caption.copyWith(color: Colors.white70),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  grade['is_active'] == true ? 'نشط' : 'غير نشط',
                  style: AdminTheme.caption.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    return Container(
      decoration: AdminTheme.elevatedCard(gradient: AdminTheme.gradientBlue),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.book_rounded, color: Colors.white),
          ),
          const Spacer(),
          Text(
            subject['name_ar'] ?? subject['name'],
            style: AdminTheme.titleMedium.copyWith(color: Colors.white),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.sort,
                size: 16,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Text(
                'ترتيب: ${subject['display_order']}',
                style: AdminTheme.caption.copyWith(color: Colors.white70),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  subject['is_active'] == true ? 'نشط' : 'غير نشط',
                  style: AdminTheme.caption.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TabButton({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isSelected ? AdminTheme.gradientBlue : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              title,
              style: AdminTheme.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
