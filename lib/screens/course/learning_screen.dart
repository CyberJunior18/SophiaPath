import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'course_info_screen.dart';
import 'course_lessons_grid_screen.dart';
import '../../models/course/course_info.dart';
import '../authentication/authService.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
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
    'Artificial Intelligence',
    'Web Development',
    'Data Science',
    'Digital Marketing',
    'Graphic Design',
    'Business Management',
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

  bool _isCourseRegistered(String courseTitle) {
    return coursesInfo.any((course) => course.title == courseTitle);
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
      case 'artificial intelligence':
        return Icons.smart_toy;
      case 'web development':
        return Icons.code;
      case 'data science':
        return Icons.analytics;
      case 'digital marketing':
        return Icons.trending_up;
      case 'graphic design':
        return Icons.palette;
      case 'business management':
        return Icons.business;
      default:
        return Icons.school;
    }
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
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: 8,
      ),
      child: GridView.builder(
        physics: const BouncingScrollPhysics(),
        itemCount: coursesInfo.length + comingSoon.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: screenWidth * 0.03,
          crossAxisSpacing: screenWidth * 0.03,
          childAspectRatio: 1.03,
        ),
        itemBuilder: (context, index) {
          final bool isAvailable = index < coursesInfo.length;
          final isDark = theme.brightness == Brightness.dark;

          if (isAvailable) {
            final sampleCourse = coursesInfo[index];
            final isRegistered = _myRegisteredCourseIds.contains(
              sampleCourse.id,
            );
            final lessonsFinished = _getLessonsFinished(sampleCourse.title);
            final totalLessons = _getTotalLessons(sampleCourse.title);
            final progress = totalLessons > 0
                ? lessonsFinished / totalLessons
                : 0.0;

            return InkWell(
              onTap: () {
                // If user is registered, go straight to course sections grid
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

                // otherwise show course info screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseInfoScreen(course: sampleCourse),
                  ),
                ).then((_) => _loadCourses());
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: EdgeInsets.all(screenWidth * 0.04),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(
                      alpha: isDark ? 0.1 : 0.15,
                    ),
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.025),
                          decoration: BoxDecoration(
                            color: theme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            _getCourseIcon(sampleCourse.title),
                            color: theme.primaryColor,
                            size: screenWidth * 0.05,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.02),
                        Expanded(
                          child: Text(
                            sampleCourse.title,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                              fontSize: 14,
                            ),
                            softWrap: true,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    if (isRegistered)
                      Column(
                        children: [
                          LinearProgressIndicator(
                            value: progress,
                            backgroundColor: theme.colorScheme.outline
                                .withValues(alpha: 0.2),
                            color: theme.primaryColor,
                            borderRadius: BorderRadius.circular(4),
                            minHeight: screenWidth * 0.01,
                          ),
                          SizedBox(height: screenWidth * 0.015),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$lessonsFinished/$totalLessons',
                                style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.032,
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.032,
                                  fontWeight: FontWeight.w600,
                                  color: theme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      )
                    else
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.03,
                            vertical: screenWidth * 0.02,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.primaryColor.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'Start',
                              style: GoogleFonts.poppins(
                                fontSize: screenWidth * 0.038,
                                color: theme.primaryColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            );
          }

          final comingSoonCourseTitle = comingSoon[index - coursesInfo.length];

          return InkWell(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.orange.withValues(alpha: 0.1)
                    : Colors.orange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(
                    alpha: isDark ? 0.1 : 0.15,
                  ),
                  width: 1,
                ),
                boxShadow: isDark
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(screenWidth * 0.025),
                        decoration: BoxDecoration(
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _getCourseIcon(comingSoonCourseTitle),
                          color: theme.primaryColor,
                          size: screenWidth * 0.05,
                        ),
                      ),
                      SizedBox(width: screenWidth * 0.02),
                      Expanded(
                        child: Text(
                          comingSoonCourseTitle,
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            fontSize: 14,
                          ),
                          softWrap: true,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  Center(
                    child: Text(
                      'Coming Soon',
                      style: GoogleFonts.poppins(
                        fontSize: screenWidth * 0.038,
                        color: theme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: 1),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
