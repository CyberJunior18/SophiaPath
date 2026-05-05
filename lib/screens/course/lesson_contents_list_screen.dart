import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/course/lesson.dart';
import '../../models/course/lessonContent.dart';
import '../Lessons/mcq_test_screen.dart';
import 'lesson_content_screen.dart';

class LessonContentsListScreen extends StatelessWidget {
  final Lesson lesson;

  const LessonContentsListScreen({super.key, required this.lesson});

  List<_ChapterGroup> _groupContents() {
    final sortedContents = List<LessonContent>.from(lesson.contents)
      ..sort((a, b) {
        final chapterCompare = a.chapterName.compareTo(b.chapterName);
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

    return groups.entries
        .map(
          (entry) =>
              _ChapterGroup(chapterName: entry.key, contents: entry.value),
        )
        .toList();
  }

  Future<void> _openContent(BuildContext context, LessonContent content) async {
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
            courseId: lesson.id ?? 0,
            totalLessons: lesson.contents.length,
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
    final groups = _groupContents();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          lesson.title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF3D5CFF),
        foregroundColor: Colors.white,
      ),
      body: groups.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No lesson content available.',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = groups[index];
                return Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.18),
                    ),
                  ),
                  child: ExpansionTile(
                    initiallyExpanded: index == 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    collapsedShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: Text(
                      group.chapterName,
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      '${group.contents.length} content item${group.contents.length == 1 ? '' : 's'}',
                      style: GoogleFonts.poppins(fontSize: 12),
                    ),
                    children: [
                      for (final content in group.contents)
                        ListTile(
                          leading: const Icon(Icons.menu_book_outlined),
                          title: Text(
                            content.partTitle.isNotEmpty
                                ? content.partTitle
                                : 'Untitled content',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Text(
                            content.type == LessonContentType.MCQ
                                ? 'Exercise'
                                : 'Learning content',
                            style: GoogleFonts.poppins(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _openContent(context, content),
                        ),
                      const SizedBox(height: 4),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class _ChapterGroup {
  final String chapterName;
  final List<LessonContent> contents;

  const _ChapterGroup({required this.chapterName, required this.contents});
}
