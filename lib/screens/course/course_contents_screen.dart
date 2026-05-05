import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/course/course_info.dart';
import '../../models/course/lesson.dart';
import '../../models/course/lessonContent.dart';
import '../Lessons/mcq_test_screen.dart';
import 'lesson_content_screen.dart';

class CourseContentsScreen extends StatelessWidget {
  final CourseInfo course;

  const CourseContentsScreen({super.key, required this.course});

  Future<void> _openContent(
    BuildContext context,
    LessonContent content,
    Lesson lesson,
  ) async {
    final questions = content.extractQuestions();
    if (questions.isNotEmpty) {
      await Navigator.push<int>(
        context,
        MaterialPageRoute(
          builder: (_) => McqTestScreen(
            section: content.partTitle.isNotEmpty
                ? content.partTitle
                : content.chapterName,
            questions: questions,
            courseId: course.id ?? 0,
            totalLessons: course.lessons.length,
            onTestCompleted: () {},
          ),
        ),
      );
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonContentScreen(
          lesson: Lesson(
            id: lesson.id,
            title: content.partTitle.isNotEmpty
                ? content.partTitle
                : lesson.title,
            questions: const [],
            contents: [content],
            done: lesson.done,
            description: lesson.description,
          ),
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
          '${course.title} - All Content',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF3D5CFF),
        foregroundColor: Colors.white,
      ),
      body: course.lessons.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No lessons available in this course.',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: course.lessons.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, lessonIndex) {
                final lesson = course.lessons[lessonIndex];

                final sortedContents = List<LessonContent>.from(lesson.contents)
                  ..sort((a, b) {
                    final chapterCompare = a.chapterName.compareTo(
                      b.chapterName,
                    );
                    if (chapterCompare != 0) return chapterCompare;
                    return a.orderIndex.compareTo(b.orderIndex);
                  });

                final groups = <String, List<LessonContent>>{};
                for (final content in sortedContents) {
                  final chapterName = content.chapterName.trim().isNotEmpty
                      ? content.chapterName.trim()
                      : 'General';
                  groups.putIfAbsent(chapterName, () => []).add(content);
                }

                return Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.18),
                    ),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: lessonIndex == 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      '${lessonIndex + 1}. ${lesson.title}',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${lesson.contents.length} content item${lesson.contents.length == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    children: [
                      if (lesson.contents.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No content available',
                            style: GoogleFonts.poppins(color: Colors.grey),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final chapter in groups.keys)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF3D5CFF,
                                          ).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          chapter,
                                          style: GoogleFonts.poppins(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF3D5CFF),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      ...?groups[chapter]?.map(
                                        (content) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Material(
                                            child: InkWell(
                                              onTap: () => _openContent(
                                                context,
                                                content,
                                                lesson,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              child: Container(
                                                padding: const EdgeInsets.all(
                                                  10,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withValues(
                                                    alpha: 0.05,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: Colors.grey
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      content.type ==
                                                              LessonContentType
                                                                  .MCQ
                                                          ? Icons.quiz_outlined
                                                          : Icons
                                                                .menu_book_outlined,
                                                      size: 20,
                                                      color:
                                                          content.type ==
                                                              LessonContentType
                                                                  .MCQ
                                                          ? Colors.orange
                                                          : Colors.blue,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            content
                                                                    .partTitle
                                                                    .isNotEmpty
                                                                ? content
                                                                      .partTitle
                                                                : 'Untitled',
                                                            style:
                                                                GoogleFonts.poppins(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 13,
                                                                ),
                                                          ),
                                                          Text(
                                                            content.category ==
                                                                    LessonContentCategory
                                                                        .LEARNING
                                                                ? 'Learning'
                                                                : 'Exercise',
                                                            style:
                                                                GoogleFonts.poppins(
                                                                  fontSize: 11,
                                                                  color: Colors
                                                                      .grey[600],
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
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
