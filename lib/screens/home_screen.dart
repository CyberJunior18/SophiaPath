import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'course/lesson_path_screen.dart';
import '../models/course/course_info.dart';
import 'authentication/authService.dart';

class ActiveSectionData {
  final CourseInfo course;
  final int sectionId;
  final String sectionTitle;
  final Map<String, dynamic>? pastLesson;
  final Map<String, dynamic>? currentLesson;
  final Map<String, dynamic>? nextLesson;

  ActiveSectionData({
    required this.course,
    required this.sectionId,
    required this.sectionTitle,
    this.pastLesson,
    this.currentLesson,
    this.nextLesson,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _errorMessage;

  List<ActiveSectionData> _activeSections = [];

  @override
  void initState() {
    super.initState();
    _loadActiveSections();
  }

  Future<void> _loadActiveSections() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final regs = await _authService.getMyRegistrations();
      final registeredCourseIds = regs
          .where((r) => r['course']?['id'] != null)
          .map((r) => r['course']['id'] as int)
          .toSet();

      final fetchedCourses = await _authService.getAllCourses();
      
      List<ActiveSectionData> activeList = [];

      for (final course in fetchedCourses) {
        if (registeredCourseIds.contains(course.id)) {
          try {
            final gradesData = await _authService.getCourseLessonGrades(courseId: course.id!);
            
            for (final section in course.sections) {
              if (section.id == null) continue;
              
              final sectionLessonsRaw = await _authService.getSectionLessons(
                courseId: course.id!,
                sectionId: section.id!,
              );
              
              if (sectionLessonsRaw.isEmpty) continue;

              final sectionLessons = sectionLessonsRaw.where((sl) {
                final title = (sl['title'] ?? sl['name'] ?? '').toString().trim().toLowerCase();
                return !title.startsWith('cheatsheet');
              }).toList();

              if (sectionLessons.isEmpty) continue;

              Map<String, dynamic>? pastLesson;
              Map<String, dynamic>? currentLesson;
              Map<String, dynamic>? nextLesson;

              bool sectionHasProgress = false;
              int firstNotDoneIndex = -1;

              for (int i = 0; i < sectionLessons.length; i++) {
                final sl = sectionLessons[i];
                final slId = sl['id'] ?? sl['lessonId'];
                if (slId == null) continue;

                final isDone = gradesData.any((g) => (g['lessonId'] == slId || g['id'] == slId) && g['done'] == true);
                
                if (isDone) {
                  sectionHasProgress = true;
                } else {
                  if (firstNotDoneIndex == -1) {
                    firstNotDoneIndex = i;
                  }
                }
              }
              
              // If it's the very first section and no progress yet, we can count it as active too
              if (!sectionHasProgress && section.id == course.sections.first.id) {
                sectionHasProgress = true;
              }

              if (sectionHasProgress && firstNotDoneIndex != -1) {
                // There is still something to do in this section
                if (firstNotDoneIndex > 0) {
                  pastLesson = sectionLessons[firstNotDoneIndex - 1];
                }
                currentLesson = sectionLessons[firstNotDoneIndex];
                if (firstNotDoneIndex < sectionLessons.length - 1) {
                  nextLesson = sectionLessons[firstNotDoneIndex + 1];
                }

                activeList.add(ActiveSectionData(
                  course: course,
                  sectionId: section.id!,
                  sectionTitle: section.title ?? 'Section',
                  pastLesson: pastLesson,
                  currentLesson: currentLesson,
                  nextLesson: nextLesson,
                ));
              }
            }
          } catch (_) {}
        }
      }

      if (mounted) {
        setState(() {
          _activeSections = activeList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  Widget _buildLessonTile(Map<String, dynamic>? lesson, String type, ActiveSectionData data) {
    if (lesson == null) return const SizedBox.shrink();
    
    final theme = Theme.of(context);
    final title = lesson['title'] ?? lesson['name'] ?? 'Lesson';
    final id = lesson['id'] ?? lesson['lessonId'];
    
    IconData icon;
    Color iconColor;
    Color bgColor;
    bool isCurrent = type == 'current';

    if (type == 'past') {
      icon = Icons.check_circle_rounded;
      iconColor = Colors.greenAccent;
      bgColor = Colors.greenAccent.withValues(alpha: 0.1);
    } else if (isCurrent) {
      icon = Icons.play_circle_fill_rounded;
      iconColor = theme.primaryColor;
      bgColor = theme.primaryColor.withValues(alpha: 0.1);
    } else {
      icon = Icons.lock_rounded;
      iconColor = Colors.grey;
      bgColor = Colors.grey.withValues(alpha: 0.1);
    }

    return InkWell(
      onTap: isCurrent ? () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => LessonPathScreen(
              course: data.course,
              sectionId: data.sectionId,
              sectionTitle: data.sectionTitle,
              autoLaunchLessonId: id,
            ),
          ),
        ).then((_) => _loadActiveSections());
      } : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: theme.cardColor.withValues(alpha: isCurrent ? 1.0 : 0.6),
          borderRadius: BorderRadius.circular(12),
          border: isCurrent ? Border.all(color: theme.primaryColor.withValues(alpha: 0.5), width: 1) : null,
          boxShadow: isCurrent ? [
            BoxShadow(
              color: theme.primaryColor.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type == 'past' ? 'Completed' : (type == 'current' ? 'Up Next' : 'Locked'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: isCurrent ? 1.0 : 0.7),
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
          ],
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

  Widget _buildActiveSectionCard(ActiveSectionData data) {
    final theme = Theme.of(context);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Builder(
                  builder: (context) {
                    final iconPath = _getSectionIconPath(data.sectionTitle);
                    if (iconPath != null) {
                      return Image.asset(iconPath, width: 40, height: 40);
                    }
                    return Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.school_rounded, color: theme.primaryColor),
                    );
                  }
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.course.title,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        data.sectionTitle,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Lessons List
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildLessonTile(data.pastLesson, 'past', data),
                _buildLessonTile(data.currentLesson, 'current', data),
                _buildLessonTile(data.nextLesson, 'next', data),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 24.0, bottom: 24.0),
              child: Text(
                'Keep Learning',
                style: GoogleFonts.poppins(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          
          if (_activeSections.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: Text(
                  'No active courses right now.\nCheck out the Courses tab to start learning!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildActiveSectionCard(_activeSections[index]);
                },
                childCount: _activeSections.length,
              ),
            ),
        ],
      ),
    );
  }
}
