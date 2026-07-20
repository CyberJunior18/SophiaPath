import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/models/course/lesson.dart' as lesson_model;
import 'course_sections_screen.dart';
import '../../models/course/course_info.dart';
import '../authentication/authService.dart';
import '../../services/course/scores_repo.dart';
import 'package:sophia_path/screens/authentication/login.dart';

class CourseInfoScreen extends StatefulWidget {
  final CourseInfo course;
  const CourseInfoScreen({super.key, required this.course});

  @override
  State<CourseInfoScreen> createState() => _CourseInfoScreenState();
}

class _CourseInfoScreenState extends State<CourseInfoScreen> {
  bool _isLoading = false;
  bool _isCourseRegistered = false;
  List<lesson_model.Section> sectionsInfo = [];
  late int courseIndex = 0;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    courseIndex = (widget.course.id ?? 1) - 1;
    sectionsInfo = widget.course.sections;
    _checkIfCourseRegistered();
  }

  Future<void> _checkIfCourseRegistered() async {
    setState(() => _isLoading = true);

    try {
      final registrations = await _authService.getMyRegistrations();
      final courseId = widget.course.id;

      final matched = registrations.where((registration) {
        final course = registration['course'];
        if (course is Map) {
          final registeredCourseId = course['id'];
          if (courseId != null && registeredCourseId != null) {
            return registeredCourseId.toString() == courseId.toString();
          }

          final registeredTitle = course['title']?.toString() ?? '';
          return registeredTitle == widget.course.title;
        }

        return false;
      }).toList();

      if (!mounted) return;
      setState(() {
        _isCourseRegistered = matched.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCourseRegistered = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _registerCourse() async {
    if (_isCourseRegistered) return;

    setState(() => _isLoading = true);

    try {
      final courseId = widget.course.id;
      if (courseId == null) {
        throw Exception('Missing course id');
      }

      final result = await _authService.registerInCourse(courseId: courseId);
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Failed to register course');
      }

      setState(() {
        _isCourseRegistered = true;
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course registered successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error registering course: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _unregisterCourse() async {
    if (!_isCourseRegistered) return;
    await ScoresRepository.resetCourseScores(courseIndex);
    setState(() => _isLoading = true);

    try {
      final courseId = widget.course.id;
      if (courseId == null) {
        throw Exception('Missing course id');
      }

      final result = await _authService.unregisterFromCourse(
        courseId: courseId,
      );
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Failed to unregister course');
      }

      setState(() {
        _isCourseRegistered = false;
        _isLoading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Course unregistered!'),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateToLessonPath() async {
    final token = await AuthStorage.getToken();
    if (token == null) {
      if (!mounted) return;
      _showLoginPrompt();
      return;
    }

    if (!_isCourseRegistered) {
      _registerCourse().then((_) {
        if (!mounted) return;
        if (_isCourseRegistered) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CourseSectionsGridScreen(course: widget.course),
            ),
          );
        }
      });
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CourseSectionsGridScreen(course: widget.course),
        ),
      );
    }
  }

  void _showLoginPrompt() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Login Required', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
          'Please log in or register to enroll in courses and save your progress.',
          style: GoogleFonts.poppins(),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoginScreen(onToggleTheme: () {}),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Log In', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.textTheme.bodyLarge?.color),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.course.title,
          style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge?.color),
        ),
        actions: [
          if (_isCourseRegistered)
            IconButton(
              icon: Icon(Icons.delete_outlined, color: Colors.red),
              onPressed: _isLoading ? null : _unregisterCourse,
              tooltip: 'Unregister from course',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Builder(
                      builder: (context) {
                        final assetPath = _getCourseAsset(widget.course.title);
                        final fallback = _getCourseIcon(widget.course.title);
                        final hasNetwork = widget.course.imageUrl.isNotEmpty;

                        Widget fallbackWidget = Container(
                          height: 220,
                          width: 220,
                          color: theme.primaryColor.withValues(alpha: 0.1),
                          child: Center(
                            child: Icon(
                              fallback,
                              size: 120,
                              color: theme.primaryColor,
                            ),
                          ),
                        );

                        if (assetPath != null) {
                          return Image.asset(
                            assetPath,
                            height: 220,
                            width: 220,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => fallbackWidget,
                          );
                        } else if (hasNetwork) {
                          return Image.network(
                            widget.course.imageUrl,
                            height: 220,
                            width: 220,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => fallbackWidget,
                          );
                        } else {
                          return fallbackWidget;
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    "About the course",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.course.about,
                    style: GoogleFonts.poppins(
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    "Course Sections",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (courseIndex >= 0 && courseIndex < sectionsInfo.length)
                    ...sectionsInfo.map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            children: [
                              Builder(
                                builder: (context) {
                                  final iconPath = _getSectionIconPath(
                                    section.title,
                                  );
                                  if (iconPath != null) {
                                    return Image.asset(
                                      iconPath,
                                      height: 32,
                                      width: 32,
                                      fit: BoxFit.contain,
                                    );
                                  }
                                  return Icon(
                                    Icons.folder_outlined,
                                    size: 32,
                                    color: theme.primaryColor,
                                  );
                                },
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  section.title,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: theme.textTheme.bodyLarge?.color,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${section.contents.length} Lessons',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color:
                                      (theme.textTheme.bodyLarge?.color ??
                                              theme.colorScheme.onSurface)
                                          .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    Text(
                      'No sections available',
                      style: GoogleFonts.poppins(
                        color:
                            (theme.textTheme.bodyLarge?.color ??
                                    theme.colorScheme.onSurface)
                                .withValues(alpha: 0.5),
                      ),
                    ),

                  // Section titles come from course.sections; course.lessons
                  // remains the flattened lesson path data.
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _navigateToLessonPath,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        disabledBackgroundColor: Colors.grey,
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              _isCourseRegistered
                                  ? "Continue Learning"
                                  : "Register Now",
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    ThemeData.estimateBrightnessForColor(
                                          theme.primaryColor,
                                        ) ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                              ),
                            ),
                    ),
                  ),

                  if (_isCourseRegistered)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Already registered',
                            style: GoogleFonts.poppins(
                              color: Colors.green,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
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
}
