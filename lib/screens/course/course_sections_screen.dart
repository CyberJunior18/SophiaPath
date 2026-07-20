import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/course/course_info.dart';
import '../../models/course/lesson.dart';
import '../authentication/authService.dart';
import '../Lessons/mcq_test_screen.dart';
import 'lesson_contents_list_screen.dart';
import 'lesson_path_screen.dart';
import 'course_contents_screen.dart';
import 'course_info_screen.dart';

enum _LessonFilter { all, withContent, withQuiz }

class CourseSectionsGridScreen extends StatefulWidget {
  final CourseInfo course;

  const CourseSectionsGridScreen({super.key, required this.course});

  @override
  State<CourseSectionsGridScreen> createState() =>
      _CourseSectionsGridScreenState();
}

class _CourseSectionsGridScreenState extends State<CourseSectionsGridScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _LessonFilter _activeFilter = _LessonFilter.all;
  final Map<int, int> _sectionLessonCounts = {};
  final Map<int, int> _sectionQuizCounts = {};
  final Map<int, int> _sectionFinishedLessonCounts = {};
  final Map<int, int> _sectionFinishedQuizCounts = {};
  final AuthService _authService = AuthService();
  final List<String> sectionsIcons = [];
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSectionSummaries();
  }

  Future<void> _loadSectionSummaries() async {
    final courseId = widget.course.id;
    if (courseId == null) return;

    for (final s in widget.course.sections) {
      final sid = s.id ?? 0;
      if (sid <= 0) continue;
      try {
        final List<Map<String, dynamic>> lessonsList = await _authService
            .getSectionLessons(courseId: courseId, sectionId: sid);

        final List<Map<String, dynamic>> doneLessonsList = await _authService
            .getSectionLessonsGrades(courseID: courseId, sectionID: sid);

        final doneLessonIds = doneLessonsList
            .map((d) => d['lessonId'].toString())
            .toSet();

        int lessonsCount = 0;
        int quizCount = 0;
        int finishedLessonsCount = 0;
        int finishedQuizCount = 0;

        for (final l in lessonsList) {
          final cat = (l['category'] ?? '').toString().toLowerCase();
          final isQuiz = cat == 'exercise' || cat == 'quiz' || cat == 'mcq';
          final lId = l['id'].toString();
          final isDone = doneLessonIds.contains(lId);

          if (isQuiz) {
            quizCount++;
            if (isDone) finishedQuizCount++;
          } else {
            lessonsCount++;
            if (isDone) finishedLessonsCount++;
          }
        }

        setState(() {
          _sectionLessonCounts[sid] = lessonsCount;
          _sectionQuizCounts[sid] = quizCount;
          _sectionFinishedLessonCounts[sid] = finishedLessonsCount;
          _sectionFinishedQuizCounts[sid] = finishedQuizCount;
        });
      } catch (_) {
        // ignore errors per-section
      }
    }
  }

  List<_LessonGridItem> _filteredLessons() {
    final lessons = widget.course.sections;

    return List<_LessonGridItem>.generate(
      lessons.length,
      (index) => _LessonGridItem(index: index, lesson: lessons[index]),
    ).where((item) {
      final lesson = item.lesson;
      final chapter = lesson.contents.isNotEmpty
          ? lesson.contents.first.chapterName
          : '';

      final matchesSearch =
          _searchQuery.isEmpty ||
          lesson.title.toLowerCase().contains(_searchQuery) ||
          lesson.description.toLowerCase().contains(_searchQuery) ||
          chapter.toLowerCase().contains(_searchQuery);

      final matchesFilter = switch (_activeFilter) {
        _LessonFilter.all => true,
        _LessonFilter.withContent => lesson.contents.isNotEmpty,
        _LessonFilter.withQuiz => lesson.questions.isNotEmpty,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _openLessonContents(_LessonGridItem item) {
    final lesson = item.lesson;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonContentsListScreen(lesson: lesson),
      ),
    );
  }

  void _openLessonQuiz(_LessonGridItem item) {
    final lesson = item.lesson;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => McqTestScreen(
          section: lesson.title,
          questions: lesson.questions,
          courseId: widget.course.id ?? 0,
          totalLessons: widget.course.sections.length,
          onTestCompleted: () {},
        ),
      ),
    );
  }

  void _openLessonPath(_LessonGridItem item) {
    final sectionId = item.lesson.id;
    if (sectionId == null || sectionId <= 0) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonPathScreen(
          course: widget.course,
          originalCourse: widget.course,
          initialLessonPageIndex: item.index,
          sectionId: sectionId,
          sectionTitle: item.lesson.title,
        ),
      ),
    );
  }

  String? _getSectionIconPath(String title) {
    final lowerTitle = title.trim().toLowerCase();

    if (lowerTitle.contains('common vulnerabilities')) {
      return 'assets/sections/commonVulnerabilities.png';
    } else if (lowerTitle.contains('c++')) {
      return 'assets/sections/cpp.png';
    } else if (lowerTitle.contains('cryptography')) {
      return 'assets/sections/cryptography.png';
    } else if (lowerTitle.contains('data structures') ||
        lowerTitle.contains('datastructures')) {
      return 'assets/sections/datast.png';
    } else if (lowerTitle.contains('intro') &&
        lowerTitle.contains('cybersecurity')) {
      return 'assets/sections/IntroToCybersecurity.png';
    } else if (lowerTitle.contains('intro') &&
        lowerTitle.contains('philosophy')) {
      return 'assets/sections/IntroToPhilosophy.png';
    } else if (lowerTitle.contains('oop') ||
        lowerTitle.contains('object oriented programming')) {
      return 'assets/sections/oop.png';
    }

    return null;
  }

  int _getLessonCount(Lesson lesson) {
    return _sectionLessonCounts[lesson.id] ?? lesson.contents.length;
  }

  int _getQuizCount(Lesson lesson) {
    return _sectionQuizCounts[lesson.id] ?? lesson.questions.length;
  }

  int _getFinishedLessonCount(Lesson lesson) {
    return _sectionFinishedLessonCounts[lesson.id] ?? 0;
  }

  int _getFinishedQuizCount(Lesson lesson) {
    return _sectionFinishedQuizCounts[lesson.id] ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredLessons();
    final crossAxisCount = MediaQuery.of(context).size.width >= 1000
        ? 4
        : MediaQuery.of(context).size.width >= 700
        ? 3
        : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sections',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Course info',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CourseInfoScreen(course: widget.course),
                ),
              );
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search sections, descriptions, or chapter name',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _activeFilter == _LessonFilter.all,
                    onSelected: (_) {
                      setState(() => _activeFilter = _LessonFilter.all);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Has content'),
                    selected: _activeFilter == _LessonFilter.withContent,
                    onSelected: (_) {
                      setState(() => _activeFilter = _LessonFilter.withContent);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Has quiz'),
                    selected: _activeFilter == _LessonFilter.withQuiz,
                    onSelected: (_) {
                      setState(() => _activeFilter = _LessonFilter.withQuiz);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No sections found.',
                        style: GoogleFonts.poppins(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final lesson = item.lesson;
                        final isChapterTest = lesson.title
                            .toLowerCase()
                            .startsWith('chapter test');
                        // final chapterName = lesson.contents.isNotEmpty
                        //     ? lesson.contents.first.chapterName
                        //     : 'General';

                        final lessonCount = _getLessonCount(lesson);
                        final quizCount = _getQuizCount(lesson);
                        final isComingSoon = lessonCount == 0 && quizCount == 0;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: isComingSoon
                              ? null
                              : () => _openLessonPath(item),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: theme.primaryColor.withValues(alpha: 0.3),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // Background Icon
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 5,
                                      right: 5,
                                      top: 5,
                                      bottom: 35,
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        final iconPath = _getSectionIconPath(lesson.title);
                                        if (iconPath != null) {
                                          return Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child: Image.asset(
                                              iconPath,
                                              fit: BoxFit.contain,
                                            ),
                                          );
                                        } else {
                                          return Center(
                                            child: Icon(
                                              isChapterTest
                                                  ? Icons.local_cafe_outlined
                                                  : lesson.questions.isNotEmpty
                                                      ? Icons.quiz_outlined
                                                      : Icons.menu_book_outlined,
                                              size: 50,
                                              color: theme.primaryColor,
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  // Content Section at the bottom in an opacity container
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(16),
                                        bottomRight: Radius.circular(16),
                                      ),
                                      child: BackdropFilter(
                                        filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(alpha: 0.3),
                                            border: Border(
                                              top: BorderSide(
                                                color: theme.primaryColor.withValues(alpha: 0.6),
                                                width: 1.5,
                                              ),
                                            ),
                                          ),
                                      padding: const EdgeInsets.all(10.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Title
                                          Text(
                                            lesson.title,
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (isComingSoon)
                                            const SizedBox.shrink()
                                          else
                                            Padding(
                                              padding: const EdgeInsets.only(top: 8),
                                              child: Builder(
                                                builder: (context) {
                                                  final finishedItems = _getFinishedLessonCount(lesson) + _getFinishedQuizCount(lesson);
                                                  final totalItems = _getLessonCount(lesson) + _getQuizCount(lesson);
                                                  final progress = totalItems > 0 ? finishedItems / totalItems : 0.0;
                                                  
                                                  return Row(
                                                    children: [
                                                      Expanded(
                                                        child: ClipRRect(
                                                          borderRadius: BorderRadius.circular(4),
                                                          child: LinearProgressIndicator(
                                                            value: progress,
                                                            backgroundColor: Colors.white.withValues(alpha: 0.2),
                                                            color: theme.primaryColor,
                                                            minHeight: 6,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        '${(progress * 100).toInt()}%',
                                                        style: GoogleFonts.poppins(
                                                          fontSize: 12,
                                                          fontWeight: FontWeight.bold,
                                                          color: theme.primaryColor,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ),
                                        ],
                                      ), // Column
                                    ), // Container
                                  ), // BackdropFilter
                                  ), // ClipRRect
                                  ), // Positioned
                                          if (!isComingSoon)
                                            Positioned(
                                              top: 4,
                                              right: 4,
                                              child: PopupMenuButton<String>(
                                                icon: const Icon(
                                                  Icons.more_vert,
                                                ),
                                                onSelected: (value) {
                                                  switch (value) {
                                                    case 'contents':
                                                      if (lesson
                                                          .contents
                                                          .isNotEmpty) {
                                                        _openLessonContents(
                                                          item,
                                                        );
                                                      }
                                                      break;
                                                    case 'quiz':
                                                      if (lesson
                                                          .questions
                                                          .isNotEmpty) {
                                                        _openLessonQuiz(item);
                                                      }
                                                      break;
                                                    case 'path':
                                                      _openLessonPath(item);
                                                      break;
                                                  }
                                                },
                                                itemBuilder: (context) => <PopupMenuEntry<String>>[
                                                  if (lesson
                                                      .contents
                                                      .isNotEmpty)
                                                    PopupMenuItem<String>(
                                                      value: 'contents',
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.list_rounded,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            'View Contents',
                                                            style:
                                                                GoogleFonts.poppins(),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  if (lesson
                                                      .questions
                                                      .isNotEmpty)
                                                    PopupMenuItem<String>(
                                                      value: 'quiz',
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                            Icons.quiz_outlined,
                                                            size: 18,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Text(
                                                            'Take Quiz',
                                                            style:
                                                                GoogleFonts.poppins(),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  PopupMenuItem<String>(
                                                    value: 'path',
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .account_tree_outlined,
                                                          size: 18,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          'Full Learning Path',
                                                          style:
                                                              GoogleFonts.poppins(),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CourseContentsScreen(course: widget.course),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Open Learning Path',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color:
                    ThemeData.estimateBrightnessForColor(theme.primaryColor) ==
                        Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonGridItem {
  final int index;
  final Lesson lesson;

  const _LessonGridItem({required this.index, required this.lesson});
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Badge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: theme.colorScheme.secondary.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.primaryColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
