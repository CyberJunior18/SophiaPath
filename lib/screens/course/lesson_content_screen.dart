import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/course/lesson.dart' as lesson_model;
import '../../models/course/lessonContent.dart' as lesson_content_model;
import '../authentication/authService.dart';

class LessonContentScreen extends StatefulWidget {
  final lesson_model.Section lesson;
  final int? courseId;
  final int? sectionId;
  final int? lessonId;

  const LessonContentScreen({
    super.key,
    required this.lesson,
    this.courseId,
    this.sectionId,
    this.lessonId,
  });

  @override
  State<LessonContentScreen> createState() => _LessonContentScreenState();
}

class _LessonContentScreenState extends State<LessonContentScreen> {
  final AuthService _authService = AuthService();
  late final PageController _pageController;
  List<_LessonPageViewModel> _pages = const [];
  late lesson_model.Section _lesson;
  int _currentPageIndex = 0;
  bool _isLoading = true;
  bool _completionSaved = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _lesson = widget.lesson;
    _initializeLesson();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _initializeLesson() async {
    try {
      final courseId = widget.courseId;
      final sectionId = widget.sectionId;
      final lessonId = widget.lessonId ?? widget.lesson.id;

      if (courseId != null &&
          sectionId != null &&
          lessonId != null &&
          lessonId > 0) {
        final fetchedLesson = await _authService.getLessonById(
          courseId: courseId,
          sectionId: sectionId,
          lessonId: lessonId,
        );

        if (mounted) {
          _lesson = fetchedLesson;
        }
      }
    } catch (_) {
      // Fall back to the lesson object supplied by the caller.
    }

    if (!mounted) return;

    setState(() {
      _pages = _buildPages(_lesson);
      _isLoading = false;
    });
  }

  List<_LessonPageViewModel> _buildPages(lesson_model.Section lesson) {
    final pages = <_LessonPageViewModel>[];

    final sortedContents = List<lesson_content_model.Lesson>.from(
      lesson.contents,
    )..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    for (final content in sortedContents) {
      final sortedPages = List<lesson_content_model.LessonPage>.from(
        content.pages,
      )..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      for (final page in sortedPages) {
        pages.add(
          _LessonPageViewModel(contentTitle: content.partTitle, page: page),
        );
      }
    }

    return pages;
  }

  void _goToPage(int index) {
    if (index < 0 || index >= _pages.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finishLesson() async {
    if (!_completionSaved) {
      _completionSaved = true;
      final lessonId = widget.lessonId ?? _lesson.id;
      if (lessonId != null && lessonId > 0) {
        try {
          await _authService.setLessonGrade(lessonId: lessonId, grade: 100);
        } catch (_) {}
      }
    }

    if (!mounted) return;
    Navigator.pop(context, 100);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.lesson.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final hasPages = _pages.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(_lesson.title)),
      body: SafeArea(
        child: Column(
          children: [
            if (hasPages)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Text(
                    //   widget.lesson.title,
                    //   style: GoogleFonts.poppins(
                    //     fontSize: 22,
                    //     fontWeight: FontWeight.w700,
                    //     color: Theme.of(context).colorScheme.onSurface,
                    //   ),
                    // ),
                    const SizedBox(height: 6),
                    Text(
                      'Page ${_currentPageIndex + 1} of ${_pages.length}',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: (_currentPageIndex + 1) / _pages.length,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: hasPages
                  ? PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final pageViewModel = _pages[index];
                        return _buildPage(context, pageViewModel);
                      },
                    )
                  : _buildEmptyState(context),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: !hasPages || _currentPageIndex == 0
                          ? null
                          : () => _goToPage(_currentPageIndex - 1),
                      child: const Text('Previous'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: !hasPages
                          ? _finishLesson
                          : _currentPageIndex < _pages.length - 1
                          ? () => _goToPage(_currentPageIndex + 1)
                          : _finishLesson,
                      child: Text(
                        !hasPages
                            ? 'Finish'
                            : _currentPageIndex < _pages.length - 1
                            ? 'Next'
                            : 'Finish lesson',
                      ),
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

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No lesson pages were found.',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This lesson does not contain page content yet.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(BuildContext context, _LessonPageViewModel pageViewModel) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        // if (pageViewModel.contentTitle.isNotEmpty) ...[
        //   Text(
        //     pageViewModel.contentTitle,
        //     style: GoogleFonts.poppins(
        //       fontSize: 18,
        //       fontWeight: FontWeight.w700,
        //       color: Theme.of(context).colorScheme.onSurface,
        //     ),
        //   ),
        //   const SizedBox(height: 6),
        // ],
        // if (pageViewModel.page.pageTitle.isNotEmpty) ...[
        //   Text(
        //     pageViewModel.page.pageTitle,
        //     style: GoogleFonts.poppins(
        //       fontSize: 16,
        //       fontWeight: FontWeight.w600,
        //       color: Theme.of(context).colorScheme.primary,
        //     ),
        //   ),
        //   const SizedBox(height: 16),
        // ],
        ...pageViewModel.page.blocks.map(
          (block) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildBlock(context, block),
          ),
        ),
      ],
    );
  }

  Widget _buildBlock(
    BuildContext context,
    lesson_content_model.LessonBlock block,
  ) {
    switch (block.type) {
      case 'heading':
        final level = block.level;
        final fontSize = switch (level) {
          1 => 24.0,
          2 => 21.0,
          3 => 19.0,
          _ => 17.0,
        };

        return Text(
          block.text,
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        );

      case 'paragraph':
        return Text(
          block.text,
          style: GoogleFonts.poppins(
            fontSize: 15,
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );

      case 'bullet_list':
        return _buildBulletList(context, block.items);

      case 'callout':
        return _buildCallout(context, block);

      case 'table':
        return _buildTable(context, block);

      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            block.text.isNotEmpty ? block.text : block.raw.toString(),
            style: GoogleFonts.poppins(fontSize: 14),
          ),
        );
    }
  }

  Widget _buildBulletList(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) {
        final bold = (item['bold'] ?? '').toString();
        final text = (item['text'] ?? '').toString();

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('•  ', style: GoogleFonts.poppins(fontSize: 16)),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      height: 1.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    children: [
                      if (bold.isNotEmpty)
                        TextSpan(
                          text: bold,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      TextSpan(text: text),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCallout(
    BuildContext context,
    lesson_content_model.LessonBlock block,
  ) {
    final variant = block.variant;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor = switch (variant) {
      'warning' => Colors.orange.withValues(alpha: 0.12),
      'success' => Colors.green.withValues(alpha: 0.12),
      'error' => Colors.red.withValues(alpha: 0.12),
      _ => colorScheme.primary.withValues(alpha: 0.08),
    };

    final icon = switch (variant) {
      'warning' => Icons.warning_amber_rounded,
      'success' => Icons.check_circle_outline,
      'error' => Icons.error_outline,
      _ => Icons.info_outline,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              block.text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    lesson_content_model.LessonBlock block,
  ) {
    final headers = block.headers;
    final rows = block.rows;

    if (headers.isEmpty && rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        border: TableBorder.all(color: borderColor),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        columnWidths: {
          for (int i = 0; i < headers.length; i++)
            i: const IntrinsicColumnWidth(),
        },
        children: [
          if (headers.isNotEmpty)
            TableRow(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              children: headers
                  .map(
                    (header) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        header,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ...rows.map(
            (row) => TableRow(
              children: row
                  .map(
                    (cell) => Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildTableCell(context, cell),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCell(BuildContext context, Map<String, dynamic> cell) {
    final bold = (cell['bold'] ?? '').toString();
    final text = (cell['text'] ?? '').toString();

    return RichText(
      text: TextSpan(
        style: GoogleFonts.poppins(
          fontSize: 13,
          height: 1.4,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        children: [
          if (bold.isNotEmpty)
            TextSpan(
              text: bold,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          TextSpan(text: text),
        ],
      ),
    );
  }
}

class _LessonPageViewModel {
  final String contentTitle;
  final lesson_content_model.LessonPage page;

  const _LessonPageViewModel({required this.contentTitle, required this.page});
}
