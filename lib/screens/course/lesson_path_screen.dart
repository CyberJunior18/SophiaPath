import 'dart:math';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/course/lesson.dart' as lesson_model;
import '../../models/course/lessonContent.dart';
import '../../models/course/course_info.dart';
import '../authentication/authService.dart';
import '../../services/course/scores_repo.dart';
import '../Lessons/mcq_test_screen.dart';
import 'lesson_content_screen.dart';
import '../../widgets/sophia_path_loading_screen.dart';
import '../../services/course/user_stats_service.dart';

class _LessonNodeData {
  final int id;
  final int? learningId;
  final int? practiceId;
  final String title;
  final String category;
  final String description;
  final int pageCount;
  final String chapterName;
  final int orderIndex;

  const _LessonNodeData({
    required this.id,
    this.learningId,
    this.practiceId,
    required this.title,
    required this.category,
    required this.description,
    required this.pageCount,
    required this.chapterName,
    required this.orderIndex,
  });

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int _countPagesFromValue(dynamic value) {
    if (value is! List) return 0;

    var total = 0;
    for (final item in value.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);

      final directPageCount = _asInt(
        map['pageCount'] ?? map['pagesCount'] ?? map['numberOfPages'],
      );
      if (directPageCount > 0) {
        total += directPageCount;
        continue;
      }

      final rawPages = map['pages'];
      if (rawPages is List && rawPages.isNotEmpty) {
        total += rawPages.length;
        continue;
      }

      total += _countPagesFromValue(map['contents'] ?? map['lessons']);
    }

    return total > 0 ? total : value.length;
  }

  static Map<String, dynamic>? _firstNestedLessonMap(Map<String, dynamic> map) {
    for (final key in const ['contents', 'lessons']) {
      final value = map[key];
      if (value is List) {
        for (final item in value.whereType<Map>()) {
          return Map<String, dynamic>.from(item);
        }
      }
    }

    return null;
  }

  static String _readString(
    Map<String, dynamic> map,
    List<String> keys, {
    Map<String, dynamic>? fallbackMap,
  }) {
    for (final key in keys) {
      final value = map[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    if (fallbackMap != null) {
      for (final key in keys) {
        final value = fallbackMap[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
    }

    return '';
  }

  bool get hasLearning => learningId != null;

  bool get hasPractice => practiceId != null;

  bool get hasCombinedAction => hasLearning && hasPractice;

  int get launchLessonId => learningId ?? practiceId ?? id;

  int get scoreLessonId => practiceId ?? learningId ?? id;

  bool isCompleted(Set<int> doneLessonIds) {
    if (hasCombinedAction) {
      return doneLessonIds.contains(learningId) &&
          doneLessonIds.contains(practiceId);
    }

    return doneLessonIds.contains(id);
  }

  factory _LessonNodeData.fromMap(Map<String, dynamic> map) {
    final nestedLessonMap = _firstNestedLessonMap(map);
    final directPageCount = _asInt(
      map['pageCount'] ?? map['pagesCount'] ?? map['numberOfPages'],
    );
    final nestedPages = _countPagesFromValue(map['contents'] ?? map['lessons']);
    final rawPages = _countPagesFromValue(map['pages']);
    final id = _asInt(map['id'] ?? map['lessonId'] ?? nestedLessonMap?['id']);

    return _LessonNodeData(
      id: id,
      learningId: id,
      title: _readString(map, const [
        'title',
        'name',
        'partTitle',
      ], fallbackMap: nestedLessonMap),
      category: _readString(map, const [
        'category',
      ], fallbackMap: nestedLessonMap).toLowerCase(),
      description: _readString(map, const [
        'description',
      ], fallbackMap: nestedLessonMap),
      pageCount: directPageCount > 0
          ? directPageCount
          : nestedPages > 0
          ? nestedPages
          : rawPages,
      chapterName: _readString(map, const [
        'chapterName',
      ], fallbackMap: nestedLessonMap),
      orderIndex: _asInt(map['orderIndex'] ?? nestedLessonMap?['orderIndex']),
    );
  }

  factory _LessonNodeData.fromLesson(
    lesson_model.Section lesson, {
    required int orderIndex,
  }) {
    final firstContentTitle = lesson.contents.isNotEmpty
        ? lesson.contents.first.partTitle.trim()
        : '';
    final firstContentCategory = lesson.contents.isNotEmpty
        ? LessonContentCategoryToString[lesson.contents.first.category] ?? ''
        : '';

    return _LessonNodeData(
      id: lesson.id ?? 0,
      learningId: lesson.id ?? 0,
      title: lesson.title.trim().isNotEmpty ? lesson.title : firstContentTitle,
      category: lesson.questions.isNotEmpty
          ? 'exercise'
          : (firstContentCategory.isNotEmpty
                ? firstContentCategory
                : 'learning'),
      description: lesson.description,
      pageCount: lesson.contents.fold<int>(
        0,
        (count, content) => count + content.pages.length,
      ),
      chapterName: lesson.contents.isNotEmpty
          ? lesson.contents.first.chapterName
          : '',
      orderIndex: orderIndex,
    );
  }
}

enum _LessonAction { learning, practice }

String _normalizeGroupedLessonTitle(String title) {
  final stripped = title.trim().replaceFirst(
    RegExp(r'^(?:exercises?|practice)\s*:\s*', caseSensitive: false),
    '',
  );

  return stripped.trim().toLowerCase();
}

String _displayGroupedLessonTitle(String title) {
  final stripped = title.trim().replaceFirst(
    RegExp(r'^(?:exercises?|practice)\s*:\s*', caseSensitive: false),
    '',
  );

  return stripped.trim().isEmpty ? title.trim() : stripped.trim();
}

bool _isCheatsheetLesson(_LessonNodeData lesson) {
  return lesson.title.trim().toLowerCase().startsWith('cheatsheet:');
}

IconData _lessonCategoryIcon(String category, [String title = '']) {
  final normalized = category.trim().toLowerCase();
  final normalizedTitle = title.trim().toLowerCase();

  final isTestTitle = normalizedTitle.startsWith('chapter test');

  if (isTestTitle) {
    return Icons.emoji_events;
  }

  if (normalized == 'exercise' || normalized == 'quiz' || normalized == 'mcq') {
    return Icons.fitness_center_rounded;
  }

  if (normalized == 'assessment' ||
      normalized == 'assesment' ||
      normalized == 'test' ||
      normalized == 'exam') {
    return Icons.sports_esports_rounded;
  }

  return Icons.menu_book_rounded;
}

class LessonPathScreen extends StatefulWidget {
  final CourseInfo course;
  final int sectionId;
  final String? sectionTitle;
  final CourseInfo? originalCourse;
  final int initialLessonPageIndex;

  const LessonPathScreen({
    super.key,
    required this.course,
    required this.sectionId,
    this.sectionTitle,
    this.originalCourse,
    this.initialLessonPageIndex = 0,
  });

  @override
  State<LessonPathScreen> createState() => _LessonPathScreenState();
}

class _LessonPathScreenState extends State<LessonPathScreen> {
  List<int> courseScores = [];
  int courseIndex = 0;
  List<bool> unlocked = [];
  final AuthService _authService = AuthService();
  List<_LessonNodeData> lessons = [];
  List<List<_LessonNodeData>> lessonsByPages = [];
  final Set<int> _doneLessonIds = <int>{};
  final Map<int, double> _lessonPercent = {};
  final Map<int, Color> _lessonNodeColors = {};
  _LessonNodeData? _cheatsheetLesson;
  int _currentLessonPageIndex = 0;
  String? _firestoreCourseId;
  int _completedLessons = 0;
  bool _isLoading = true;
  bool _didInitialAutoScroll = false;
  int? _pendingAutoScrollIndex;
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _lessonNodeKeys = <GlobalKey>[];
  final UserStatsService _statsService = UserStatsService();

  void _syncLessonNodeKeys(int count) {
    if (_lessonNodeKeys.length == count) return;

    if (_lessonNodeKeys.length < count) {
      _lessonNodeKeys.addAll(
        List<GlobalKey>.generate(
          count - _lessonNodeKeys.length,
          (_) => GlobalKey(),
        ),
      );
      return;
    }

    _lessonNodeKeys.removeRange(count, _lessonNodeKeys.length);
  }

  void _scheduleAutoScrollToIndex(int? index) {
    if (index == null || index < 0 || index >= lessons.length) {
      return;
    }

    _pendingAutoScrollIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didInitialAutoScroll) return;

      final targetContext = _lessonNodeKeys[index].currentContext;
      if (targetContext == null) return;

      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.35,
      );

      _didInitialAutoScroll = true;
    });
  }

  List<int> _normalizedScores(int desiredLength) {
    if (desiredLength <= 0) return const [];

    if (courseScores.length >= desiredLength) {
      return courseScores.sublist(0, desiredLength);
    }

    return [
      ...courseScores,
      ...List.filled(desiredLength - courseScores.length, 0),
    ];
  }

  List<bool> _normalizedUnlocked(int desiredLength) {
    if (desiredLength <= 0) return const [];

    final base = unlocked.isNotEmpty
        ? unlocked
        : List<bool>.generate(
            desiredLength,
            (index) => index == 0 || index <= _completedLessons,
          );

    if (base.length >= desiredLength) {
      return base.sublist(0, desiredLength);
    }

    return [
      ...base,
      ...List<bool>.generate(
        desiredLength - base.length,
        (index) => base.length + index <= _completedLessons,
      ),
    ];
  }

  bool _isExerciseLike(_LessonNodeData lesson) {
    final normalizedCategory = lesson.category.trim().toLowerCase();
    if (normalizedCategory == 'exercise' ||
        normalizedCategory == 'quiz' ||
        normalizedCategory == 'mcq') {
      return true;
    }

    final normalizedTitle = lesson.title.trim().toLowerCase();
    return normalizedTitle.startsWith('exercise:') ||
        normalizedTitle.startsWith('exercises:') ||
        normalizedTitle.startsWith('practice:');
  }

  bool _shouldGroupLessonNodes(
    _LessonNodeData learningLesson,
    _LessonNodeData practiceLesson,
  ) {
    return !_isExerciseLike(learningLesson) &&
        _isExerciseLike(practiceLesson) &&
        _normalizeGroupedLessonTitle(learningLesson.title) ==
            _normalizeGroupedLessonTitle(practiceLesson.title);
  }

  bool _isPracticeLocked(_LessonNodeData lesson) {
    return lesson.hasCombinedAction &&
        !(_doneLessonIds.contains(lesson.learningId));
  }

  bool _isPracticeAction(_LessonNodeData lesson) {
    return lesson.hasCombinedAction || _isExerciseLike(lesson);
  }

  List<_LessonNodeData> _groupLessonNodes(List<_LessonNodeData> rawLessons) {
    if (rawLessons.length < 2) return rawLessons;

    final groupedLessons = <_LessonNodeData>[];
    var index = 0;

    while (index < rawLessons.length) {
      final currentLesson = rawLessons[index];

      if (index + 1 < rawLessons.length) {
        final nextLesson = rawLessons[index + 1];
        if (_shouldGroupLessonNodes(currentLesson, nextLesson)) {
          groupedLessons.add(
            _LessonNodeData(
              id: currentLesson.id,
              learningId: currentLesson.launchLessonId,
              practiceId: nextLesson.launchLessonId,
              title: _displayGroupedLessonTitle(currentLesson.title),
              category: 'mixed',
              description: currentLesson.description.isNotEmpty
                  ? currentLesson.description
                  : nextLesson.description,
              pageCount: currentLesson.pageCount + nextLesson.pageCount,
              chapterName: currentLesson.chapterName.isNotEmpty
                  ? currentLesson.chapterName
                  : nextLesson.chapterName,
              orderIndex: currentLesson.orderIndex,
            ),
          );
          index += 2;
          continue;
        }
      }

      groupedLessons.add(currentLesson);
      index += 1;
    }

    return groupedLessons;
  }

  List<_LessonNodeData> _separateCheatsheetLessons(
    List<_LessonNodeData> rawLessons,
  ) {
    _cheatsheetLesson = null;

    final pathLessons = <_LessonNodeData>[];
    for (final lesson in rawLessons) {
      if (_isCheatsheetLesson(lesson)) {
        _cheatsheetLesson ??= lesson;
        continue;
      }

      pathLessons.add(lesson);
    }

    return pathLessons;
  }

  Future<void> _loadScores() async {
    final int currentCourseIndex =
        widget.course.id != null && widget.course.id! > 0
        ? widget.course.id! - 1
        : 0;
    courseIndex = currentCourseIndex;

    await ScoresRepository.initializeScores(0, lessons.length);

    final courseScoresList = await ScoresRepository.getCourseScores(
      currentCourseIndex,
    );

    setState(() {
      if (courseScoresList.isEmpty) {
        courseScores = List.filled(lessons.length, 0);
      } else {
        if (courseScoresList.length < lessons.length) {
          courseScores = [
            ...courseScoresList,
            ...List.filled(lessons.length - courseScoresList.length, 0),
          ];
        } else {
          courseScores = courseScoresList;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);

    lessons = await _loadSectionLessons();
    lessonsByPages = lessons.isEmpty ? <List<_LessonNodeData>>[] : [lessons];
    _currentLessonPageIndex = 0;

    await _loadDoneLessons();
    await _loadLessonGrades();

    debugPrint(
      '🔍 LessonPathScreen: Found ${lessons.length} lessons in ${lessonsByPages.length} pages',
    );
    for (var lesson in lessons) {
      debugPrint('  - ${lesson.title}');
    }

    await _findDatabaseCourse();

    await _loadScores();

    _completedLessons = _countCompletedPrefix();
    unlocked = List.generate(lessons.length, (index) {
      return index <= _completedLessons;
    });

    _syncLessonNodeKeys(lessons.length);
    _scheduleAutoScrollToIndex(
      _completedLessons > 0 ? _completedLessons - 1 : null,
    );

    setState(() => _isLoading = false);
  }

  Future<void> _loadDoneLessons() async {
    final courseId = widget.course.id;
    if (courseId == null || courseId <= 0) {
      _doneLessonIds.clear();
      _completedLessons = 0;
      return;
    }

    final doneLessons = await _authService.getDoneLessonsInCourse(
      courseId: courseId,
      sectionId: widget.sectionId,
    );

    _doneLessonIds
      ..clear()
      ..addAll(
        doneLessons.map((lesson) => lesson['lessonId']).whereType<int>(),
      );
  }

  Future<void> _loadLessonGrades() async {
    final courseId = widget.course.id;
    if (courseId == null || courseId <= 0) return;

    try {
      final grades = await _authService.getSectionLessonsGrades(
        courseID: courseId,
        sectionID: widget.sectionId,
      );

      final Map<int, double> newPercents = {};
      final Map<int, Color> newColors = {};

      for (final g in grades) {
        final lid = (g['lessonId'] ?? g['lesson'] ?? g['id']) as dynamic;
        int lessonId = 0;
        if (lid is int) lessonId = lid;
        if (lessonId <= 0) continue;

        final rawGrade = g['grade'] ?? g['score'];
        double gradeVal = 0.0;
        if (rawGrade is num) {
          gradeVal = rawGrade.toDouble();
        } else if (rawGrade is String) {
          gradeVal = double.tryParse(rawGrade) ?? 0.0;
        }

        if (gradeVal <= 0) continue;

        // if backend stores 0..1 normalize to 0..100
        final percent = gradeVal <= 1.0 ? (gradeVal * 100.0) : gradeVal;
        newPercents[lessonId] = percent;

        Color nodeColor = Theme.of(context).cardColor;
        if (percent >= 70) {
          nodeColor = Colors.green[700]!;
        } else if (percent >= 50) {
          nodeColor = Colors.amber.withOpacity(0.18);
        } else {
          nodeColor = Colors.blue.withOpacity(0.10);
        }
        newColors[lessonId] = nodeColor;
      }

      if (mounted) {
        setState(() {
          _lessonPercent.addAll(newPercents);
          _lessonNodeColors.addAll(newColors);
        });
      }
    } catch (_) {
      // ignore
    }
  }

  int _countCompletedPrefix() {
    var completed = 0;

    for (final lesson in lessons) {
      if (!lesson.isCompleted(_doneLessonIds)) {
        break;
      }
      completed += 1;
    }

    return completed;
  }

  Future<List<_LessonNodeData>> _loadSectionLessons() async {
    final courseId = widget.course.id;
    if (courseId == null || courseId <= 0) {
      return _fallbackLessonNodes();
    }

    final sectionLessons = await _authService.getSectionLessons(
      courseId: courseId,
      sectionId: widget.sectionId,
    );

    if (sectionLessons.isNotEmpty) {
      final rawLessons = <_LessonNodeData>[];

      for (var index = 0; index < sectionLessons.length; index++) {
        final summaryNode = _LessonNodeData.fromMap(sectionLessons[index]);
        var node = summaryNode;

        if (summaryNode.id > 0) {
          try {
            final fullLesson = await _authService.getLessonById(
              courseId: courseId,
              sectionId: widget.sectionId,
              lessonId: summaryNode.id,
            );
            node = _LessonNodeData.fromLesson(fullLesson, orderIndex: index);
          } catch (_) {
            node = summaryNode;
          }
        }

        if (node.id > 0 || node.title.isNotEmpty) {
          rawLessons.add(node);
        }
      }

      return _groupLessonNodes(_separateCheatsheetLessons(rawLessons));
    }

    return _fallbackLessonNodes();
  }

  List<_LessonNodeData> _fallbackLessonNodes() {
    if (widget.originalCourse?.sections.isNotEmpty == true) {
      final rawLessons = List<_LessonNodeData>.generate(
        widget.originalCourse!.sections.length,
        (index) => _LessonNodeData.fromLesson(
          widget.originalCourse!.sections[index],
          orderIndex: index,
        ),
      );

      return _groupLessonNodes(_separateCheatsheetLessons(rawLessons));
    }

    if (widget.course.sections.isNotEmpty) {
      final rawLessons = List<_LessonNodeData>.generate(
        widget.course.sections.length,
        (index) => _LessonNodeData.fromLesson(
          widget.course.sections[index],
          orderIndex: index,
        ),
      );

      return _groupLessonNodes(_separateCheatsheetLessons(rawLessons));
    }

    _cheatsheetLesson = null;
    return const [];
  }

  Future<void> _openCheatsheetLesson() async {
    final cheatsheet = _cheatsheetLesson;
    final courseId = widget.course.id;
    if (cheatsheet == null || courseId == null || courseId <= 0) return;

    final targetLessonId = cheatsheet.launchLessonId;
    if (targetLessonId <= 0) return;

    final lesson = lesson_model.Section(
      id: targetLessonId,
      title: cheatsheet.title,
      questions: const [],
      contents: const [],
      done: false,
      description: cheatsheet.description,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonContentScreen(
          lesson: lesson,
          courseId: courseId,
          sectionId: widget.sectionId,
          lessonId: targetLessonId,
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions({int? totalNodesInPage}) {
    return [
      if (_cheatsheetLesson != null)
        IconButton(
          icon: const Icon(Icons.article_outlined),
          tooltip: 'Cheatsheet',
          onPressed: _openCheatsheetLesson,
        ),
      SizedBox(width: 20),
      if (totalNodesInPage != null)
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_completedLessons/$totalNodesInPage',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Future<void> _findDatabaseCourse() async {
    try {
      // final allCourses = await _courseService.getCourses();

      // final firestoreCourse = allCourses.firstWhere(
      //   (course) => course.title == widget.course.title,
      //   orElse: () {
      //     return Course(
      //       title: widget.course.title,
      //       courseIndex: 0,
      //       lessonsFinished: 0,
      //     );
      //   },
      // );

      // _firestoreCourseId = firestoreCourse.id;
      // _completedLessons = firestoreCourse.lessonsFinished;
    } catch (e) {
      _completedLessons = 0;
    }
  }

  Future<void> startTest(
    _LessonNodeData lesson,
    int pageIndex, {
    bool practice = false,
  }) async {
    final currentPageLessons = lessonsByPages[_currentLessonPageIndex];
    final currentScores = _normalizedScores(currentPageLessons.length);
    final currentUnlocked = _normalizedUnlocked(currentPageLessons.length);

    debugPrint(
      '🔵 startTest called: lesson=${lesson.title}, pageIndex=$pageIndex, unlocked=${unlocked.length}',
    );
    if (pageIndex < 0 ||
        pageIndex >= currentUnlocked.length ||
        !currentUnlocked[pageIndex]) {
      debugPrint(
        '❌ Early return: pageIndex=$pageIndex, locked=${pageIndex >= currentUnlocked.length ? true : !currentUnlocked[pageIndex]}',
      );
      return;
    }

    final isFirstLessonOfFirstCourse = pageIndex == 0 && _completedLessons == 0;

    DateTime? startTime;
    if (isFirstLessonOfFirstCourse) {
      startTime = DateTime.now();
    }
    if (widget.course.id == null) {
      return;
    }

    final isExercise = practice || lesson.category == 'exercise';
    final targetLessonId = practice
        ? (lesson.practiceId ?? lesson.launchLessonId)
        : lesson.launchLessonId;

    if (targetLessonId <= 0) {
      return;
    }

    lesson_model.Section fullLesson = lesson_model.Section(
      id: targetLessonId,
      title: lesson.title,
      questions: const [],
      contents: const [],
      done: false,
      description: '',
    );

    if (isExercise) {
      try {
        fullLesson = await _authService.getLessonById(
          courseId: widget.course.id!,
          sectionId: widget.sectionId,
          lessonId: targetLessonId,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load quiz lesson: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    if (!mounted) return;

    // Check whether this exercise lesson contains non-exercise blocks
    // (headings, tables, bullet lists, paragraphs, etc.) alongside exercises.
    // If so, route to LessonContentScreen which renders ALL block types inline,
    // rather than McqTestScreen which would only show the extracted MCQ questions.
    final hasMixedContent = fullLesson.contents.any(
      (c) => c.hasNonExerciseBlocks,
    );

    debugPrint("\n Lessons info : ${fullLesson.toString()}");
    final score = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            isExercise && fullLesson.questions.isNotEmpty && !hasMixedContent
            ? McqTestScreen(
                section: fullLesson.title,
                questions: fullLesson.questions,
                courseId: courseIndex,
                totalLessons: lessons.length,
                lessonId: targetLessonId,
                onTestCompleted: () {},
              )
            : LessonContentScreen(
                lesson: fullLesson,
                courseId: widget.course.id,
                sectionId: widget.sectionId,
                lessonId: targetLessonId,
              ),
      ),
    );

    if (score != null && mounted) {
      final updatedScores = List<int>.from(currentScores);
      if (score > updatedScores[pageIndex]) {
        updatedScores[pageIndex] = score;
      }

      final isPassingScore = score >= 70;
      final shouldUnlockNext =
          isPassingScore && pageIndex + 1 < currentUnlocked.length;

      setState(() {
        courseScores = updatedScores;
        _doneLessonIds.add(targetLessonId);

        if (shouldUnlockNext) {
          final updatedUnlocked = List<bool>.from(currentUnlocked);
          updatedUnlocked[pageIndex + 1] = true;
          unlocked = updatedUnlocked;
        } else {
          unlocked = currentUnlocked;
        }
      });

      final currentCourseIndex = widget.course.id! - 1;
      await ScoresRepository.addScore(currentCourseIndex, pageIndex, score);

      if (isPassingScore) {
        final newCompletedCount = pageIndex + 1;

        if (newCompletedCount > _completedLessons) {
          _completedLessons = newCompletedCount;

          await _statsService.recordLessonCompletion(
            widget.course.title,
            fullLesson.title,
          );

          if (score == 100) {
            await _statsService.recordPerfectScore();
          }

          if (score >= 70) {
            final correctCount = (fullLesson.questions.length * (score / 100))
                .round();
            for (int i = 0; i < correctCount; i++) {
              await _statsService.incrementCorrectAnswers();
            }
          }

          if (isFirstLessonOfFirstCourse && startTime != null) {
            final completionTime = DateTime.now()
                .difference(startTime)
                .inMinutes;

            if (completionTime <= 5) {
              await _statsService.recordFastCompletion();
            }
          }

          if (newCompletedCount >= lessons.length) {}

          await _updateCourseProgress(_completedLessons);
        }
        // update UI with the latest score percentage and node color for this lesson
        if (targetLessonId > 0) {
          final double percent = score.toDouble();
          Color nodeColor = Theme.of(context).cardColor;
          if (percent >= 70) {
            nodeColor = Colors.green[700]!;
          } else if (percent >= 50) {
            nodeColor = Colors.amber.withOpacity(0.18);
          } else {
            nodeColor = Colors.blue.withOpacity(0.10);
          }

          if (mounted) {
            setState(() {
              _lessonPercent[targetLessonId] = percent;
              _lessonNodeColors[targetLessonId] = nodeColor;
            });
          }
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Score below 70%. Try again to unlock next lesson.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _updateCourseProgress(int completedLessons) async {
    try {
      if (_firestoreCourseId != null) {
        // Update existing course
        // await _courseService.updateCourse(updatedCourse);
      } else {
        // Create new course entry
        // final newId = await _courseService.insertCourse(newCourse);
        // _firestoreCourseId = newId;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Progress saved!'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showLessonPreview(_LessonNodeData lesson, int pageIndex) async {
    final currentPageLessons = lessonsByPages[_currentLessonPageIndex];
    final currentUnlocked = _normalizedUnlocked(currentPageLessons.length);
    final isLessonDone = lesson.isCompleted(_doneLessonIds);

    if (pageIndex < 0 ||
        pageIndex >= currentUnlocked.length ||
        !currentUnlocked[pageIndex]) {
      return;
    }

    final description = lesson.description.trim().isEmpty
        ? 'Start this lesson when you are ready.'
        : lesson.description.trim();
    final practiceLocked = _isPracticeLocked(lesson);

    final selectedAction = await showDialog<_LessonAction>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;
        final accentColor = isLessonDone
            ? const Color(0xFF58CC02)
            : const Color.fromARGB(255, 39, 156, 0);
        final hasBothActions = lesson.hasCombinedAction;
        final categoryLabel = hasBothActions
            ? 'Learning + Practice'
            : (_isPracticeAction(lesson) ? 'Practice' : 'Learning');

        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            decoration: BoxDecoration(
              color: isLessonDone
                  ? (isDark ? const Color(0xFF1F2D1F) : const Color(0xFFF2FBF0))
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isLessonDone
                    ? accentColor.withValues(alpha: isDark ? 0.55 : 0.95)
                    : isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : const Color(0xFFE5E5E5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isLessonDone
                      ? accentColor.withValues(alpha: isDark ? 0.22 : 0.18)
                      : Colors.black.withValues(alpha: isDark ? 0.35 : 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLessonDone ? 'Completed lesson' : categoryLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lesson.title,
                            textAlign: TextAlign.left,
                            softWrap: true,
                            maxLines: 3, // or null for unlimited
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.nunito(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              color: theme.textTheme.titleLarge?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14), // width, not height, inside Row
                    Container(
                      width: 58,
                      height: 58,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1CB0F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _lessonCategoryIcon(lesson.category, lesson.title),
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  description,
                  textAlign: TextAlign.left,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.35,
                    color: theme.textTheme.bodyMedium?.color?.withValues(
                      alpha: 0.78,
                    ),
                  ),
                ),
                // const SizedBox(height: 14),
                // Container(
                //   padding: const EdgeInsets.symmetric(
                //     horizontal: 12,
                //     vertical: 7,
                //   ),
                //   decoration: BoxDecoration(
                //     color: accentSoftColor,
                //     borderRadius: BorderRadius.circular(999),
                //   ),
                //   child: Text(
                //     pageLabel,
                //     style: GoogleFonts.nunito(
                //       fontSize: 13,
                //       fontWeight: FontWeight.w800,
                //       color: accentColor,
                //     ),
                //   ),
                // ),
                // const SizedBox(height: 18),
                const SizedBox(height: 18),

                if (hasBothActions)
                  SizedBox(
                    height: 60,
                    child: Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(
                                dialogContext,
                                _LessonAction.learning,
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                'Learning',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton(
                              onPressed: practiceLocked
                                  ? null
                                  : () => Navigator.pop(
                                      dialogContext,
                                      _LessonAction.practice,
                                    ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: practiceLocked
                                    ? theme.disabledColor
                                    : accentColor,
                                side: BorderSide(
                                  color: practiceLocked
                                      ? theme.disabledColor
                                      : accentColor,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: Text(
                                practiceLocked ? 'Exercise Locked' : 'Exercise',
                                style: GoogleFonts.nunito(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(
                    width: 300,
                    height: 50,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        dialogContext,
                        _isPracticeAction(lesson)
                            ? _LessonAction.practice
                            : _LessonAction.learning,
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        _isPracticeAction(lesson)
                            ? 'START PRACTICE'
                            : 'START THE LESSON',
                        style: GoogleFonts.nunito(
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedAction == null || !mounted) {
      return;
    }

    if (selectedAction == _LessonAction.practice) {
      await startTest(lesson, pageIndex, practice: true);
      return;
    }

    await startTest(lesson, pageIndex);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SophiaPathLoadingScreen(appBarTitle: widget.course.title);
    }

    if (lessonsByPages.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.sectionTitle ?? widget.course.title),
          actions: _buildAppBarActions(),
        ),
        body: const Center(child: Text('No lessons found in this section.')),
      );
    }

    final theme = Theme.of(context);
    final nodeSpacing = 120.0;
    final currentPageLessons = lessonsByPages[_currentLessonPageIndex];
    final totalNodesInPage = currentPageLessons.length;
    final currentScores = _normalizedScores(totalNodesInPage);
    final currentUnlocked = _normalizedUnlocked(totalNodesInPage);
    _syncLessonNodeKeys(totalNodesInPage);

    if (!_didInitialAutoScroll && _pendingAutoScrollIndex != null) {
      _scheduleAutoScrollToIndex(_pendingAutoScrollIndex);
    }

    // build node widgets and compute exact Y positions so painter can follow
    final List<Widget> nodeWidgets = [];
    final List<double> nodeCentersY = [];
    final List<bool> connectNext = [];
    String? lastChapter;
    String? prevChapter;
    double extraGap = 0;
    const double nodeSize = 80.0;
    double contentHeight = 0;
    for (int i = 0; i < totalNodesInPage; i++) {
      final chapterName = currentPageLessons[i].chapterName.isNotEmpty
          ? currentPageLessons[i].chapterName
          : 'General';

      if (chapterName != lastChapter) {
        lastChapter = chapterName;
        if (i == 0) {
          extraGap = 40;
        } else {
          extraGap += 120; // space before chapter text
        }

        //chapters names
        nodeWidgets.add(
          Positioned(
            top: i * nodeSpacing + extraGap - 30,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white),
                ),
                child: Text(
                  chapterName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );

        final chapterTop = i * nodeSpacing + extraGap - 30;
        contentHeight = max(contentHeight, chapterTop + 60);

        extraGap += 60;
        //dividers
        nodeWidgets.add(
          Positioned(
            top: i * nodeSpacing + extraGap - 135,
            left: 0,
            right: 0,
            child: Center(
              child: DottedLine(
                direction: Axis.horizontal,
                lineThickness: 2.0,
                dashLength: 4.0,
                dashColor: theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
                dashGapLength: 4.0,
              ),
            ),
          ),
        );

        // nodeWidgets.add( //todo : add a widget that appears on top as lock
        //   Positioned(
        //     top: i * nodeSpacing + extraGap - 135,
        //     left: 0,
        //     right: 0,
        //     child: Container(
        //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        //       decoration: BoxDecoration(
        //         color: const Color.fromARGB(107, 114, 114, 114),
        //         borderRadius: BorderRadius.circular(12),
        //         border: Border.all(color: Colors.white),
        //       ),
        //       child: SizedBox(height: 50),

        //       // child: Text(
        //       //   chapterName,
        //       //   style: GoogleFonts.poppins(
        //       //     fontSize: 24,
        //       //     fontWeight: FontWeight.w600,
        //       //   ),
        //       // ),
        //     ),
        //   ),
        // );
      }

      final nodeTop = i * nodeSpacing + extraGap;
      nodeCentersY.add(nodeTop + nodeSize / 2);
      contentHeight = max(contentHeight, nodeTop + nodeSize + 20);

      if (i > 0) {
        connectNext.add(prevChapter == chapterName);
      }
      prevChapter = chapterName;

      //nodes
      nodeWidgets.add(
        Positioned(
          key: _lessonNodeKeys[i],
          top: nodeTop,
          left: i % 2 == 0
              ? MediaQuery.of(context).size.width * 0.18 - 17
              : MediaQuery.of(context).size.width * 0.62 - 17,
          child: CourseNode(
            title: currentPageLessons[i].title,
            index: i + 1,
            locked: !currentUnlocked[i],
            percentage:
                (_isExerciseLike(currentPageLessons[i]) ||
                    currentPageLessons[i].hasPractice)
                ? (_lessonPercent[currentPageLessons[i].scoreLessonId] != null
                      ? _lessonPercent[currentPageLessons[i].scoreLessonId]!
                            .round()
                      : currentScores[i])
                : 0,
            isCompleted: currentPageLessons[i].isCompleted(_doneLessonIds),
            category: currentPageLessons[i].category,
            theme: theme,
            nodeColor: _lessonNodeColors[currentPageLessons[i].scoreLessonId],
            enabled: currentUnlocked[i],
            onTap: () => _showLessonPreview(currentPageLessons[i], i),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          child: Text(
            widget.sectionTitle ?? widget.course.title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF3D5CFF),
        foregroundColor: Colors.white,
        actions: _buildAppBarActions(totalNodesInPage: totalNodesInPage),
      ),

      body: Column(
        children: [
          // if (totalPages > 1)
          //   Padding(
          //     padding: const EdgeInsets.all(12.0),
          //     child: Text(
          //       '${lessons[_currentLessonPageIndex].title}',
          //       style: GoogleFonts.poppins(
          //         fontSize: 16,
          //         fontWeight: FontWeight.w600,
          //       ),
          //       textAlign: TextAlign.center,
          //     ),
          //   ),
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                height: max(
                  contentHeight + 40,
                  totalNodesInPage * nodeSpacing + 30,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: Stack(
                    children: [
                      CustomPaint(
                        size: Size(
                          double.infinity,
                          nodeCentersY.isNotEmpty
                              ? nodeCentersY.last + 60
                              : totalNodesInPage * nodeSpacing,
                        ),
                        painter: LessonPathPainter(
                          nodeCentersY,
                          connectNext: connectNext,
                          unlocked: currentUnlocked,
                          theme: theme,
                        ),
                      ),
                      ...nodeWidgets,
                    ],
                  ),
                ),
              ),
            ),
          ),
          // if (totalPages > 1)
          //   Padding(
          //     padding: const EdgeInsets.all(16.0),
          //     child: Row(
          //       mainAxisAlignment: MainAxisAlignment.center,
          //       children: [
          //         IconButton(
          //           icon: const Icon(Icons.arrow_back_ios),
          //           onPressed: _currentLessonPageIndex > 0
          //               ? () => setState(() => _currentLessonPageIndex--)
          //               : null,
          //         ),
          //         Text(
          //           '${_currentLessonPageIndex + 1} / $totalPages',
          //           style: GoogleFonts.poppins(
          //             fontSize: 14,
          //             fontWeight: FontWeight.w600,
          //           ),
          //         ),
          //         IconButton(
          //           icon: const Icon(Icons.arrow_forward_ios),
          //           onPressed: _currentLessonPageIndex < totalPages - 1
          //               ? () => setState(() => _currentLessonPageIndex++)
          //               : null,
          //         ),
          //       ],
          //     ),
          //   ),
        ],
      ),
    );
  }
}

class CourseNode extends StatefulWidget {
  final String title;
  final int index;
  final bool locked;
  final String category;
  final int percentage;
  final bool isCompleted;
  final ThemeData theme;
  final Color? nodeColor;
  final bool enabled;
  final VoidCallback? onTap;

  const CourseNode({
    super.key,
    required this.title,
    required this.index,
    required this.locked,
    required this.category,
    this.percentage = 0,
    this.isCompleted = false,
    required this.theme,
    this.nodeColor,
    this.enabled = true,
    this.onTap,
  });

  @override
  State<CourseNode> createState() => _CourseNodeState();
}

class _CourseNodeState extends State<CourseNode> {
  bool hovering = false;

  Color _darken(Color color, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  Widget build(BuildContext context) {
    const nodeSize = 80.0;
    final isDark = widget.theme.brightness == Brightness.dark;

    Color nodeColor;
    Color borderColor;
    Color shadowColor;
    Color textColor = Colors.white;

    // allow overriding node color from parent
    if (widget.nodeColor != null && !widget.locked) {
      nodeColor = widget.nodeColor!;
      borderColor = widget.nodeColor!.withValues(alpha: 0.9);
      shadowColor = _darken(nodeColor, 0.16);
      textColor = Colors.white;
    } else if (widget.locked) {
      nodeColor = isDark ? const Color(0xFF3F4654) : const Color(0xFFE5E5E5);
      borderColor = isDark ? const Color(0xFF555F70) : const Color(0xFFD0D0D0);
      shadowColor = isDark ? const Color(0xFF2C323D) : const Color(0xFFBDBDBD);
      textColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    } else if (widget.isCompleted) {
      nodeColor = const Color(0xFF58CC02);
      borderColor = const Color(0xFF58CC02);
      shadowColor = const Color(0xFF46A302);
    } else {
      nodeColor = const Color(0xFF1CB0F6);
      borderColor = const Color(0xFF1CB0F6);
      shadowColor = const Color(0xFF0A8ED1);
    }

    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            if (!widget.locked && hovering)
              Container(
                width: nodeSize + 12,
                height: nodeSize + 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: nodeColor.withValues(alpha: 0.2),
                ),
              ),

            _DuolingoButton(
              enabled: widget.enabled && !widget.locked,
              onPressed: widget.onTap,
              baseColor: nodeColor,
              shadowColor: shadowColor,
              borderColor: borderColor,
              size: nodeSize,
              shadowHeight: 6,
              borderRadius: nodeSize / 2,
              shape: BoxShape.circle,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: isDark || widget.locked ? 0.06 : 0.28,
                      ),
                      blurRadius: 0,
                      offset: const Offset(0, 2),
                      spreadRadius: -1,
                    ),
                  ],
                ),
                child: Center(
                  child: widget.locked
                      ? Icon(Icons.lock, color: textColor, size: 24)
                      : Icon(
                          _lessonCategoryIcon(widget.category, widget.title),
                          color: Colors.white,
                          size: 32,
                        ),
                ),
              ),
            ),

            if (widget.isCompleted && !widget.locked)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    border: Border.all(color: Colors.green, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.green),
                ),
              ),

            if (!widget.locked && widget.percentage > 0)
              Positioned(
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.percentage < 50
                        ? Colors.red
                        : widget.percentage < 80
                        ? Colors.orange
                        : Colors.green,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 0.45),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Text(
                    '${widget.percentage}%',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 100,
          child: Column(
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: widget.locked
                      ? (isDark ? Colors.grey[500] : Colors.grey[600])
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (widget.isCompleted && !widget.locked)
                const SizedBox(height: 2),
              // if (widget.isCompleted && !widget.locked)
              //   Text(
              //     'Completed',
              //     style: GoogleFonts.poppins(
              //       fontSize: 9,
              //       color: Colors.green,
              //       fontWeight: FontWeight.w500,
              //     ),
              //   ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DuolingoButton extends StatefulWidget {
  final bool enabled;
  final VoidCallback? onPressed;
  final Widget child;
  final Color baseColor;
  final Color shadowColor;
  final Color borderColor;
  final double size;
  final double shadowHeight;
  final double borderRadius;
  final BoxShape shape;

  const _DuolingoButton({
    required this.enabled,
    required this.onPressed,
    required this.child,
    required this.baseColor,
    required this.shadowColor,
    required this.borderColor,
    this.size = 80,
    this.shadowHeight = 6,
    this.borderRadius = 16,
    this.shape = BoxShape.rectangle,
  });

  @override
  State<_DuolingoButton> createState() => _DuolingoButtonState();
}

class _DuolingoButtonState extends State<_DuolingoButton> {
  bool _isPressed = false;

  void _setPressed(bool pressed) {
    if (!widget.enabled || _isPressed == pressed) return;
    setState(() => _isPressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final pressedOffset = _isPressed ? widget.shadowHeight : 0.0;
    final cursor = widget.enabled
        ? SystemMouseCursors.click
        : SystemMouseCursors.basic;

    return MouseRegion(
      cursor: cursor,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.enabled ? (_) => _setPressed(true) : null,
        onTapUp: widget.enabled
            ? (_) {
                _setPressed(false);
                widget.onPressed?.call();
              }
            : null,
        onTapCancel: widget.enabled ? () => _setPressed(false) : null,
        child: SizedBox(
          width: widget.size,
          height: widget.size + widget.shadowHeight,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: widget.shadowHeight,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.shadowColor,
                    shape: widget.shape,
                    borderRadius: widget.shape == BoxShape.rectangle
                        ? BorderRadius.circular(widget.borderRadius)
                        : null,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 50),
                curve: Curves.easeOut,
                top: pressedOffset,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    color: widget.baseColor,
                    shape: widget.shape,
                    borderRadius: widget.shape == BoxShape.rectangle
                        ? BorderRadius.circular(widget.borderRadius)
                        : null,
                    border: Border.all(color: widget.borderColor, width: 2),
                  ),
                  child: Center(child: widget.child),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LessonPathPainter extends CustomPainter {
  final List<double> nodeCentersY;
  final List<bool> connectNext;
  final List<bool> unlocked;
  final ThemeData theme;

  LessonPathPainter(
    this.nodeCentersY, {
    required this.connectNext,
    required this.unlocked,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final isDark = theme.brightness == Brightness.dark;
    final w = size.width;

    for (int i = 0; i < nodeCentersY.length - 1; i++) {
      // skip drawing if there's a chapter break between i and i+1
      final shouldConnect = (i < connectNext.length) ? connectNext[i] : true;
      if (!shouldConnect) continue;

      final isSegmentUnlocked =
          unlocked.length > i && unlocked[i] && unlocked[i + 1];

      final paint = Paint()
        ..color = isSegmentUnlocked
            ? const Color(0xFF3D5CFF).withValues(alpha: 0.7)
            : (isDark ? Colors.grey[700]! : Colors.grey[300]!)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSegmentUnlocked ? 3.5 : 2.5
        ..strokeCap = StrokeCap.round;

      final startX = i % 2 == 0 ? w * 0.18 + 40 : w * 0.62 + 40;
      final startY = nodeCentersY[i];

      final endX = (i + 1) % 2 == 0 ? w * 0.18 + 40 : w * 0.62 + 40;
      final endY = nodeCentersY[i + 1];

      final controlX1 = startX + (endX - startX) * 0.5;
      final controlY1 = startY + (endY - startY) * 0.35;
      final controlX2 = controlX1;
      final controlY2 = startY + (endY - startY) * 0.65;

      final path = Path()
        ..moveTo(startX, startY)
        ..cubicTo(controlX1, controlY1, controlX2, controlY2, endX, endY);

      canvas.drawPath(path, paint);

      if (isSegmentUnlocked) {
        final arrowPaint = Paint()
          ..color = const Color(0xFF3D5CFF)
          ..style = PaintingStyle.fill;

        final t = 0.7;
        final arrowX = _cubicBezier(startX, controlX1, controlX2, endX, t);
        final arrowY = _cubicBezier(startY, controlY1, controlY2, endY, t);

        final dx = _cubicBezierDerivative(
          startX,
          controlX1,
          controlX2,
          endX,
          t,
        );
        final dy = _cubicBezierDerivative(
          startY,
          controlY1,
          controlY2,
          endY,
          t,
        );
        final angle = atan2(dy, dx);

        canvas.save();
        canvas.translate(arrowX, arrowY);
        canvas.rotate(angle);

        final arrowPath = Path();
        arrowPath.moveTo(0, 0);
        arrowPath.lineTo(-8, -5);
        arrowPath.lineTo(-8, 5);
        arrowPath.close();

        canvas.drawPath(arrowPath, arrowPaint);
        canvas.restore();
      }
    }
  }

  double _cubicBezier(double a, double b, double c, double d, double t) {
    return pow(1 - t, 3) * a +
        3 * pow(1 - t, 2) * t * b +
        3 * (1 - t) * pow(t, 2) * c +
        pow(t, 3) * d;
  }

  double _cubicBezierDerivative(
    double a,
    double b,
    double c,
    double d,
    double t,
  ) {
    return 3 * pow(1 - t, 2) * (b - a) +
        6 * (1 - t) * t * (c - b) +
        3 * pow(t, 2) * (d - c);
  }

  @override
  bool shouldRepaint(covariant LessonPathPainter oldDelegate) {
    return oldDelegate.nodeCentersY != nodeCentersY ||
        oldDelegate.connectNext != connectNext ||
        oldDelegate.unlocked != unlocked ||
        oldDelegate.theme != theme;
  }
}
