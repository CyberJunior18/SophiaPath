import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/models/data.dart';
import 'package:sophia_path/models/course/question.dart';

import '../../models/course/lesson.dart';
import '../../services/course/database_helper.dart';
import '../../models/course/course_info.dart';
import '../../services/course/scores_repo.dart';
import 'test_screen.dart';
import '../../services/course/user_stats_service.dart';

class LessonPathScreen extends StatefulWidget {
  final CourseInfo course;
  final CourseInfo? originalCourse;

  const LessonPathScreen({
    super.key,
    required this.course,
    this.originalCourse,
  });

  @override
  State<LessonPathScreen> createState() => _LessonPathScreenState();
}

class _LessonPathScreenState extends State<LessonPathScreen> {
  List<int> courseScores = [];
  int courseIndex = 0;
  late List<bool> unlocked;
  late List<Lesson> lessons;
  final DatabaseService _dbService = DatabaseService();
  int? _databaseCourseId;
  int _completedLessons = 0;
  bool _isLoading = true;
  final UserStatsService _statsService = UserStatsService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ✅ Get current user ID
  String? get _userId => _auth.currentUser?.uid;
  Future<void> _loadScores() async {
    final int currentCourseIndex = coursesInfo.indexOf(widget.course);
    courseIndex = currentCourseIndex;

    await ScoresRepository.initializeScores(coursesInfo.length, lessons.length);

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

  // ✅ NEW: Sync lesson progress to Firebase
  Future<void> _syncProgressToFirebase(
    int courseIndex,
    int completedLessons,
    List<int> scores,
  ) async {
    String? uid = _userId;
    if (uid == null) return;

    try {
      // Convert scores list to a map for Firebase
      Map<String, int> scoresMap = {};
      for (int i = 0; i < scores.length; i++) {
        scoresMap[i.toString()] = scores[i];
      }

      await _firestore.collection('Users').doc(uid).update({
        'coursesProgress.$courseIndex': completedLessons,
        'lessonScores.$courseIndex': scoresMap,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print(
        '✅ Synced progress to Firebase: Course $courseIndex, Lessons: $completedLessons',
      );
    } catch (e) {
      print('❌ Error syncing to Firebase: $e');
    }
  }

  // ✅ NEW: Load progress from Firebase
  Future<void> _loadProgressFromFirebase() async {
    String? uid = _userId;
    if (uid == null) return;

    try {
      DocumentSnapshot userDoc = await _firestore
          .collection('Users')
          .doc(uid)
          .get();

      if (userDoc.exists) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;

        // Load course progress
        if (data['coursesProgress'] != null) {
          Map<String, dynamic> progress = data['coursesProgress'];
          int firebaseCompleted = progress[courseIndex.toString()] ?? 0;

          // If Firebase has more progress, update local
          if (firebaseCompleted > _completedLessons) {
            setState(() {
              _completedLessons = firebaseCompleted;
            });

            // Update unlocked lessons
            for (int i = 0; i < lessons.length; i++) {
              if (i < _completedLessons) {
                unlocked[i] = true;
              }
            }
          }
        }

        // Load lesson scores
        if (data['lessonScores'] != null &&
            data['lessonScores'][courseIndex.toString()] != null) {
          Map<String, dynamic> scoresMap =
              data['lessonScores'][courseIndex.toString()];
          List<int> firebaseScores = List.filled(lessons.length, 0);

          scoresMap.forEach((key, value) {
            int index = int.tryParse(key) ?? -1;
            if (index >= 0 && index < lessons.length) {
              firebaseScores[index] = value as int;
            }
          });

          // Update local scores if Firebase has higher scores
          setState(() {
            for (int i = 0; i < lessons.length; i++) {
              if (firebaseScores[i] > courseScores[i]) {
                courseScores[i] = firebaseScores[i];
              }
            }
          });
        }
      }
    } catch (e) {
      print('❌ Error loading from Firebase: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() => _isLoading = true);

    if (widget.originalCourse != null) {
      lessons = _findCourseLessons(widget.originalCourse!.title);
    } else {
      lessons = _findCourseLessons(widget.course.title);
    }

    await _findDatabaseCourse();

    await _loadScores();

    // ✅ NEW: Load progress from Firebase
    await _loadProgressFromFirebase();

    unlocked = List.generate(lessons.length, (index) {
      return index == 0 || index <= _completedLessons;
    });

    setState(() => _isLoading = false);
  }

  List<Lesson> _findCourseLessons(String courseTitle) {
    final courseIndex = coursesInfo.indexWhere(
      (course) => course.title == courseTitle,
    );

    if (courseIndex >= 0 && courseIndex < lessonsInfo.length) {
      return lessonsInfo[courseIndex];
    }
    return widget.course.sections.map((section) {
      return Lesson(
        title: section,
        done: false,
        questions: [
          Question(
            question: "What is $section?",
            answers: [
              Answer(answer: "Correct Answer"),
              Answer(answer: "Wrong Answer 1"),
              Answer(answer: "Wrong Answer 2"),
              Answer(answer: "Wrong Answer 3"),
            ],
          ),
        ],
      );
    }).toList();
  }

  Future<void> _findDatabaseCourse() async {
    try {
      final allCourses = await _dbService.getCourses();

      final databaseCourse = allCourses.firstWhere(
        (course) => course.title == widget.course.title,
        orElse: () {
          return Course(
            title: widget.course.title,
            courseIndex: 0,
            lessonsFinished: 0,
          );
        },
      );

      _databaseCourseId = databaseCourse.id;
      _completedLessons = databaseCourse.lessonsFinished;
    } catch (e) {
      _completedLessons = 0;
    }
  }

  Future<void> startTest(int index) async {
    if (index >= lessons.length || !unlocked[index]) return;

    final lesson = lessons[index];

    final isFirstLessonOfFirstCourse = index == 0 && _completedLessons == 0;

    DateTime? startTime;
    if (isFirstLessonOfFirstCourse) {
      startTime = DateTime.now();
    }

    final score = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => TestScreen(
          section: lesson.title,
          questions: lesson.questions,
          courseId: _databaseCourseId ?? 0,
          totalLessons: lessons.length,
          onTestCompleted: () {},
        ),
      ),
    );

    if (score != null && mounted) {
      final updatedScores = List<int>.from(courseScores);
      if (score > updatedScores[index]) {
        updatedScores[index] = score;
      }

      final isPassingScore = score >= 70;
      final shouldUnlockNext = isPassingScore && index + 1 < lessons.length;

      setState(() {
        courseScores = updatedScores;

        if (shouldUnlockNext) {
          final updatedUnlocked = List<bool>.from(unlocked);
          updatedUnlocked[index + 1] = true;
          unlocked = updatedUnlocked;
        }
      });

      final currentCourseIndex = coursesInfo.indexOf(widget.course);
      await ScoresRepository.addScore(currentCourseIndex, index, score);

      if (isPassingScore) {
        final newCompletedCount = index + 1;

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
          await _syncProgressToFirebase(
            currentCourseIndex,
            _completedLessons,
            updatedScores,
          );
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
      if (_databaseCourseId != null) {
        final course = await _dbService.getCourseById(_databaseCourseId!);
        if (course != null) {
          final updatedCourse = Course(
            id: course.id,
            title: course.title,
            courseIndex: course.courseIndex,
            lessonsFinished: completedLessons,
          );
          await _dbService.updateCourse(updatedCourse);
        }
      } else {
        final newCourse = Course(
          title: widget.course.title,
          courseIndex: 0,
          lessonsFinished: completedLessons,
        );
        final newId = await _dbService.insertCourse(newCourse);
        _databaseCourseId = newId;
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
    final totalLessons = lessons.length;

    return Scaffold(
      appBar: AppBar(
        title: FittedBox(
          child: Text(
            widget.course.title,
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
              final currentCourseIndex = coursesInfo.indexOf(widget.course);
              await _syncProgressToFirebase(
                currentCourseIndex,
                _completedLessons,
                courseScores,
              );
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
                  '$_completedLessons/$totalLessons',
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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          height: totalLessons * nodeSpacing + 30,
          child: Padding(
            padding: const EdgeInsets.only(top: 20.0),
            child: Stack(
              children: [
                CustomPaint(
                  size: Size(double.infinity, totalLessons * nodeSpacing),
                  painter: LessonPathPainter(
                    totalLessons,
                    unlocked: unlocked,
                    theme: theme,
                  ),
                ),
                for (int i = 0; i < totalLessons; i++)
                  Positioned(
                    top: i * nodeSpacing,
                    left: i % 2 == 0
                        ? MediaQuery.of(context).size.width * 0.18 - 17
                        : MediaQuery.of(context).size.width * 0.62 - 17,
                    child: MouseRegion(
                      cursor: unlocked[i]
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: GestureDetector(
                        onTap: unlocked[i] ? () => startTest(i) : null,
                        child: CourseNode(
                          title: lessons[i].title,
                          index: i + 1,
                          locked: !unlocked[i],
                          percentage: courseScores[i],
                          isCompleted: i < _completedLessons,
                          theme: theme,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
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

class LessonPathPainter extends CustomPainter {
  final int nodeCount;
  final List<bool> unlocked;
  final ThemeData theme;

  LessonPathPainter(
    this.nodeCount, {
    required this.unlocked,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final spacing = size.height / nodeCount;
    final isDark = theme.brightness == Brightness.dark;

    for (int i = 0; i < nodeCount - 1; i++) {
      final isSegmentUnlocked = unlocked[i] && unlocked[i + 1];

      final paint = Paint()
        ..color = isSegmentUnlocked
            ? const Color(0xFF3D5CFF).withValues(alpha: 0.7)
            : (isDark ? Colors.grey[700]! : Colors.grey[300]!)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSegmentUnlocked ? 3.5 : 2.5
        ..strokeCap = StrokeCap.round;

      final startX = i % 2 == 0
          ? size.width * 0.18 + 40
          : size.width * 0.62 + 40;
      final startY = i * spacing + 40;

      final endX = (i + 1) % 2 == 0
          ? size.width * 0.18 + 40
          : size.width * 0.62 + 40;
      final endY = (i + 1) * spacing + 40;

      final controlX1 = startX + (endX - startX) * 0.5;
      final controlY1 = startY + spacing * 0.3;
      final controlX2 = startX + (endX - startX) * 0.5;
      final controlY2 = startY + spacing * 0.7;

      final path = Path();
      path.moveTo(startX, startY);
      path.cubicTo(controlX1, controlY1, controlX2, controlY2, endX, endY);

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
    return oldDelegate.unlocked != unlocked || oldDelegate.theme != theme;
  }
}
