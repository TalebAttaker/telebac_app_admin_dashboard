import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/curriculum.dart';
import '../models/grade.dart';
import '../models/subject.dart';
import '../models/topic.dart';
import '../models/lesson.dart';
import '../models/specialization.dart';

/// Content Service - Optimized with Smart Caching
/// Handles all content-related operations (grades, subjects, topics, lessons, specializations)

class ContentService extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Data lists
  List<Curriculum> _curricula = [];
  List<Grade> _grades = [];
  List<Subject> _subjects = [];
  List<Topic> _topics = [];
  List<Lesson> _lessons = [];
  List<Specialization> _specializations = [];

  bool _isLoading = false;

  // ====== Smart Caching System ======
  // Cache with TTL (Time To Live)
  static const Duration _cacheTTL = Duration(minutes: 10);

  // Cache timestamps
  DateTime? _curriculaCacheTime;
  final Map<String, DateTime> _gradesCacheTime = {};
  final Map<String, DateTime> _subjectsCacheTime = {};
  final Map<String, DateTime> _topicsCacheTime = {};
  final Map<String, DateTime> _lessonsCacheTime = {};
  final Map<String, DateTime> _specializationsCacheTime = {};

  // Cached data by key
  final Map<String, List<Grade>> _gradesCache = {};
  final Map<String, List<Subject>> _subjectsCache = {};
  final Map<String, List<Topic>> _topicsCache = {};
  final Map<String, List<Lesson>> _lessonsCache = {};
  final Map<String, List<Specialization>> _specializationsCache = {};

  // Current curriculum tracking for subscription validation
  String? _currentCurriculumId;

  // Getters
  List<Curriculum> get curricula => _curricula;
  List<Grade> get grades => _grades;
  List<Subject> get subjects => _subjects;
  List<Topic> get topics => _topics;
  List<Lesson> get lessons => _lessons;
  List<Specialization> get specializations => _specializations;
  bool get isLoading => _isLoading;

  /// Get current curriculum ID for subscription validation
  String? get currentCurriculumId => _currentCurriculumId;

  /// Set current curriculum ID
  void setCurrentCurriculum(String? curriculumId) {
    if (_currentCurriculumId != curriculumId) {
      _currentCurriculumId = curriculumId;
      debugPrint('[ContentService] Current curriculum set to: $curriculumId');
      notifyListeners(); // إخطار المستمعين بتغيير المنهج
    }
  }

  /// Check if cache is valid
  bool _isCacheValid(DateTime? cacheTime) {
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < _cacheTTL;
  }

  /// Fetch all curricula with caching
  Future<List<Curriculum>> fetchCurricula() async {
    // Return cached data if valid
    if (_isCacheValid(_curriculaCacheTime) && _curricula.isNotEmpty) {
      return _curricula;
    }

    try {
      _isLoading = true;
      // Don't notify here - wait until data is loaded

      final response = await _supabase
          .from('curricula')
          .select()
          .eq('is_active', true)
          .order('display_order');

      _curricula = (response as List)
          .map((json) => Curriculum.fromJson(json))
          .toList();

      _curriculaCacheTime = DateTime.now();
      _isLoading = false;
      notifyListeners();
      return _curricula;
    } catch (e) {
      _isLoading = false;
      debugPrint('Error fetching curricula: $e');
      rethrow;
    }
  }

  /// Fetch grades for a specific curriculum with caching
  Future<List<Grade>> fetchGradesByCurriculum(String curriculumId) async {
    final cacheKey = curriculumId;

    // Return cached data if valid
    if (_isCacheValid(_gradesCacheTime[cacheKey]) &&
        _gradesCache[cacheKey]?.isNotEmpty == true) {
      _grades = _gradesCache[cacheKey]!;
      return _grades;
    }

    try {
      _isLoading = true;
      // Don't notify here

      final response = await _supabase
          .from('grades')
          .select()
          .eq('curriculum_id', curriculumId)
          .eq('is_active', true)
          .order('display_order');

      _grades = (response as List)
          .map((json) => Grade.fromJson(json))
          .toList();

      // Cache the result
      _gradesCache[cacheKey] = _grades;
      _gradesCacheTime[cacheKey] = DateTime.now();

      _isLoading = false;
      notifyListeners();
      return _grades;
    } catch (e) {
      _isLoading = false;
      debugPrint('Error fetching grades by curriculum: $e');
      rethrow;
    }
  }

  /// Fetch all grades with caching
  Future<void> fetchGrades() async {
    const cacheKey = 'all';

    // Return cached data if valid
    if (_isCacheValid(_gradesCacheTime[cacheKey]) &&
        _gradesCache[cacheKey]?.isNotEmpty == true) {
      _grades = _gradesCache[cacheKey]!;
      return;
    }

    try {
      _isLoading = true;

      final response = await _supabase
          .from('grades')
          .select()
          .eq('is_active', true)
          .order('display_order');

      _grades = (response as List)
          .map((json) => Grade.fromJson(json))
          .toList();

      // Cache the result
      _gradesCache[cacheKey] = _grades;
      _gradesCacheTime[cacheKey] = DateTime.now();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      debugPrint('Error fetching grades: $e');
      rethrow;
    }
  }

  /// Fetch specializations for a grade with caching
  Future<List<Specialization>> fetchSpecializations(String gradeId) async {
    // Return cached data if valid
    if (_isCacheValid(_specializationsCacheTime[gradeId]) &&
        _specializationsCache[gradeId]?.isNotEmpty == true) {
      _specializations = _specializationsCache[gradeId]!;
      return _specializations;
    }

    try {
      final response = await _supabase
          .from('specializations')
          .select()
          .eq('grade_id', gradeId)
          .eq('is_active', true)
          .order('display_order');

      _specializations = (response as List)
          .map((json) => Specialization.fromJson(json))
          .toList();

      // Cache the result
      _specializationsCache[gradeId] = _specializations;
      _specializationsCacheTime[gradeId] = DateTime.now();

      notifyListeners();
      return _specializations;
    } catch (e) {
      debugPrint('Error fetching specializations: $e');
      return [];
    }
  }

  /// Check if a grade has specializations (with simple caching)
  final Map<String, bool> _hasSpecializationsCache = {};

  Future<bool> gradeHasSpecializations(String gradeId) async {
    // Check cache first
    if (_hasSpecializationsCache.containsKey(gradeId)) {
      return _hasSpecializationsCache[gradeId]!;
    }

    try {
      final response = await _supabase
          .from('specializations')
          .select('id')
          .eq('grade_id', gradeId)
          .eq('is_active', true)
          .limit(1);

      final hasSpecs = (response as List).isNotEmpty;
      _hasSpecializationsCache[gradeId] = hasSpecs;
      return hasSpecs;
    } catch (e) {
      debugPrint('Error checking specializations: $e');
      return false;
    }
  }

  /// Fetch subjects for a grade with caching
  Future<void> fetchSubjects(String gradeId, {String? specializationId}) async {
    final cacheKey = '$gradeId-${specializationId ?? 'all'}';

    // Return cached data if valid
    if (_isCacheValid(_subjectsCacheTime[cacheKey]) &&
        _subjectsCache[cacheKey]?.isNotEmpty == true) {
      _subjects = _subjectsCache[cacheKey]!;
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;

      var query = _supabase
          .from('subjects')
          .select()
          .eq('grade_id', gradeId)
          .eq('is_active', true);

      if (specializationId != null) {
        query = query.eq('specialization_id', specializationId);
      }

      final response = await query.order('display_order');

      _subjects = (response as List)
          .map((json) => Subject.fromJson(json))
          .toList();

      // Cache the result
      _subjectsCache[cacheKey] = _subjects;
      _subjectsCacheTime[cacheKey] = DateTime.now();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      debugPrint('Error fetching subjects: $e');
      rethrow;
    }
  }

  /// Fetch topics for a subject with caching
  Future<void> fetchTopics(String subjectId) async {
    // Return cached data if valid
    if (_isCacheValid(_topicsCacheTime[subjectId]) &&
        _topicsCache[subjectId]?.isNotEmpty == true) {
      _topics = _topicsCache[subjectId]!;
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;

      final response = await _supabase
          .from('topics')
          .select()
          .eq('subject_id', subjectId)
          .eq('is_active', true)
          .order('display_order', ascending: true);

      _topics = (response as List)
          .map((json) => Topic.fromJson(json))
          .toList();

      // Cache the result
      _topicsCache[subjectId] = _topics;
      _topicsCacheTime[subjectId] = DateTime.now();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      debugPrint('Error fetching topics: $e');
      rethrow;
    }
  }

  /// Fetch lessons for a topic with caching
  Future<void> fetchLessons(String topicId) async {
    // Return cached data if valid
    if (_isCacheValid(_lessonsCacheTime[topicId]) &&
        _lessonsCache[topicId]?.isNotEmpty == true) {
      _lessons = _lessonsCache[topicId]!;
      notifyListeners();
      return;
    }

    try {
      _isLoading = true;

      final response = await _supabase
          .from('lessons')
          .select('''
            *,
            videos(*)
          ''')
          .eq('topic_id', topicId)
          .eq('is_active', true)
          .order('display_order');

      _lessons = (response as List)
          .map((json) => Lesson.fromJson(json))
          .toList();

      // Cache the result
      _lessonsCache[topicId] = _lessons;
      _lessonsCacheTime[topicId] = DateTime.now();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      debugPrint('Error fetching lessons: $e');
      rethrow;
    }
  }

  /// Search content (no caching for search)
  Future<List<Lesson>> searchLessons(String query) async {
    try {
      final response = await _supabase
          .from('lessons')
          .select('*, videos(*)')
          .ilike('title', '%$query%')
          .eq('is_active', true)
          .limit(20);

      return (response as List)
          .map((json) => Lesson.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('Error searching lessons: $e');
      return [];
    }
  }

  /// Clear specializations cache
  void clearSpecializations() {
    _specializations = [];
    notifyListeners();
  }

  /// Clear all caches (useful for refresh)
  void clearAllCaches() {
    _curriculaCacheTime = null;
    _gradesCacheTime.clear();
    _subjectsCacheTime.clear();
    _topicsCacheTime.clear();
    _lessonsCacheTime.clear();
    _specializationsCacheTime.clear();
    _gradesCache.clear();
    _subjectsCache.clear();
    _topicsCache.clear();
    _lessonsCache.clear();
    _specializationsCache.clear();
    _hasSpecializationsCache.clear();
  }

  /// Prefetch data for a curriculum (for faster navigation)
  Future<void> prefetchForCurriculum(String curriculumId) async {
    // Fetch grades in background
    fetchGradesByCurriculum(curriculumId).catchError((_) {});
  }
}
