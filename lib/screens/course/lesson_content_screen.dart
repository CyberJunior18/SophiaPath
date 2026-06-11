import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/course/lesson.dart' as lesson_model;
import '../../models/course/lessonContent.dart' as lesson_content_model;
import '../../widgets/inline_code_text.dart';
import '../authentication/authService.dart';
import '../Lessons/mcq_test_screen.dart';

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
      case 'image':
        return Image.network(
          block.url,
          width: block.width,
          height: block.height,
        );
      case 'bullet_list':
        return _buildBulletList(context, block.items);

      case 'callout':
        return _buildCallout(context, block);

      case 'table':
        return _buildTable(context, block);

      case 'normal_code':
        return _buildNormalCodeBlock(context, block);

      case 'code_challenge':
        return _buildCodeChallengeBlock(context, block);

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
    final columnCount = rows.fold<int>(
      headers.length,
      (currentMax, row) => row.length > currentMax ? row.length : currentMax,
    );

    if (columnCount == 0) {
      return const SizedBox.shrink();
    }

    final borderColor = Theme.of(context).colorScheme.outlineVariant;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Table(
            border: TableBorder.all(color: borderColor),
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            columnWidths: {
              for (int i = 0; i < columnCount; i++) i: const FlexColumnWidth(),
            },
            children: [
              if (headers.isNotEmpty)
                TableRow(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  children: List.generate(columnCount, (index) {
                    final header = index < headers.length ? headers[index] : '';
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        header,
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }),
                ),
              ...rows.map(
                (row) => TableRow(
                  children: List.generate(columnCount, (index) {
                    final cell = index < row.length
                        ? row[index]
                        : const <String, dynamic>{};
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildTableCell(context, cell),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildNormalCodeBlock(
    BuildContext context,
    lesson_content_model.LessonBlock block,
  ) {
    final snippet = block.raw['codeSnippet'];
    final snippetMap = snippet is Map
        ? Map<String, dynamic>.from(snippet)
        : const <String, dynamic>{};
    final language = (snippetMap['language'] ?? '').toString().trim();
    final rawLines = snippetMap['lines'] ?? block.raw['lines'];
    final lines = rawLines is List
        ? rawLines.map((line) => line.toString()).toList()
        : const <String>[];

    if (lines.isEmpty && block.text.isEmpty) {
      return const SizedBox.shrink();
    }

    final codeLines = lines.isNotEmpty ? lines : block.text.split('\n');
    final codeText = codeLines.join('\n');
    final canRunCode = _canRunCppSnippet(codeLines);
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: constraints.maxWidth),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.code, size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          language.isNotEmpty ? language.toUpperCase() : 'CODE',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (canRunCode) ...[
                        const SizedBox(width: 12),
                        FilledButton.icon(
                          onPressed: () => _openCppPlayground(
                            context,
                            title: language.isNotEmpty
                                ? language.toUpperCase()
                                : 'Code Snippet',
                            initialCode: codeText,
                          ),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Run'),
                        ),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(codeLines.length, (index) {
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == codeLines.length - 1 ? 0 : 6,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 22,
                              child: SizedBox(
                                height: 19,
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '${index + 1}',
                                    textAlign: TextAlign.right,
                                    style: GoogleFonts.robotoMono(
                                      fontSize: 12,
                                      height: 1.5,
                                      color: colorScheme.onSurfaceVariant
                                          .withValues(alpha: 0.75),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildHighlightedCodeText(
                                context,
                                codeLines[index],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _canRunCppSnippet(List<String> codeLines) {
    for (final line in codeLines) {
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) continue;
      return trimmed.startsWith('#include');
    }
    return false;
  }

  void _openCppPlayground(
    BuildContext context, {
    required String title,
    required String initialCode,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CppPlaygroundScreen(title: title, initialCode: initialCode),
      ),
    );
  }

  Widget _buildCodeChallengeBlock(
    BuildContext context,
    lesson_content_model.LessonBlock block,
  ) {
    final rawStarterCode = block.raw['starterCode'];
    final starterCode = rawStarterCode is Map
        ? Map<String, dynamic>.from(rawStarterCode)
        : const <String, dynamic>{};
    final language = (starterCode['language'] ?? '').toString().trim();
    final rawLines = starterCode['lines'];
    final starterLines = rawLines is List
        ? rawLines.map((line) => line.toString()).toList()
        : const <String>[];
    final starterCodeText = starterLines.join('\n');
    final colorScheme = Theme.of(context).colorScheme;

    List<lesson_content_model.CodeChallengeTestCase> parseCases(
      dynamic rawCases, {
      bool hidden = false,
    }) {
      if (rawCases is! List) return const [];

      return rawCases
          .whereType<Map>()
          .map(
            (item) => lesson_content_model.CodeChallengeTestCase.fromMap(
              Map<String, dynamic>.from(item),
              hidden: hidden,
            ),
          )
          .where(
            (testCase) =>
                testCase.input.isNotEmpty || testCase.expectedOutput.isNotEmpty,
          )
          .toList();
    }

    final testCases = [
      ...parseCases(block.raw['testCases']),
      ...parseCases(block.raw['hiddenTestCases'], hidden: true),
    ];

    Widget section(String title, String body) {
      if (body.trim().isEmpty) return const SizedBox.shrink();

      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            InlineCodeText(
              body,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.5,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final example = block.raw['example'];
    final exampleMap = example is Map
        ? Map<String, dynamic>.from(example)
        : const <String, dynamic>{};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.local_cafe_outlined, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Code Challenge',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              FilledButton.icon(
                onPressed: starterCodeText.isEmpty
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CppPlaygroundScreen(
                              title:
                                  block.raw['problem']?.toString().isNotEmpty ==
                                      true
                                  ? block.raw['problem'].toString()
                                  : 'Code Challenge',
                              initialCode: starterCodeText,
                              testCases: testCases,
                            ),
                          ),
                        );
                      },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Run'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          section('Problem', block.raw['problem']?.toString() ?? ''),
          section('Input format', block.raw['inputFormat']?.toString() ?? ''),
          section('Output format', block.raw['outputFormat']?.toString() ?? ''),
          section('Constraints', block.raw['constraints']?.toString() ?? ''),
          if (exampleMap.isNotEmpty) ...[
            Text(
              'Example',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 6),
            if ((exampleMap['input'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InlineCodeText(
                  'Input: ${exampleMap['input']}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if ((exampleMap['output'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InlineCodeText(
                  'Output: ${exampleMap['output']}',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            if ((exampleMap['explanation'] ?? '').toString().isNotEmpty)
              InlineCodeText(
                'Explanation: ${exampleMap['explanation']}',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
          ],
          if (language.isNotEmpty || starterCodeText.isNotEmpty) ...[
            Text(
              'Starter Code',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (language.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        language.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ...starterLines.asMap().entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 28,
                            child: SizedBox(
                              height: 19,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  '${entry.key + 1}',
                                  textAlign: TextAlign.right,
                                  style: GoogleFonts.robotoMono(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.75),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.robotoMono(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: colorScheme.onSurface,
                                ),
                                children: [
                                  TextSpan(
                                    text: entry.value.isEmpty
                                        ? ' '
                                        : entry.value,
                                  ),
                                ],
                              ),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                              textWidthBasis: TextWidthBasis.parent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHighlightedCodeText(BuildContext context, String code) {
    final theme = Theme.of(context);

    return RichText(
      text: _highlightedCodeTextSpan(
        code,
        theme,
        GoogleFonts.robotoMono(
          fontSize: 13,
          height: 1.5,
          color: theme.colorScheme.onSurface,
        ),
      ),
      softWrap: true,
      overflow: TextOverflow.visible,
      textWidthBasis: TextWidthBasis.parent,
    );
  }

  TextSpan _highlightedCodeTextSpan(
    String source,
    ThemeData theme,
    TextStyle baseStyle,
  ) {
    final spans = <TextSpan>[];
    var lastMatchEnd = 0;

    for (final match in _codeTokenPattern.allMatches(source)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: source.substring(lastMatchEnd, match.start)));
      }

      final token = source.substring(match.start, match.end);
      spans.add(TextSpan(text: token, style: _styleForCodeToken(token, theme)));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < source.length) {
      spans.add(TextSpan(text: source.substring(lastMatchEnd)));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  TextStyle _styleForCodeToken(String token, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    Color color;
    FontWeight fontWeight = FontWeight.w400;

    if (token.startsWith('//')) {
      color = isDark ? const Color(0xFF6A9955) : const Color(0xFF008000);
    } else if (token.startsWith('/*')) {
      color = isDark ? const Color(0xFF6A9955) : const Color(0xFF008000);
    } else if (token.startsWith('"') || token.startsWith("'")) {
      color = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    } else if (RegExp(r'^\d').hasMatch(token)) {
      color = isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
    } else if (_codeKeywords.contains(token)) {
      color = isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
      fontWeight = FontWeight.w600;
    } else if (_codeLibraryWords.contains(token)) {
      color = isDark ? const Color(0xFFDCDCAA) : const Color(0xFF795E26);
    } else {
      color = isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333);
    }

    return TextStyle(color: color, fontWeight: fontWeight);
  }

  static final RegExp _codeTokenPattern = RegExp(
    r'''(//.*$|/\*.*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:#include|using|namespace|int|return|void|double|float|char|string|bool|if|else|for|while|class|struct|public|private|true|false|const|auto|long|short|switch|case|break|continue|new|delete)\b|\b(?:cout|cin|std|endl|main)\b|\b\d+(?:\.\d+)?\b|[{}()[\];,<>+\-*/=])''',
    multiLine: true,
    dotAll: true,
  );

  static const Set<String> _codeKeywords = {
    '#include',
    'using',
    'namespace',
    'int',
    'return',
    'void',
    'double',
    'float',
    'char',
    'string',
    'bool',
    'if',
    'else',
    'for',
    'while',
    'class',
    'struct',
    'public',
    'private',
    'true',
    'false',
    'const',
    'auto',
    'long',
    'short',
    'switch',
    'case',
    'break',
    'continue',
    'new',
    'delete',
  };

  static const Set<String> _codeLibraryWords = {
    'cout',
    'cin',
    'std',
    'endl',
    'main',
  };
}

class _LessonPageViewModel {
  final String contentTitle;
  final lesson_content_model.LessonPage page;

  const _LessonPageViewModel({required this.contentTitle, required this.page});
}
