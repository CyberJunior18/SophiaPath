import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/course/course_info.dart';
import '../../models/course/lesson.dart';
import '../Lessons/mcq_test_screen.dart';
import 'lesson_contents_list_screen.dart';
import 'lesson_path_screen.dart';
import 'course_contents_screen.dart';

enum _LessonFilter { all, withContent, withQuiz }

class CourseSectionsGridScreen extends StatefulWidget {
  final CourseInfo course;

  const CourseSectionsGridScreen({super.key, required this.course});

  @override
  State<CourseSectionsGridScreen> createState() =>
      _CourseSectionsGridScreenState();
}

class _CourseSectionsGridScreenState extends State<CourseSectionsGridScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _LessonFilter _activeFilter = _LessonFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_LessonGridItem> _filteredLessons() {
    final lessons = widget.course.sections;

    return List<_LessonGridItem>.generate(
      lessons.length,
      (index) => _LessonGridItem(index: index, lesson: lessons[index]),
    ).where((item) {
      final lesson = item.lesson;
      final chapter = lesson.contents.isNotEmpty
          ? lesson.contents.first.chapterName
          : '';

      final matchesSearch =
          _searchQuery.isEmpty ||
          lesson.title.toLowerCase().contains(_searchQuery) ||
          lesson.description.toLowerCase().contains(_searchQuery) ||
          chapter.toLowerCase().contains(_searchQuery);

      final matchesFilter = switch (_activeFilter) {
        _LessonFilter.all => true,
        _LessonFilter.withContent => lesson.contents.isNotEmpty,
        _LessonFilter.withQuiz => lesson.questions.isNotEmpty,
      };

      return matchesSearch && matchesFilter;
    }).toList();
  }

  void _openLessonContents(_LessonGridItem item) {
    final lesson = item.lesson;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonContentsListScreen(lesson: lesson),
      ),
    );
  }

  void _openLessonQuiz(_LessonGridItem item) {
    final lesson = item.lesson;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => McqTestScreen(
          section: lesson.title,
          questions: lesson.questions,
          courseId: widget.course.id ?? 0,
          totalLessons: widget.course.sections.length,
          onTestCompleted: () {},
        ),
      ),
    );
  }

  void _openLessonPath(_LessonGridItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonPathScreen(
          course: widget.course,
          originalCourse: widget.course,
          initialLessonPageIndex: item.index,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredLessons();
    final crossAxisCount = MediaQuery.of(context).size.width >= 1000
        ? 4
        : MediaQuery.of(context).size.width >= 700
        ? 3
        : 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sections',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: const Color(0xFF3D5CFF),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: 'Search sections, descriptions, or chapter name',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _activeFilter == _LessonFilter.all,
                    onSelected: (_) {
                      setState(() => _activeFilter = _LessonFilter.all);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Has content'),
                    selected: _activeFilter == _LessonFilter.withContent,
                    onSelected: (_) {
                      setState(() => _activeFilter = _LessonFilter.withContent);
                    },
                  ),
                  ChoiceChip(
                    label: const Text('Has quiz'),
                    selected: _activeFilter == _LessonFilter.withQuiz,
                    onSelected: (_) {
                      setState(() => _activeFilter = _LessonFilter.withQuiz);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No sections found.',
                        style: GoogleFonts.poppins(
                          color: theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    )
                  : GridView.builder(
                      physics: const BouncingScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.95,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        final lesson = item.lesson;
                        final chapterName = lesson.contents.isNotEmpty
                            ? lesson.contents.first.chapterName
                            : 'General';

                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openLessonPath(item),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.cardColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: Colors.grey.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '#${item.index + 1}',
                                      style: GoogleFonts.poppins(
                                        color: const Color(0xFF3D5CFF),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      icon: const Icon(Icons.more_vert),
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'contents':
                                            if (lesson.contents.isNotEmpty) {
                                              _openLessonContents(item);
                                            }
                                            break;
                                          case 'quiz':
                                            if (lesson.questions.isNotEmpty) {
                                              _openLessonQuiz(item);
                                            }
                                            break;
                                          case 'path':
                                            _openLessonPath(item);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) =>
                                          <PopupMenuEntry<String>>[
                                            if (lesson.contents.isNotEmpty)
                                              PopupMenuItem<String>(
                                                value: 'contents',
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.list_rounded,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'View Contents',
                                                      style:
                                                          GoogleFonts.poppins(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            if (lesson.questions.isNotEmpty)
                                              PopupMenuItem<String>(
                                                value: 'quiz',
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.quiz_outlined,
                                                      size: 18,
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'Take Quiz',
                                                      style:
                                                          GoogleFonts.poppins(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            PopupMenuItem<String>(
                                              value: 'path',
                                              child: Row(
                                                children: [
                                                  const Icon(
                                                    Icons.account_tree_outlined,
                                                    size: 18,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    'Full Learning Path',
                                                    style:
                                                        GoogleFonts.poppins(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  lesson.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 20,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  chapterName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.poppins(
                                    color: Colors.grey,
                                    fontSize: 12,
                                  ),
                                ),
                                Row(
                                  children: [
                                    _Badge(
                                      icon: Icons.article_outlined,
                                      text: '${lesson.contents.length}',
                                    ),
                                    const SizedBox(width: 8),
                                    _Badge(
                                      icon: Icons.quiz_outlined,
                                      text: '${lesson.questions.length}',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CourseContentsScreen(course: widget.course),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3D5CFF),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Open Learning Path',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LessonGridItem {
  final int index;
  final Lesson lesson;

  const _LessonGridItem({required this.index, required this.lesson});
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Badge({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: Colors.grey.withValues(alpha: 0.15),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
