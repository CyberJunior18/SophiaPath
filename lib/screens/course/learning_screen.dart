import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'course_info_screen.dart';
import 'course_sections_screen.dart';
import '../../models/course/course_info.dart';
import '../authentication/authService.dart';
import '../../widgets/course_card.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final AuthService _authService = AuthService();
  List<CourseInfo> coursesInfo = [];
  bool _isLoading = true;
  String? _errorMessage;
  int totalAvaialableCourses = 0;
  Set<int> _myRegisteredCourseIds = {};

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  List<String> comingSoon = [
    'AI',
    'Web Development',
    'Data Science',
    'Digital Marketing',
    'Graphic Design',
  ];
  Future<void> _loadCourses() async {
    final regs = await _authService.getMyRegistrations();
    _myRegisteredCourseIds = regs
        .where((r) => r['course']?['id'] != null)
        .map((r) => r['course']['id'] as int)
        .toSet();
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final fetchedCourses = await _authService.getAllCourses();
      final enrichedCourses = await _enrichCoursesWithProgress(fetchedCourses);
      if (!mounted) return;

      setState(() {
        coursesInfo = enrichedCourses;
        totalAvaialableCourses = coursesInfo.length;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final rawMessage = e.toString();
      final cleanMessage = rawMessage.startsWith('Exception: ')
          ? rawMessage.substring('Exception: '.length)
          : rawMessage;

      setState(() {
        coursesInfo = [];
        totalAvaialableCourses = coursesInfo.length;
        _isLoading = false;
        _errorMessage = cleanMessage;
      });
    }
  }

  Future<List<CourseInfo>> _enrichCoursesWithProgress(
    List<CourseInfo> fetchedCourses,
  ) async {
    return Future.wait(
      fetchedCourses.map((course) async {
        int doneCount = course.numberOfFinishedLessons;
        int totalLessons = course.totalLessons;

        try {
          if (course.id != null && course.id! > 0) {
            final gradesData = await _authService.getCourseLessonGrades(
              courseId: course.id!,
            );

            // Use backend-declared totalLessons when available; otherwise derive from grades list.
            if (totalLessons <= 0) {
              totalLessons = gradesData.length;
            }

            doneCount = gradesData.where((entry) {
              return entry['done'] == true;
            }).length;
          }
        } catch (_) {
          // Keep existing course progress if grade enrichment fails.
        }

        if (totalLessons <= 0) {
          if (course.lessons.isNotEmpty) {
            totalLessons = course.lessons.length;
          } else if (course.sections.isNotEmpty) {
            totalLessons = course.sections.length;
          }
        }

        return CourseInfo(
          id: course.id,
          title: course.title,
          description: course.description,
          numberOfFinishedLessons: doneCount,
          totalLessons: totalLessons,
          about: course.about,
          imageUrl: course.imageUrl,
          sections: course.sections,
          lessons: course.lessons,
        );
      }),
    );
  }

  int _getLessonsFinished(String courseTitle) {
    final index = coursesInfo.indexWhere(
      (course) => course.title == courseTitle,
    );
    if (index < 0) return 0;
    return coursesInfo[index].numberOfFinishedLessons;
  }

  int _getTotalLessons(String courseTitle) {
    final courseIndex = coursesInfo.indexWhere(
      (course) => course.title == courseTitle,
    );

    if (courseIndex >= 0) {
      final course = coursesInfo[courseIndex];
      if (course.totalLessons > 0) return course.totalLessons;
      if (course.lessons.isNotEmpty) return course.lessons.length;
      if (course.sections.isNotEmpty) return course.sections.length;
    }

    return 0;
  }

  IconData _getCourseIcon(String courseTitle) {
    switch (courseTitle.toLowerCase()) {
      case 'cybersecurity':
        return Icons.security;
      case 'mobile app development':
        return Icons.phone_android;
      case 'physics':
        return Icons.science;
      case 'philosophy':
        return Icons.psychology;
      case 'ai':
        return Icons.smart_toy;
      case 'web development':
        return Icons.code;
      case 'data science':
        return Icons.analytics;
      case 'digital marketing':
        return Icons.trending_up;
      case 'graphic design':
        return Icons.palette;
      default:
        return Icons.school;
    }
  }

  String? _getCourseAsset(String courseTitle) {
    final normalized = courseTitle.toLowerCase().replaceAll(' ', '');
    if (normalized.contains('cybersecurity')) {
      return 'assets/courses/cybersecurity.png';
    } else if (normalized.contains('computerscience')) {
      return 'assets/courses/computerScience.png';
    } else if (normalized.contains('philosophy')) {
      return 'assets/courses/philosophy.png';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && coursesInfo.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Available Courses Section
          if (coursesInfo.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Available Courses',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 16),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: screenWidth * 0.03,
                  crossAxisSpacing: screenWidth * 0.03,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final sampleCourse = coursesInfo[index];
                  final isRegistered = _myRegisteredCourseIds.contains(
                    sampleCourse.id,
                  );
                  final lessonsFinished = _getLessonsFinished(
                    sampleCourse.title,
                  );
                  final totalLessons = _getTotalLessons(sampleCourse.title);
                  final progress = totalLessons > 0
                      ? lessonsFinished / totalLessons
                      : 0.0;

                  return CourseCard(
                    course: sampleCourse,
                    assetImagePath: _getCourseAsset(sampleCourse.title),
                    isRegistered: isRegistered,
                    progress: progress,
                    lessonsFinished: lessonsFinished,
                    totalLessons: totalLessons,
                    fallbackIcon: _getCourseIcon(sampleCourse.title),
                    onTap: () {
                      if (isRegistered) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CourseSectionsGridScreen(course: sampleCourse),
                          ),
                        ).then((_) => _loadCourses());
                        return;
                      }

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CourseInfoScreen(course: sampleCourse),
                        ),
                      ).then((_) => _loadCourses());
                    },
                  );
                }, childCount: coursesInfo.length),
              ),
            ),
          ],

          // Coming Soon Section
          if (comingSoon.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.only(top: 16, bottom: 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Coming Soon',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: screenWidth * 0.03,
                  crossAxisSpacing: screenWidth * 0.03,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final comingSoonCourseTitle = comingSoon[index];
                  return CourseCard(
                    title: comingSoonCourseTitle,
                    assetImagePath: _getCourseAsset(comingSoonCourseTitle),
                    isRegistered: false,
                    isComingSoon: true,
                    fallbackIcon: _getCourseIcon(comingSoonCourseTitle),
                    onTap: null,
                  );
                }, childCount: comingSoon.length),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
