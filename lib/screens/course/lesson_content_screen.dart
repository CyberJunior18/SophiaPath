import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart'; // Add this line
import '../../models/course/lesson.dart' as lesson_model;
import '../../models/course/lessonContent.dart' as lesson_content_model;
import '../../widgets/inline_code_text.dart';
import '../../widgets/uml_diagram_widget.dart';
import '../../widgets/cyber_lab_widget.dart';
import '../../widgets/sophia_path_loading_screen.dart';
import '../authentication/authService.dart';
import '../code_playground_screen.dart';
import '../../services/code_execution_service.dart';

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

  // Track answer state per exercise block keyed by "pageIndex_blockIndex"
  // true = answered correctly, false = answered incorrectly, null = not answered
  final Map<String, bool?> _exerciseAnswers = {};
  int _totalExercises = 0;
  int _correctExercises = 0;
  // Store actual answer content for restoring when re-visiting pages
  final Map<String, dynamic> _exerciseAnswerData = {};
  // Store MCQ selected index per block key
  final Map<String, int> _blockSelectedIndex = {};
  final Set<int> _completedPages = {};

  String _blockKey(int pageIndex, int blockIndex) =>
      'page${pageIndex}_block$blockIndex';

  bool _isExerciseBlock(String type) {
    return ['mcq', 'fill_code', 'write_line', 'find_error'].contains(type);
  }

  bool _isPageCompleted(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _pages.length) return false;
    if (_completedPages.contains(pageIndex)) return true;

    final page = _pages[pageIndex].page;
    bool hasExercises = false;
    for (int i = 0; i < page.blocks.length; i++) {
      if (_isExerciseBlock(page.blocks[i].type)) {
        hasExercises = true;
        // Allow proceeding once answered (any answer), not only correct ones.
        // Grade is calculated at the end based on correct/total.
        if (_exerciseAnswers[_blockKey(pageIndex, i)] == null) {
          return false;
        }
      }
    }
    // Pages without exercises are auto-completed
    if (!hasExercises) return true;
    // All exercises have been answered - page is completed
    return true;
  }

  void _onExerciseAnswered(
    int pageIndex,
    int blockIndex, {
    bool isCorrect = true,
  }) {
    setState(() {
      final wasCorrect =
          _exerciseAnswers[_blockKey(pageIndex, blockIndex)] == true;
      final previouslyAnswered =
          _exerciseAnswers[_blockKey(pageIndex, blockIndex)] != null;
      _exerciseAnswers[_blockKey(pageIndex, blockIndex)] = isCorrect;

      if (isCorrect && !wasCorrect) {
        _correctExercises++;
      } else if (!isCorrect && wasCorrect) {
        _correctExercises--;
      }

      if (!previouslyAnswered) {
        _totalExercises++;
      }

      if (_isPageCompleted(pageIndex)) {
        _completedPages.add(pageIndex);
      }
    });
  }

  void _saveExerciseAnswerData(int pageIndex, int blockIndex, dynamic data) {
    // No setState needed here - simply storing data in the map.
    // Calling setState on every keystroke would cause the parent to rebuild,
    // interfering with TextField input.
    _exerciseAnswerData[_blockKey(pageIndex, blockIndex)] = data;
  }

  void _saveBlockSelectedIndex(
    int pageIndex,
    int blockIndex,
    int selectedIndex,
  ) {
    _blockSelectedIndex[_blockKey(pageIndex, blockIndex)] = selectedIndex;
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _lesson = widget.lesson;
    final hasAnyBlocks = _lesson.contents.any(
      (c) => c.pages.any((p) => p.blocks.isNotEmpty),
    );
    _isLoading = !hasAnyBlocks;
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

      // Only fetch if the passed lesson doesn't already contain any block data
      final hasAnyBlocks = _lesson.contents.any(
        (c) => c.pages.any((p) => p.blocks.isNotEmpty),
      );

      if (!hasAnyBlocks &&
          courseId != null &&
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
      // Fall back to the original widget.lesson
    }

    _pages = _buildPages(_lesson);
    final hasAnyBlocksAfterFetch = _lesson.contents.any(
      (c) => c.pages.any((p) => p.blocks.isNotEmpty),
    );
    if (!hasAnyBlocksAfterFetch) {
      await Future.delayed(const Duration(seconds: 2));
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
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
    // Block forward navigation if current page is not completed
    if (index > _currentPageIndex && !_isPageCompleted(_currentPageIndex)) {
      return;
    }
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

      // Calculate grade: each exercise is 1pt, convert to percentage
      final grade = _totalExercises > 0
          ? (_correctExercises * 100.0 / _totalExercises)
          : 100.0;

      if (lessonId != null && lessonId > 0) {
        try {
          await _authService.setLessonGrade(lessonId: lessonId, grade: grade);
        } catch (_) {}
      }
    }

    if (!mounted) return;
    Navigator.pop(
      context,
      _totalExercises > 0 ? (_correctExercises * 100 ~/ _totalExercises) : 100,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return SophiaPathLoadingScreen(appBarTitle: widget.lesson.title);
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
                      physics: const NeverScrollableScrollPhysics(),
                      onPageChanged: (index) {
                        setState(() {
                          _currentPageIndex = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final pageViewModel = _pages[index];
                        return _buildPage(context, pageViewModel, index);
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
                          ? _isPageCompleted(_currentPageIndex)
                                ? () => _goToPage(_currentPageIndex + 1)
                                : null
                          : _finishLesson,
                      child: Text(
                        !hasPages
                            ? 'Finish'
                            : _currentPageIndex < _pages.length - 1
                            ? _isPageCompleted(_currentPageIndex)
                                  ? 'Next'
                                  : 'Answer to proceed'
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

  Widget _buildPage(
    BuildContext context,
    _LessonPageViewModel pageViewModel,
    int pageIndex,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      children: [
        ...List.generate(pageViewModel.page.blocks.length, (blockIndex) {
          final block = pageViewModel.page.blocks[blockIndex];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _buildBlock(context, block, pageIndex, blockIndex),
          );
        }),
      ],
    );
  }

  Widget _buildBlock(
    BuildContext context,
    lesson_content_model.LessonBlock block, [
    int pageIndex = 0,
    int blockIndex = 0,
  ]) {
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
        final double ratio = block.height > 0 ? block.width / block.height : 16 / 9;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: ratio,
              child: Image.network(
                block.url,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
      case 'bullet_list':
        return _buildBulletList(context, block.items);

      case 'callout':
        return _buildCallout(context, block);

      case 'table':
        return _buildTable(context, block);

      case 'normal_code':
        return _buildNormalCodeBlock(context, block);

      case 'uml_diagram':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: UmlDiagramWidget(data: block.raw),
        );

      case 'mcq':
        return _buildMcqBlock(context, block, pageIndex, blockIndex);

      case 'code_challenge':
        return _buildCodeChallengeBlock(context, block, pageIndex, blockIndex);

      case 'write_line':
      case 'fill_code':
        return _buildInlineCodeExercise(context, block, pageIndex, blockIndex);

      case 'find_error':
        return _buildMcqBlock(context, block, pageIndex, blockIndex);

      case 'cyber':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: CyberLabWidget(block: block),
        );

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
    final colorScheme = Theme.of(context).colorScheme;
    final isRunable =
        block.raw['runable'] != false; // Default to true if not present
    final canRunCode = isRunable && _canRunCode(codeLines);
    final detectedLanguage = _detectLanguage(codeLines);
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
                          onPressed: () => _openCodePlayground(
                            context,
                            title: language.isNotEmpty
                                ? language.toUpperCase()
                                : 'Code Snippet',
                            initialCode: codeText,
                            detectedLanguage: detectedLanguage,
                            specifiedLanguage:
                                language, // The language from the code snippet metadata
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

  String _detectLanguage(List<String> codeLines) {
    for (final line in codeLines) {
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) continue;

      // Check for C++ indicators
      if (trimmed.startsWith('#include') ||
          trimmed.contains('std::') ||
          trimmed.contains('cout') ||
          trimmed.contains('cin')) {
        return 'cpp';
      }

      // Check for Java indicators
      if (trimmed.contains('public class') ||
          trimmed.contains('System.out') ||
          trimmed.contains('import java.') ||
          trimmed.contains('String[] args')) {
        return 'java';
      }
    }
    return 'unknown';
  }

  bool _canRunCode(List<String> codeLines) {
    return _detectLanguage(codeLines) != 'unknown';
  }

  void _openCodePlayground(
    BuildContext context, {
    required String title,
    required String initialCode,
    required String detectedLanguage,
    required String specifiedLanguage,
  }) {
    // Use specified language if provided, otherwise use detected language
    final finalLanguage = specifiedLanguage.isNotEmpty
        ? specifiedLanguage
        : detectedLanguage;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CodePlaygroundScreen(
          title: title,
          initialCode: initialCode,
          language: finalLanguage,
        ),
      ),
    );
  }

  Widget _buildInlineCodeExercise(
    BuildContext context,
    lesson_content_model.LessonBlock block,
    int pageIndex,
    int blockIndex,
  ) {
    final blockType = block.type;
    final instruction = (block.raw['instruction'] ?? '').toString();
    final fileName = (block.raw['fileName'] ?? '').toString();
    final rawTemplate = block.raw['codeTemplate'];
    final template = rawTemplate is Map
        ? Map<String, dynamic>.from(rawTemplate)
        : <String, dynamic>{};
    final rawLines = template['lines'];
    final codeLines = rawLines is List
        ? rawLines
              .whereType<Map>()
              .map(
                (line) => lesson_content_model.CodeTemplateLine.fromMap(
                  Map<String, dynamic>.from(line),
                ),
              )
              .toList()
        : const <lesson_content_model.CodeTemplateLine>[];
    final language = (template['language'] ?? '').toString();

    if (codeLines.isEmpty) {
      return const SizedBox.shrink();
    }

    final key = _blockKey(pageIndex, blockIndex);
    final initiallyAnswered = _exerciseAnswers[key] ?? false;
    final savedInputValues = _exerciseAnswerData[key] as Map<int, String>?;

    return _InlineCodeExerciseWidget(
      blockType: blockType,
      instruction: instruction,
      fileName: fileName,
      codeLines: codeLines,
      language: language,
      rawBlock: block.raw,
      initiallyAnswered: initiallyAnswered,
      initialInputValues: savedInputValues,
      onAnswered: (isCorrect) =>
          _onExerciseAnswered(pageIndex, blockIndex, isCorrect: isCorrect),
      onSaveInputValues: (inputValues) =>
          _saveExerciseAnswerData(pageIndex, blockIndex, inputValues),
      buildHighlightedCodeText: _buildHighlightedCodeText,
    );
  }

  Widget _buildCodeChallengeBlock(
    BuildContext context,
    lesson_content_model.LessonBlock block, [
    int pageIndex = 0,
    int blockIndex = 0,
  ]) {
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

    // Build challenge info map to pass to CodePlaygroundScreen
    final challengeProblem = (block.raw['problem'] ?? '').toString();
    final challengeInputFormat = (block.raw['inputFormat'] ?? '').toString();
    final challengeOutputFormat = (block.raw['outputFormat'] ?? '').toString();
    final challengeConstraints = (block.raw['constraints'] ?? '').toString();
    final exampleRaw = block.raw['example'];
    final exampleMap = exampleRaw is Map
        ? Map<String, dynamic>.from(exampleRaw)
        : const <String, dynamic>{};

    // Build a structured map for the playground screen
    final umlDiagramRaw = block.raw['umlDiagram'];
    final challengeInfo = <String, dynamic>{
      'problem': challengeProblem,
      'inputFormat': challengeInputFormat,
      'outputFormat': challengeOutputFormat,
      'constraints': challengeConstraints,
      'example': exampleMap,
      if (umlDiagramRaw is List && umlDiagramRaw.isNotEmpty)
        'umlDiagram': umlDiagramRaw,
    };

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
                        final detectedLang = _detectLanguage(starterLines);
                        final finalLanguage = language.isNotEmpty
                            ? language
                            : detectedLang;

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CodePlaygroundScreen(
                              title: 'Code Challenge',
                              initialCode: starterCodeText,
                              language: finalLanguage,
                              testCases: testCases,
                              challengeInfo: challengeInfo,
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
          section('Problem', challengeProblem),
          section('Input format', challengeInputFormat),
          section('Output format', challengeOutputFormat),
          section('Constraints', challengeConstraints),
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
          // === UML DIAGRAM SECTION ===
          if (block.raw['umlDiagram'] is List &&
              (block.raw['umlDiagram'] as List).isNotEmpty) ...[
            Text(
              'Class Diagram',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...((block.raw['umlDiagram'] as List).map((diagramData) {
              final diagram = diagramData is Map
                  ? Map<String, dynamic>.from(diagramData)
                  : <String, dynamic>{};
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: UmlDiagramWidget(data: diagram, compact: true),
              );
            })),
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

  Widget _sheetSection(
    BuildContext context,
    String title,
    String body,
    ColorScheme colorScheme,
  ) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 14,
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

  Widget _sheetCodeBlock(
    BuildContext context,
    String label,
    String code,
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.robotoMono(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              code,
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                height: 1.4,
                color: colorScheme.onSurface,
              ),
            ),
          ),
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
    r'''(//.*$|/\*.*?\*/|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:#include|using|namespace|int|return|void|double|float|char|string|bool|if|else|for|while|class|struct|public|private|true|false|const|auto|long|short|switch|case|break|continue|new|delete|abstract|extends|implements|interface|super|this|final|static|null|throws|try|catch|import|package|enum|protected|default|do)\b|\b(?:cout|cin|std|endl|main|String|System|out|print|println|length|size)\b|\b\d+(?:\.\d+)?\b|@\w+|[{}()[\];,<>+\-*/=])''',
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
    // Java keywords
    'abstract',
    'extends',
    'implements',
    'interface',
    'super',
    'this',
    'final',
    'static',
    'null',
    'throws',
    'try',
    'catch',
    'import',
    'package',
    'enum',
    'protected',
    'default',
    'do',
  };

  static const Set<String> _codeLibraryWords = {
    'cout',
    'cin',
    'std',
    'endl',
    'main',
    'String',
    'System',
    'out',
    'print',
    'println',
    'length',
    'size',
  };

  Widget _buildMcqBlock(
    BuildContext context,
    lesson_content_model.LessonBlock block,
    int pageIndex,
    int blockIndex,
  ) {
    final question =
        (block.raw['question'] ?? block.raw['instruction'] ?? block.text ?? '')
            .toString();
    final rawAnswers = block.raw['answers'];
    final answers = rawAnswers is List
        ? rawAnswers
              .map(
                (a) => a is Map ? (a['answer'] ?? '').toString() : a.toString(),
              )
              .toList()
        : <String>[];
    final correctAnswerIndex = block.raw['correctAnswer'] is int
        ? block.raw['correctAnswer'] as int
        : (block.raw['correctAnswerIndex'] is int
              ? block.raw['correctAnswerIndex'] as int
              : 0);

    if (question.isEmpty || answers.isEmpty) {
      return const SizedBox.shrink();
    }

    // Extract optional code snippet that accompanies the MCQ
    final rawSnippet = block.raw['codeSnippet'];
    final snippetMap = rawSnippet is Map
        ? Map<String, dynamic>.from(rawSnippet)
        : const <String, dynamic>{};
    final rawSnippetLines = snippetMap['lines'];
    final snippetLines = rawSnippetLines is List
        ? rawSnippetLines.map((line) => line.toString()).toList()
        : const <String>[];
    final snippetLanguage = (snippetMap['language'] ?? '')
        .toString()
        .toUpperCase();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (snippetLines.isNotEmpty) ...[
          _buildNormalCodeBlock(
            context,
            lesson_content_model.LessonBlock(
              raw: {
                'codeSnippet': {
                  'lines': snippetLines,
                  'language': snippetLanguage,
                },
                'runable': false,
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        _InlineMcqWidget(
          question: question,
          answers: answers,
          correctAnswerIndex: correctAnswerIndex,
          initiallyAnswered:
              _exerciseAnswers[_blockKey(pageIndex, blockIndex)] ?? false,
          initialSelectedIndex:
              _blockSelectedIndex[_blockKey(pageIndex, blockIndex)],
          onAnswered: (isCorrect) =>
              _onExerciseAnswered(pageIndex, blockIndex, isCorrect: isCorrect),
          onSelectedIndexChanged: (selectedIndex) =>
              _saveBlockSelectedIndex(pageIndex, blockIndex, selectedIndex),
        ),
      ],
    );
  }
}

class _InlineMcqWidget extends StatefulWidget {
  final String question;
  final List<String> answers;
  final int correctAnswerIndex;
  final bool initiallyAnswered;
  final int? initialSelectedIndex;
  final ValueChanged<bool> onAnswered;
  final ValueChanged<int>? onSelectedIndexChanged;

  const _InlineMcqWidget({
    required this.question,
    required this.answers,
    required this.correctAnswerIndex,
    this.initiallyAnswered = false,
    this.initialSelectedIndex,
    required this.onAnswered,
    this.onSelectedIndexChanged,
  });

  @override
  State<_InlineMcqWidget> createState() => _InlineMcqWidgetState();
}

class _InlineMcqWidgetState extends State<_InlineMcqWidget> {
  int? _selectedIndex;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    _answered = widget.initiallyAnswered;
    if (widget.initialSelectedIndex != null) {
      _selectedIndex = widget.initialSelectedIndex;
    }
  }

  @override
  void didUpdateWidget(_InlineMcqWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Restore state when widget is rebuilt on page revisit
    bool needsUpdate = false;
    if (widget.initiallyAnswered != oldWidget.initiallyAnswered) {
      _answered = widget.initiallyAnswered;
      needsUpdate = true;
    }
    if (widget.initialSelectedIndex != null &&
        widget.initialSelectedIndex != oldWidget.initialSelectedIndex) {
      _selectedIndex = widget.initialSelectedIndex;
      needsUpdate = true;
    }
    if (needsUpdate) {
      setState(() {});
    }
  }

  Color _answerContainerColor(ThemeData theme) {
    final background = theme.scaffoldBackgroundColor;
    final hsl = HSLColor.fromColor(background);
    final boost = theme.brightness == Brightness.dark ? 0.10 : 0.04;
    return hsl.withLightness(min(1.0, hsl.lightness + boost)).toColor();
  }

  Color _answerFeedbackColor(ThemeData theme, Color color) {
    return Color.alphaBlend(
      color.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.28 : 0.18,
      ),
      _answerContainerColor(theme),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.quiz_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Quick Check',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            widget.question,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),
          ...List.generate(widget.answers.length, (i) {
            final isSelected = i == _selectedIndex;
            final isCorrect = i == widget.correctAnswerIndex;

            Color bgColor = _answerContainerColor(theme);
            IconData? icon;
            Color? iconColor;

            if (_answered) {
              if (isSelected) {
                bgColor = isCorrect
                    ? _answerFeedbackColor(theme, Colors.green)
                    : _answerFeedbackColor(theme, Colors.red);
                icon = isCorrect ? Icons.check_circle : Icons.cancel;
                iconColor = isCorrect ? Colors.green : Colors.red;
              } else if (isCorrect) {
                bgColor = _answerFeedbackColor(theme, Colors.green);
                icon = Icons.check_circle;
                iconColor = Colors.green;
              }
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _answered
                      ? null
                      : () {
                          final correct = i == widget.correctAnswerIndex;
                          setState(() {
                            _selectedIndex = i;
                            _answered = true;
                          });
                          widget.onAnswered(correct);
                          widget.onSelectedIndexChanged?.call(i);
                        },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.answers[i],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: colorScheme.onSurface,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                        if (icon != null)
                          Icon(icon, color: iconColor, size: 22),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (_answered) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (_selectedIndex == widget.correctAnswerIndex
                            ? Colors.green
                            : Colors.red)
                        .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    _selectedIndex == widget.correctAnswerIndex
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    size: 18,
                    color: _selectedIndex == widget.correctAnswerIndex
                        ? Colors.green
                        : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _selectedIndex == widget.correctAnswerIndex
                          ? 'Correct! Well done.'
                          : 'Incorrect. The correct answer is "${widget.answers[widget.correctAnswerIndex]}".',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        height: 1.4,
                        color: _selectedIndex == widget.correctAnswerIndex
                            ? Colors.green.shade700
                            : Colors.red.shade700,
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
}

// Inline code exercise widget for fill_code, write_line, and find_error block types.
class _InlineCodeExerciseWidget extends StatefulWidget {
  final String blockType;
  final String instruction;
  final String fileName;
  final List<lesson_content_model.CodeTemplateLine> codeLines;
  final String language;
  final Map<String, dynamic> rawBlock;
  final bool initiallyAnswered;
  final Map<int, String>? initialInputValues;
  final ValueChanged<bool> onAnswered;
  final void Function(Map<int, String>) onSaveInputValues;
  final Widget Function(BuildContext, String) buildHighlightedCodeText;

  const _InlineCodeExerciseWidget({
    required this.blockType,
    required this.instruction,
    required this.fileName,
    required this.codeLines,
    required this.language,
    required this.rawBlock,
    required this.initiallyAnswered,
    this.initialInputValues,
    required this.onAnswered,
    required this.onSaveInputValues,
    required this.buildHighlightedCodeText,
  });

  @override
  State<_InlineCodeExerciseWidget> createState() =>
      _InlineCodeExerciseWidgetState();
}

class _InlineCodeExerciseWidgetState extends State<_InlineCodeExerciseWidget> {
  final Map<int, TextEditingController> _controllers = {};
  final CodeExecutionService _codeExecutionService = CodeExecutionService();
  bool _answered = false;
  bool _isChecking = false;
  String _feedbackMessage = '';
  bool _lastAnswerCorrect = false;
  String _compilationError = '';

  Null get width => null;

  @override
  void initState() {
    super.initState();
    _answered = widget.initiallyAnswered;
    _initControllers();
  }

  void _initControllers() {
    for (int i = 0; i < widget.codeLines.length; i++) {
      final line = widget.codeLines[i];
      if (line.type == 'input') {
        final initialValue =
            widget.initialInputValues?[i] ??
            (widget.initiallyAnswered ? line.expectedAnswer : '');
        _controllers[i] = TextEditingController(text: initialValue);
      }
    }
  }

  @override
  void didUpdateWidget(_InlineCodeExerciseWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool needsRestore = false;
    if (widget.initiallyAnswered != oldWidget.initiallyAnswered) {
      _answered = widget.initiallyAnswered;
      needsRestore = true;
    }
    if (widget.initialInputValues != oldWidget.initialInputValues) {
      needsRestore = true;
    }
    if (needsRestore) {
      _restoreControllerValues();
    }
  }

  void _restoreControllerValues() {
    for (int i = 0; i < widget.codeLines.length; i++) {
      if (widget.codeLines[i].type == 'input') {
        final initialValue =
            widget.initialInputValues?[i] ??
            (widget.initiallyAnswered
                ? widget.codeLines[i].expectedAnswer
                : '');
        if (_controllers[i] != null) {
          _controllers[i]!.text = initialValue;
        }
      }
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<int, String> _collectInputValues() {
    final values = <int, String>{};
    for (int i = 0; i < widget.codeLines.length; i++) {
      if (widget.codeLines[i].type == 'input' && _controllers[i] != null) {
        values[i] = _controllers[i]!.text.trim();
      }
    }
    return values;
  }

  Widget _buildInputField(
    BuildContext context,
    int index,
    lesson_content_model.CodeTemplateLine line,
    ColorScheme colorScheme,
  ) {
    return _answered
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              _controllers[index]?.text ?? line.expectedAnswer,
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                height: 1.45,
                color: _lastAnswerCorrect ? Colors.green : Colors.red,
              ),
            ),
          )
        : SizedBox(
            height: line.multiline ? 100 : 44,
            child: TextField(
              controller: _controllers[index],
              maxLines: line.multiline ? 4 : 1,
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                height: 1.45,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: colorScheme.primary),
                ),
                hintText: 'Type your answer...',
                hintStyle: GoogleFonts.robotoMono(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: colorScheme.surfaceContainerHigh.withValues(
                  alpha: 0.5,
                ),
              ),
              onChanged: (_) {
                widget.onSaveInputValues(_collectInputValues());
              },
            ),
          );
  }

  Widget _buildInlineInputField(
    BuildContext context,
    int index,
    lesson_content_model.CodeTemplateLine line,
    ColorScheme colorScheme,
  ) {
    final inputWidth = (line.width * 16.0).clamp(60.0, 200.0);
    return _answered
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Text(
              _controllers[index]?.text ?? line.expectedAnswer,
              style: GoogleFonts.robotoMono(
                fontSize: 13,
                height: 1.45,
                color: _lastAnswerCorrect ? Colors.green : Colors.red,
              ),
            ),
          )
        : SizedBox(
            width: inputWidth,
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextField(
                controller: _controllers[index],
                maxLines: 1,
                style: GoogleFonts.robotoMono(
                  fontSize: 13,
                  height: 1.45,
                  color: colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: BorderSide(color: colorScheme.primary),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHigh.withValues(
                    alpha: 0.5,
                  ),
                ),
                onChanged: (_) {
                  widget.onSaveInputValues(_collectInputValues());
                },
              ),
            ),
          );
  }

  Future<void> _checkAnswer() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
      _compilationError = '';
    });

    // Save input values before checking
    widget.onSaveInputValues(_collectInputValues());

    if (widget.blockType == 'write_line') {
      final passed = await _checkWriteLine();
      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _answered = true;
        _lastAnswerCorrect = passed;
        if (passed) {
          _feedbackMessage =
              'Correct! Your code compiled and ran successfully.';
        } else if (_compilationError.isNotEmpty) {
          _feedbackMessage = 'Compilation error: $_compilationError';
        } else {
          _feedbackMessage = 'Incorrect. Review your code and try again.';
        }
      });
      widget.onAnswered(passed);
      return;
    }

    // For fill_code and find_error: compare against expected answers
    bool allCorrect = true;
    for (int i = 0; i < widget.codeLines.length; i++) {
      final line = widget.codeLines[i];
      if (line.type == 'input') {
        final expected = line.expectedAnswer.trim();
        final actual = (_controllers[i]?.text ?? '').trim();
        if (expected.isNotEmpty && actual != expected) {
          allCorrect = false;
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _isChecking = false;
      _answered = true;
      _lastAnswerCorrect = allCorrect;
      _feedbackMessage = allCorrect
          ? 'Correct! Well done.'
          : 'Incorrect. Review your answers and try again.';
    });
    widget.onAnswered(allCorrect);
  }

  Future<bool> _checkWriteLine() async {
    // Build the full code by replacing input lines with user-entered text.
    final codeBuffer = StringBuffer();
    for (int i = 0; i < widget.codeLines.length; i++) {
      final line = widget.codeLines[i];
      if (line.type == 'input') {
        codeBuffer.writeln(_controllers[i]?.text ?? '');
      } else if (line.type == 'code') {
        codeBuffer.writeln(line.content);
      }
    }

    final fullCode = codeBuffer.toString().trim();
    if (fullCode.isEmpty) {
      setState(() {
        _compilationError = 'No code provided.';
      });
      return false;
    }

    // Detect language from the code
    final detectedLanguage = _detectLanguageFromLines(fullCode);
    final language = widget.language.isNotEmpty
        ? widget.language
        : detectedLanguage;

    try {
      final result = await _codeExecutionService.executeCode(
        language: language,
        lines: fullCode.split('\n'),
      );
      // If no error, execution succeeded
      if (result['success'] == true) {
        return true;
      } else {
        setState(() {
          _compilationError = (result['error'] ?? '').toString();
        });
        return false;
      }
    } catch (e) {
      setState(() {
        _compilationError = e.toString();
      });
      return false;
    }
  }

  String _detectLanguageFromLines(String code) {
    for (final line in code.split('\n')) {
      final trimmed = line.trimLeft();
      if (trimmed.isEmpty) continue;
      if (trimmed.startsWith('#include') ||
          trimmed.contains('std::') ||
          trimmed.contains('cout') ||
          trimmed.contains('cin')) {
        return 'cpp';
      }
      if (trimmed.contains('public class') ||
          trimmed.contains('System.out') ||
          trimmed.contains('import java.') ||
          trimmed.contains('String[] args')) {
        return 'java';
      }
    }
    return 'unknown';
  }

  Color _feedbackBgColor(
    BuildContext context,
    bool isCorrect, {
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    return isError
        ? theme.colorScheme.error.withValues(alpha: 0.1)
        : (isCorrect ? Colors.green : Colors.red).withValues(alpha: 0.1);
  }

  Color _feedbackTextColor(
    BuildContext context,
    bool isCorrect, {
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    return isError
        ? theme.colorScheme.error
        : (isCorrect ? Colors.green.shade700 : Colors.red.shade700);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final width = MediaQuery.of(context).size.width;
    final exerciseLabel = switch (widget.blockType) {
      'write_line' => 'Write the Line',
      'fill_code' => 'Fill the Code',
      'find_error' => 'Find the Error',
      _ => 'Exercise',
    };

    final checkButtonLabel = switch (widget.blockType) {
      'write_line' => 'Check Output',
      'fill_code' => 'Check Answer',
      'find_error' => 'Check Answer',
      _ => 'Check Answer',
    };

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.edit_note_rounded,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.fileName,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  if (widget.language.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        widget.language.toUpperCase(),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                        ),
                      ),
                    ),
                ],
              ),
              // if (widget.instruction.isNotEmpty) ...[
              //   const SizedBox(height: 10),
              //   Text(
              //     widget.instruction,
              //     style: GoogleFonts.poppins(
              //       fontSize: 14,
              //       height: 1.5,
              //       color: colorScheme.onSurface,
              //     ),
              //   ),
              // ],
              // if (widget.fileName.isNotEmpty) ...[
              //   const SizedBox(height: 6),
              //   Row(
              //     children: [
              //       Icon(
              //         Icons.insert_drive_file_outlined,
              //         size: 14,
              //         color: colorScheme.onSurfaceVariant,
              //       ),
              //       const SizedBox(width: 4),
              //       Text(
              //         widget.fileName,
              //         style: GoogleFonts.poppins(
              //           fontSize: 12,
              //           fontWeight: FontWeight.w600,
              //           color: colorScheme.onSurfaceVariant,
              //         ),
              //       ),
              //     ],
              //   ),
              // ],
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  // border: Border.all(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: () {
                    // Group lines into visual rows, merging sameLine items
                    final visualRows = <List<int>>[];
                    int i = 0;
                    while (i < widget.codeLines.length) {
                      final line = widget.codeLines[i];
                      if (line.sameLine && visualRows.isNotEmpty) {
                        visualRows.last.add(i);
                      } else {
                        visualRows.add([i]);
                      }
                      i++;
                    }

                    return visualRows.map((rowIndices) {
                      // If single non-input item, render as before (full width)
                      if (rowIndices.length == 1) {
                        final idx = rowIndices.first;
                        final line = widget.codeLines[idx];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(width: 8),
                              if (line.type == 'input')
                                Expanded(
                                  child: _buildInputField(
                                    context,
                                    idx,
                                    line,
                                    colorScheme,
                                  ),
                                )
                              else
                                Expanded(
                                  child: widget.buildHighlightedCodeText(
                                    context,
                                    line.content,
                                  ),
                                ),
                            ],
                          ),
                        );
                      }

                      // Multiple items on same line (inline code with sameLine)
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(width: 8),
                            ...rowIndices.map((idx) {
                              final seg = widget.codeLines[idx];
                              if (seg.type == 'input') {
                                return _buildInlineInputField(
                                  context,
                                  idx,
                                  seg,
                                  colorScheme,
                                );
                              }
                              return widget.buildHighlightedCodeText(
                                context,
                                seg.content,
                              );
                            }),
                          ],
                        ),
                      );
                    }).toList();
                  }(),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 20),
        if (!_answered)
          Center(
            child: SizedBox(
              width: width * 0.5,
              child: ElevatedButton(
                onPressed: _isChecking ? null : _checkAnswer,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isChecking
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        checkButtonLabel,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        if (_answered) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _feedbackBgColor(
                context,
                _lastAnswerCorrect,
                isError: _compilationError.isNotEmpty,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  _lastAnswerCorrect
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  size: 18,
                  color: _feedbackTextColor(
                    context,
                    _lastAnswerCorrect,
                    isError: _compilationError.isNotEmpty,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _feedbackMessage.isNotEmpty
                        ? _feedbackMessage
                        : (_lastAnswerCorrect
                              ? 'Correct! Well done.'
                              : 'Incorrect. Review your answer and try again.'),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      height: 1.4,
                      color: _feedbackTextColor(
                        context,
                        _lastAnswerCorrect,
                        isError: _compilationError.isNotEmpty,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _LessonPageViewModel {
  final String contentTitle;
  final lesson_content_model.LessonPage page;

  const _LessonPageViewModel({required this.contentTitle, required this.page});
}
