import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/inline_code_text.dart';

import '../../models/course/course_info.dart';
import '../../models/course/lesson.dart' as lesson_model;
import '../authentication/authService.dart';
import 'lesson_content_screen.dart';

class CourseContentsScreen extends StatefulWidget {
  final CourseInfo course;

  const CourseContentsScreen({super.key, required this.course});

  @override
  State<CourseContentsScreen> createState() => _CourseContentsScreenState();
}

class _CourseContentsScreenState extends State<CourseContentsScreen> {
  final AuthService _auth = AuthService();
  final Map<int, List<Map<String, dynamic>>> _sectionLessons = {};
  final Set<int> _loadingSections = {};

  Future<void> _ensureSectionLoaded(int? courseId, int? sectionId) async {
    if (courseId == null || sectionId == null) return;
    if (_sectionLessons.containsKey(sectionId)) return;
    setState(() => _loadingSections.add(sectionId));
    try {
      final list = await _auth.getSectionLessons(
        courseId: courseId,
        sectionId: sectionId,
      );
      _sectionLessons[sectionId] = list;
    } catch (_) {
      _sectionLessons[sectionId] = [];
    } finally {
      if (mounted) setState(() => _loadingSections.remove(sectionId));
    }
  }

  void _openLessonFromMap(Map<String, dynamic> lessonMap) {
    final lid = lessonMap['id'] ?? lessonMap['lessonId'];
    final int lessonId = lid is int
        ? lid
        : int.tryParse(lid?.toString() ?? '') ?? 0;
    final title = (lessonMap['title'] ?? lessonMap['name'] ?? '').toString();

    if (lessonId <= 0) return;

    final lesson = lesson_model.Section(
      id: lessonId,
      title: title.isNotEmpty ? title : 'Untitled',
      questions: const [],
      contents: const [],
      done: false,
      description: (lessonMap['description'] ?? '').toString(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonContentScreen(
          lesson: lesson,
          courseId: widget.course.id,
          sectionId: lessonMap['sectionId'] ?? lessonMap['section'],
          lessonId: lessonId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.course.title} - All Content',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: widget.course.sections.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No sections available in this course.',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: widget.course.sections.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, sectionIndex) {
                final section = widget.course.sections[sectionIndex];
                final sectionId = section.id;

                final cached = sectionId != null
                    ? _sectionLessons[sectionId]
                    : null;
                final lessonCount = sectionId != null
                    ? (_sectionLessons[sectionId]?.length ??
                          section.contents.length)
                    : section.contents.length;
                final isLoading =
                    sectionId != null && _loadingSections.contains(sectionId);

                return Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.18),
                    ),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: sectionIndex == 0,
                    onExpansionChanged: (expanded) async {
                      if (expanded) {
                        await _ensureSectionLoaded(widget.course.id, sectionId);
                      }
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      '${sectionIndex + 1}. ${section.title}',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '$lessonCount content item${lessonCount == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    children: [
                      if (isLoading)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (cached == null)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Tap to load lessons for this section.',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      else if (cached.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No lessons found for this section.',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: cached.map((lessonMap) {
                              final title =
                                  (lessonMap['title'] ??
                                          lessonMap['name'] ??
                                          'Untitled')
                                      .toString();
                              final category = (lessonMap['category'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final isChapterTest = title
                                  .toLowerCase()
                                  .startsWith('chapter test');

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  child: InkWell(
                                    onTap: () => _openLessonFromMap(lessonMap),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withValues(
                                          alpha: 0.05,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: Colors.grey.withValues(
                                            alpha: 0.15,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isChapterTest
                                                ? Icons.local_cafe_outlined
                                                : category == 'exercise' ||
                                                      category == 'mcq'
                                                ? Icons.quiz_outlined
                                                : Icons.menu_book_outlined,
                                            size: 20,
                                            color: isChapterTest
                                                ? Colors.brown
                                                : category == 'exercise' ||
                                                      category == 'mcq'
                                                ? Colors.orange
                                                : Colors.blue,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                InlineCodeText(
                                                  title,
                                                  style: GoogleFonts.poppins(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                Text(
                                                  category == 'exercise'
                                                      ? 'Exercise'
                                                      : 'Learning',
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 11,
                                                    color: Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Icon(
                                            Icons.chevron_right,
                                            size: 18,
                                            color: Colors.grey[400],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
