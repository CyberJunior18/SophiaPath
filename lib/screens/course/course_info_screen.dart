import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/models/course/lesson.dart' as lesson_model;
import 'course_lessons_grid_screen.dart';
import '../../models/course/course_info.dart';
import '../authentication/authService.dart';
import '../../services/course/scores_repo.dart';

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

  void _navigateToLessonPath() {
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.textTheme.bodyLarge!.color!,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.course.title,
          style: GoogleFonts.poppins(color: theme.textTheme.bodyLarge!.color!),
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
                    child: widget.course.imageUrl.startsWith('http')
                        ? Image.network(
                            widget.course.imageUrl,
                            height: 180,
                            width: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: 180,
                                width: 100,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.book,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          )
                        : Image.network(
                            widget.course.imageUrl,
                            height: 180,
                            width: 100,
                            fit: BoxFit.cover,
                          ),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    "About the course",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge!.color!,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    widget.course.about,
                    style: GoogleFonts.poppins(
                      color: theme.textTheme.bodyLarge!.color!,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.menu_book,
                        label: 'Sections',
                        value: sectionsInfo.length.toString(),
                      ),
                      _buildStatItem(
                        icon: Icons.schedule,
                        label: 'Duration',
                        value: '${sectionsInfo.length * 30} min',
                      ),
                      _buildStatItem(
                        icon: Icons.people,
                        label: 'Level',
                        value: 'Beginner',
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  Text(
                    "Course Sections",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.textTheme.bodyLarge!.color!,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (courseIndex >= 0 && courseIndex < sectionsInfo.length)
                    ...sectionsInfo.map(
                      (section) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 18,
                              color: _isCourseRegistered
                                  ? theme.primaryColor
                                  : Colors.grey,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    section.title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w600,
                                      color: theme.textTheme.bodyLarge!.color!,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    section.description,
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: theme.textTheme.bodyLarge!.color!
                                          .withValues(alpha: 0.6),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(
                      'No sections available',
                      style: GoogleFonts.poppins(
                        color: theme.textTheme.bodyLarge!.color!.withValues(
                          alpha: 0.5,
                        ),
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
                                color: ThemeData.estimateBrightnessForColor(theme.primaryColor) == Brightness.dark
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

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 30, color: theme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
