import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/screens/course/course_info_screen.dart';
import 'package:sophia_path/models/data.dart';
import '../../services/course/database_helper.dart';

class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  List<Course> _registeredCourses = [];
  bool _isLoading = true;
  final DatabaseService _databaseService = DatabaseService();
  final Map<String, int> _courseProgress = {};
  int totalAvaialableCourses = coursesInfo.length;
  @override
  void initState() {
    super.initState();
    _loadRegisteredCourses();
  }

  List<String> comingSoon = [
    'Artificial Intelligence',
    'Web Development',
    'Data Science',
    'Digital Marketing',
    'Graphic Design',
    'Business Management',
  ];
  Future<void> _loadRegisteredCourses() async {
    setState(() => _isLoading = true);
    try {
      final courses = await _databaseService.getCourses();
      for (var course in courses) {
        _courseProgress[course.title] = course.lessonsFinished;
      }
      setState(() {
        _registeredCourses = courses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  bool _isCourseRegistered(String courseTitle) {
    return _registeredCourses.any((course) => course.title == courseTitle);
  }

  int _getLessonsFinished(String courseTitle) {
    return _courseProgress[courseTitle] ?? 0;
  }

  int _getTotalLessons(String courseTitle) {
    final courseIndex = coursesInfo.indexWhere(
      (course) => course.title == courseTitle,
    );

    if (courseIndex >= 0 && courseIndex < lessonsInfo.length) {
      return lessonsInfo[courseIndex].length;
    }

    final course = coursesInfo.firstWhere(
      (course) => course.title == courseTitle,
      orElse: () => coursesInfo.first,
    );

    return course.sections.length;
  }

  IconData _getCourseIcon(String courseTitle) {
    switch (courseTitle.toLowerCase()) {
      case 'cybersecurity':
        return Icons.security;
      case 'mobile development':
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

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : Padding(
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
                bool isAvailable = index < totalAvaialableCourses;
                final isDark = theme.brightness == Brightness.dark;

                dynamic sampleCourse;
                sampleCourse = isAvailable ? coursesInfo[index] : null;

                final isRegistered = isAvailable
                    ? _isCourseRegistered(sampleCourse.title)
                    : null;
                final lessonsFinished = isAvailable
                    ? _getLessonsFinished(sampleCourse.title)
                    : null;
                final totalLessons = isAvailable
                    ? _getTotalLessons(sampleCourse.title)
                    : null;
                final progress = isAvailable
                    ? (totalLessons! > 0
                          ? lessonsFinished! / totalLessons
                          : 0.0)
                    : null;

                final comingSoonCourseTitle = isAvailable
                    ? null
                    : comingSoon[index - coursesInfo.length];

                return isAvailable
                    ? InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CourseInfoScreen(course: sampleCourse),
                            ),
                          ).then((_) => _loadRegisteredCourses());
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
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
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
                                    padding: EdgeInsets.all(
                                      screenWidth * 0.025,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF3D5CFF,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getCourseIcon(sampleCourse.title),
                                      color: const Color(0xFF3D5CFF),
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
                                        fontSize: 9.5,
                                      ),
                                      softWrap: true,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),

                              if (isRegistered!)
                                Column(
                                  children: [
                                    LinearProgressIndicator(
                                      value: progress,
                                      backgroundColor: theme.colorScheme.outline
                                          .withValues(alpha: 0.2),
                                      color: const Color(0xFF3D5CFF),
                                      borderRadius: BorderRadius.circular(4),
                                      minHeight: screenWidth * 0.01,
                                    ),
                                    SizedBox(height: screenWidth * 0.015),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          '$lessonsFinished/$totalLessons',
                                          style: GoogleFonts.poppins(
                                            fontSize: screenWidth * 0.032,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                        Text(
                                          '${(progress! * 100).toInt()}%',
                                          style: GoogleFonts.poppins(
                                            fontSize: screenWidth * 0.032,
                                            fontWeight: FontWeight.w600,
                                            color: const Color(0xFF3D5CFF),
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
                                    color: isDark
                                        ? const Color(0xFF18193C)
                                        : const Color(0xFFE6F2FF),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF3D5CFF,
                                      ).withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Start',
                                      style: GoogleFonts.poppins(
                                        fontSize: screenWidth * 0.038,
                                        color: const Color(0xFF3D5CFF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : InkWell(
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
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ]
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.05,
                                      ),
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
                                    padding: EdgeInsets.all(
                                      screenWidth * 0.025,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF3D5CFF,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      _getCourseIcon(comingSoonCourseTitle!),
                                      color: const Color(0xFF3D5CFF),
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
                                        fontSize: 9.5,
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
                                    color: Color(0xFF5D6CFF),
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
