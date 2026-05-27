import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/course/lessonContent.dart' as lesson_content_model;
import '../../models/course/lesson.dart' as lesson_model;
import '../../models/course/course_info.dart';
import '../../services/course/scores_repo.dart';
import '../Lessons/mcq_test_screen.dart';
import 'lesson_content_screen.dart';
import '../../services/course/user_stats_service.dart';

class LessonPathScreen extends StatefulWidget {
  final CourseInfo course;
  final CourseInfo? originalCourse;
  final int initialLessonPageIndex;

  const LessonPathScreen({
    super.key,
    required this.course,
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
  int _currentLessonPageIndex = 0;
  List<lesson_model.Section> lessons = [];
  List<List<lesson_model.Section>> lessonsByPages = [];
  String? _firestoreCourseId;
  int _completedLessons = 0;
  bool _isLoading = true;
  final UserStatsService _statsService = UserStatsService();

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

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);

    final sourceCourse = widget.originalCourse ?? widget.course;
    lessons = _findCourseLessons(sourceCourse);
    lessonsByPages = _buildLessonPages(lessons);

    if (lessonsByPages.isNotEmpty) {
      _currentLessonPageIndex = widget.initialLessonPageIndex.clamp(
        0,
        lessonsByPages.length - 1,
      );
    }

    debugPrint(
      '🔍 LessonPathScreen: Found ${lessons.length} lessons in ${lessonsByPages.length} pages',
    );
    for (var lesson in lessons) {
      debugPrint('  - ${lesson.title}');
    }

    await _findDatabaseCourse();

    await _loadScores();

    unlocked = List.generate(lessons.length, (index) {
      return index == 0 || index <= _completedLessons;
    });

    setState(() => _isLoading = false);
  }

  List<lesson_model.Section> _findCourseLessons(CourseInfo course) {
    if (course.sections.isNotEmpty) {
      final sortedLessons = List<lesson_model.Section>.from(course.sections)
        ..sort((a, b) => (a.id ?? 0).compareTo(b.id ?? 0));
      return sortedLessons;
    }

    if (course.lessons.isNotEmpty) {
      return course.lessons.map((section) {
        return lesson_model.Section(
          title: section.title,
          done: false,
          description: section.description,
          questions: [
            lesson_content_model.MCQ(
              question: 'What is ${section.title}?',
              options: [
                lesson_content_model.Answer(answer: 'Correct Answer'),
                lesson_content_model.Answer(answer: 'Wrong Answer 1'),
                lesson_content_model.Answer(answer: 'Wrong Answer 2'),
                lesson_content_model.Answer(answer: 'Wrong Answer 3'),
              ],
            ),
          ],
        );
      }).toList();
    }

    return const [];
  }

  List<List<lesson_model.Section>> _buildLessonPages(
    List<lesson_model.Section> allLessons,
  ) {
    final pages = <List<lesson_model.Section>>[];
    for (final lesson in allLessons) {
      final sortedContents = List.from(lesson.contents)
        ..sort((a, b) => (a.orderIndex ?? 0).compareTo(b.orderIndex ?? 0));

      if (sortedContents.isNotEmpty) {
        final contentLessons = sortedContents.map((content) {
          return lesson_model.Section(
            id: lesson.id,
            title: (content.partTitle ?? '').isNotEmpty
                ? (content.partTitle ?? '')
                : lesson.title,
            description: lesson.description,
            done: lesson.done,
            questions: content.extractQuestions() ?? [],
            contents: [content],
          );
        }).toList();
        pages.add(contentLessons);
      } else {
        pages.add([lesson]);
      }
    }
    return pages;
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

  Future<void> startTest(lesson_model.Section lesson, int pageIndex) async {
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
    debugPrint("\n Lessons info : ${lesson.toString()}");
    final score = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => lesson.questions.isNotEmpty
            ? McqTestScreen(
                section: lesson.title,
                questions: lesson.questions,
                courseId: courseIndex,
                totalLessons: lessons.length,
                lessonId: lesson.id,
                onTestCompleted: () {},
              )
            : LessonContentScreen(
                lesson: lesson,
                courseId: widget.course.id,
                sectionId: widget.course.id,
                lessonId: lesson.id,
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
            lesson.title,
          );

          if (score == 100) {
            await _statsService.recordPerfectScore();
          }

          if (score >= 70) {
            final correctCount = (lesson.questions.length * (score / 100))
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.course.title, style: TextStyle(fontSize: 15)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final nodeSpacing = 120.0;
    final currentPageLessons = lessonsByPages[_currentLessonPageIndex];
    final totalNodesInPage = currentPageLessons.length;
    final currentScores = _normalizedScores(totalNodesInPage);
    final currentUnlocked = _normalizedUnlocked(totalNodesInPage);

    // build node widgets and compute exact Y positions so painter can follow
    final List<Widget> nodeWidgets = [];
    final List<double> nodeCentersY = [];
    final List<bool> connectNext = [];
    final List<_ChapterBlock> chapterBlocks = [];
    String? lastChapter;
    String? prevChapter;
    double extraGap = 0;
    const double nodeSize = 80.0;
    double contentHeight = 0;

    for (int i = 0; i < totalNodesInPage; i++) {
      final chapterName = currentPageLessons[i].contents[0].chapterName;

      if (chapterName != lastChapter) {
        lastChapter = chapterName;
        if (i == 0) {
          extraGap = 40;
        } else {
          extraGap += 120; // space before chapter text
        }
        chapterBlocks.add(
          _ChapterBlock(
            chapterName: chapterName,
            startIndex: i,
            top: i * nodeSpacing + extraGap - 30,
          ),
        );

        extraGap += 60;
      }

      final nodeTop = i * nodeSpacing + extraGap;
      nodeCentersY.add(nodeTop + nodeSize / 2);
      contentHeight = max(contentHeight, nodeTop + nodeSize + 20);

      if (i > 0) {
        connectNext.add(prevChapter == chapterName);
      }
      prevChapter = chapterName;

      nodeWidgets.add(
        Positioned(
          top: nodeTop,
          left: i % 2 == 0
              ? MediaQuery.of(context).size.width * 0.18 - 17
              : MediaQuery.of(context).size.width * 0.62 - 17,
          child: MouseRegion(
            cursor: currentUnlocked[i]
                ? SystemMouseCursors.click
                : SystemMouseCursors.basic,
            child: GestureDetector(
              onTap: currentUnlocked[i]
                  ? () => startTest(currentPageLessons[i], i)
                  : null,
              child: CourseNode(
                title: currentPageLessons[i].title,
                index: i + 1,
                locked: !currentUnlocked[i],
                percentage: currentScores[i],
                isCompleted: i < _completedLessons,
                theme: theme,
              ),
            ),
          ),
        ),
      );
    }

    final pageHeight = max(
      contentHeight + 40,
      totalNodesInPage * nodeSpacing + 30,
    );

    for (int i = 0; i < chapterBlocks.length; i++) {
      final chapterStart = chapterBlocks[i].top;
      final nextChapterStart = i + 1 < chapterBlocks.length
          ? chapterBlocks[i + 1].top
          : pageHeight;
      final isChapterLocked = !currentUnlocked[chapterBlocks[i].startIndex];

      nodeWidgets.add(
        Positioned(
          top: chapterStart,
          left: 0,
          right: 0,
          bottom: pageHeight - nextChapterStart,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(107, 114, 114, 114),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white),
                ),
                child: Text(
                  chapterBlocks[i].chapterName,
                  style: GoogleFonts.poppins(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isChapterLocked)
                Positioned(
                  top: 52,
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: const Center(
                      child: Icon(Icons.lock, color: Colors.white, size: 30),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          child: Text(
            lessons[_currentLessonPageIndex].title,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
        ),
        backgroundColor: const Color(0xFF3D5CFF),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Progress synced to cloud!')),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
        ],
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
  final int percentage;
  final bool isCompleted;
  final ThemeData theme;

  const CourseNode({
    super.key,
    required this.title,
    required this.index,
    required this.locked,
    this.percentage = 0,
    this.isCompleted = false,
    required this.theme,
  });

  @override
  State<CourseNode> createState() => _CourseNodeState();
}

class _CourseNodeState extends State<CourseNode> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final nodeSize = 80.0;
    final isDark = widget.theme.brightness == Brightness.dark;

    Color nodeColor;
    Color borderColor;
    Color textColor = Colors.white;

    if (widget.locked) {
      nodeColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
      borderColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
      textColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    } else if (widget.isCompleted) {
      nodeColor = const Color(0xFF4CAF50);
      borderColor = const Color(0xFF388E3C);
    } else {
      nodeColor = const Color(0xFF3D5CFF);
      borderColor = const Color(0xFF1E40AF);
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

            Container(
              padding: EdgeInsets.all(10),
              width: nodeSize,
              height: nodeSize,
              decoration: BoxDecoration(
                color: nodeColor,
                shape: BoxShape.circle,
                border: Border.all(color: borderColor, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: widget.locked ? 0.1 : 0.25,
                    ),
                    blurRadius: 6,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: widget.locked
                    ? Icon(Icons.lock, color: textColor, size: 24)
                    : Text(
                        widget.index.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
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
              if (widget.isCompleted && !widget.locked)
                Text(
                  'Completed',
                  style: GoogleFonts.poppins(
                    fontSize: 9,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChapterBlock {
  final String chapterName;
  final int startIndex;
  final double top;

  const _ChapterBlock({
    required this.chapterName,
    required this.startIndex,
    required this.top,
  });
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
