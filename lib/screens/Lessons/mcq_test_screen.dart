import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../widgets/inline_code_text.dart';
import '../../models/course/lessonContent.dart';
import '../authentication/authService.dart';
import '../../services/cpp_code_runner.dart';
import '../../services/course/user_stats_service.dart';

class McqTestScreen extends StatefulWidget {
  final String section;
  final List<MCQ> questions;
  final int courseId;
  final int totalLessons;
  final int? lessonId;
  final VoidCallback? onTestCompleted;

  const McqTestScreen({
    super.key,
    required this.section,
    required this.questions,
    required this.courseId,
    required this.totalLessons,
    this.lessonId,
    this.onTestCompleted,
  });

  @override
  State<McqTestScreen> createState() => _McqTestScreenState();
}

class _McqTestScreenState extends State<McqTestScreen> {
  int currentIndex = 0;
  int correctAnswers = 0;
  bool answered = false;
  int selectedIndex = -1;
  int currentCorrectIndex = -1;
  bool? lastAnswerCorrect;
  late List<Answer> currentAnswers;
  final Map<int, List<TextEditingController>> _fillCodeControllers = {};
  final CppCodeRunner _cppCodeRunner = CppCodeRunner();
  final UserStatsService _statsService = UserStatsService();

  @override
  void initState() {
    super.initState();
    _setupCurrentQuestion();
  }

  @override
  void dispose() {
    for (final controllers in _fillCodeControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void _setupCurrentQuestion() {
    final question = widget.questions[currentIndex];
    if (question.isFillCode) {
      currentAnswers = const [];
      currentCorrectIndex = -1;
      _fillCodeControllers.putIfAbsent(
        currentIndex,
        () => question.inputLines
            .map((_) => TextEditingController())
            .toList(growable: false),
      );
      return;
    }

    if (question.isCodeChallenge) {
      currentAnswers = const [];
      currentCorrectIndex = -1;
      return;
    }

    _shuffleCurrentAnswers();
  }

  void _shuffleCurrentAnswers() {
    final question = widget.questions[currentIndex];
    List<Answer> answers = List.from(question.options);
    if (answers.isEmpty) {
      currentAnswers = const [];
      currentCorrectIndex = -1;
      return;
    }
    final int correctIndex =
        question.correctAnswerIndex >= 0 &&
            question.correctAnswerIndex < answers.length
        ? question.correctAnswerIndex
        : 0;
    Answer correct = answers.removeAt(correctIndex);
    answers.shuffle();
    currentCorrectIndex = Random().nextInt(answers.length + 1);
    answers.insert(currentCorrectIndex, correct);
    currentAnswers = answers;
  }

  void _showTestResult(int score) async {
    if (score == 100) {
      await _statsService.recordPerfectScore();
    }

    if (score >= 70) {
      await _statsService.incrementCorrectAnswers();
    }

    final lessonId = widget.lessonId;
    if (lessonId != null && lessonId > 0) {
      try {
        await AuthService().setLessonGrade(
          lessonId: lessonId,
          grade: score.toDouble(),
        );
      } catch (_) {}
    }

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24.0),
        ),
        elevation: 10,
        shadowColor: Colors.black.withValues(alpha: 0.3),
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Container(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: _getScoreGradient(score),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getScoreColor(score).withValues(alpha: 0.3),
                      blurRadius: 15,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '$score%',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                score >= 70 ? 'Congratulations!' : 'Test Completed',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getScoreIcon(score),
                    color: _getScoreColor(score),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _getScoreMessage(score),
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getScoreColor(score),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context, score);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getScoreColor(score),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.teal;
    if (score >= 70) return Colors.blue;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  List<Color> _getScoreGradient(int score) {
    if (score >= 90) return [Colors.green.shade600, Colors.green.shade400];
    if (score >= 80) return [Colors.teal.shade600, Colors.teal.shade400];
    if (score >= 70) return [Colors.blue.shade600, Colors.blue.shade400];
    if (score >= 60) return [Colors.orange.shade600, Colors.orange.shade400];
    return [Colors.red.shade600, Colors.red.shade400];
  }

  IconData _getScoreIcon(int score) {
    if (score >= 90) return Icons.emoji_events;
    if (score >= 80) return Icons.star;
    if (score >= 70) return Icons.thumb_up;
    if (score >= 60) return Icons.check_circle;
    return Icons.refresh;
  }

  String _getScoreMessage(int score) {
    if (score >= 95) return 'Perfect Score! 🎯';
    if (score >= 90) return 'Outstanding! 🏆';
    if (score >= 80) return 'Excellent Work! 🌟';
    if (score >= 70) return 'Great Job! 👍';
    if (score >= 60) return 'Good Effort! 👏';
    return 'Keep Practicing! 💪';
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
    final question = widget.questions[currentIndex];

    return Scaffold(
      // appBar: AppBar(
      //   title: Text(widget.section),
      //   backgroundColor: theme.colorScheme.primary,
      // ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () async {
                    final shouldLeave =
                        await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Are you sure?'),
                            content: const Text(
                              'Your progress in this lesson will be removed if you leave.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text('Leave'),
                              ),
                            ],
                          ),
                        ) ??
                        false;

                    if (shouldLeave) {
                      Navigator.pop(context);
                    }
                  },
                  icon: Icon(Icons.close),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Question ${currentIndex + 1}/${widget.questions.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            'Score: $correctAnswers/${widget.questions.length}',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: (currentIndex + 1) / widget.questions.length,
                        backgroundColor: Colors.grey[300],
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            // Text(
                            //   'Q${currentIndex + 1}',
                            //   style: GoogleFonts.poppins(
                            //     fontSize: 18,
                            //     fontWeight: FontWeight.bold,
                            //     color: theme.colorScheme.primary,
                            //   ),
                            // ),
                            // const SizedBox(height: 10),
                            InlineCodeText(
                              "${question.isFillCode || question.hasCodeSnippet ? question.instruction : question.question}",
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            // if (question.hint != null && question.hint!.isNotEmpty)
                            //   Padding(
                            //     padding: const EdgeInsets.only(top: 10),
                            //     child: Text(
                            //       'Hint: ${question.hint!}',
                            //       style: GoogleFonts.poppins(
                            //         fontSize: 14,
                            //         fontStyle: FontStyle.italic,
                            //         color: Colors.orange[700],
                            //       ),
                            //     ),
                            //   ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    if (question.hasCodeSnippet) ...[
                      _buildCodeSnippetCard(
                        context,
                        question,
                        theme,
                        onRunPlayground: () async {
                          final passed = await _openCodePlayground(question);
                          if (passed == true &&
                              question.isCodeChallenge &&
                              mounted) {
                            setState(() {
                              answered = true;
                              lastAnswerCorrect = true;
                              correctAnswers++;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 22),
                    ],
                    if (question.isFillCode) ...[
                      _buildFillCodeCard(question, theme),
                      const SizedBox(height: 18),
                      if (!answered)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _checkFillCodeAnswer,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              question.exerciseType == 'write_line'
                                  ? 'Check Output'
                                  : 'Check Answer',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ] else if (question.isCodeChallenge) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Open the code editor, run the visible and hidden tests, then return here when your solution passes.',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.5,
                            color: theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: answered
                              ? null
                              : () {
                                  setState(() {
                                    answered = true;
                                    lastAnswerCorrect = false;
                                  });
                                },
                          icon: const Icon(Icons.skip_next_rounded),
                          label: const Text('Skip Challenge (0 points)'),
                        ),
                      ),
                    ] else
                      ...List.generate(currentAnswers.length, (i) {
                        bool isSelected = i == selectedIndex;
                        bool isCorrect = i == currentCorrectIndex;

                        Color bgColor = _answerContainerColor(theme);
                        IconData? icon;
                        Color? iconColor;

                        if (answered) {
                          if (isSelected) {
                            bgColor = isCorrect
                                ? _answerFeedbackColor(theme, Colors.green)
                                : _answerFeedbackColor(theme, Colors.red);
                            icon = isCorrect
                                ? Icons.check_circle
                                : Icons.cancel;
                            iconColor = isCorrect ? Colors.green : Colors.red;
                          } else if (isCorrect) {
                            bgColor = _answerFeedbackColor(theme, Colors.green);
                            icon = Icons.check_circle;
                            iconColor = Colors.green;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Material(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: answered
                                  ? null
                                  : () => _selectAnswer(i, isCorrect),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        currentAnswers[i].answer,
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          color:
                                              theme.textTheme.bodyLarge?.color,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (icon != null)
                                      Icon(icon, color: iconColor, size: 24),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),

                    if (answered)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            question.answerComment,
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: theme.textTheme.bodyMedium?.color,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (answered)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (currentIndex + 1 < widget.questions.length) {
                        setState(() {
                          currentIndex++;
                          answered = false;
                          selectedIndex = -1;
                          lastAnswerCorrect = null;
                          _setupCurrentQuestion();
                        });
                      } else {
                        int score =
                            ((correctAnswers / widget.questions.length) * 100)
                                .round();
                        _showTestResult(score);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: lastAnswerCorrect == null
                          ? null
                          : lastAnswerCorrect!
                          ? Colors.green
                          : Colors.red,
                      foregroundColor: lastAnswerCorrect == null
                          ? null
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      currentIndex + 1 < widget.questions.length
                          ? 'Next Question'
                          : 'See Results',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _selectAnswer(int index, bool isCorrect) {
    setState(() {
      answered = true;
      selectedIndex = index;
      lastAnswerCorrect = isCorrect;
      if (isCorrect) correctAnswers++;
    });
  }

  Future<void> _checkFillCodeAnswer() async {
    final question = widget.questions[currentIndex];

    if (question.exerciseType == 'write_line') {
      final passed = await _checkWriteLineAnswer(question);
      if (!mounted) return;

      setState(() {
        answered = true;
        lastAnswerCorrect = passed;
        if (passed == true) correctAnswers++;
      });
      return;
    }
    final controllers = _fillCodeControllers[currentIndex] ?? const [];
    final expectedInputs = question.inputLines;

    String normalizeInput(String value, {required bool multiline}) {
      if (!multiline) {
        return value.trim();
      }

      return value
          .replaceAll('\r\n', '\n')
          .split('\n')
          .map((line) => line.trimRight())
          .join('\n')
          .trim();
    }

    final isCorrect =
        controllers.length == expectedInputs.length &&
        List.generate(controllers.length, (index) {
          final expected = expectedInputs[index];
          final typed = normalizeInput(
            controllers[index].text,
            multiline: expected.multiline,
          );
          final expectedAnswer = normalizeInput(
            expected.expectedAnswer,
            multiline: expected.multiline,
          );

          return typed == expectedAnswer;
        }).every((matches) => matches);

    setState(() {
      answered = true;
      lastAnswerCorrect = isCorrect;
      if (isCorrect) correctAnswers++;
    });
  }

  Future<bool> _checkWriteLineAnswer(MCQ question) async {
    final testCases = [...question.testCases, ...question.hiddenTestCases];
    if (testCases.isEmpty) {
      final result = await _cppCodeRunner.run(_editableCodeForQuestion(question));
      return !result.isError && result.output.trim().isNotEmpty;
    }

    final runResults = await _cppCodeRunner.runBatch(
      _editableCodeForQuestion(question),
      testCases.map((testCase) => testCase.input).toList(),
    );

    if (runResults.length != testCases.length) return false;

    for (var index = 0; index < testCases.length; index++) {
      final actual = _normalizeOutput(runResults[index].output);
      final expected = _normalizeOutput(testCases[index].expectedOutput);
      if (runResults[index].isError || actual != expected) {
        return false;
      }
    }

    return true;
  }

  String _normalizeOutput(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.trimRight())
        .toList();

    while (lines.isNotEmpty && lines.first.trim().isEmpty) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }

    return lines.join('\n').trim();
  }

  Future<bool?> _openCodePlayground(MCQ question) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CppPlaygroundScreen(
          title: question.fileName.isNotEmpty ? question.fileName : 'C++ Code',
          initialCode: _editableCodeForQuestion(question),
          testCases: [...question.testCases, ...question.hiddenTestCases],
        ),
      ),
    );
  }

  String _editableCodeForQuestion(MCQ question) {
    if (question.codeSnippetLines.isNotEmpty) {
      return question.codeSnippetLines.join('\n');
    }

    final controllers = _fillCodeControllers[currentIndex] ?? const [];
    final lines = <String>[];
    var inputIndex = 0;
    var lineIndex = 0;

    String inputAnswer(CodeTemplateLine line) {
      final typedAnswer = inputIndex < controllers.length
          ? line.multiline
            ? controllers[inputIndex].text
            : controllers[inputIndex].text.trim()
          : '';
      inputIndex++;
      return typedAnswer.isNotEmpty ? typedAnswer : line.expectedAnswer;
    }

    while (lineIndex < question.codeTemplateLines.length) {
      final line = question.codeTemplateLines[lineIndex];
      if (line.type == 'input') {
        lines.add(inputAnswer(line));
        lineIndex++;
        continue;
      }

      var codeLine = line.content;
      lineIndex++;
      var hadInlineInput = false;

      while (lineIndex < question.codeTemplateLines.length &&
          question.codeTemplateLines[lineIndex].type == 'input') {
        codeLine =
            '$codeLine${inputAnswer(question.codeTemplateLines[lineIndex])}';
        hadInlineInput = true;
        lineIndex++;
      }

      if (hadInlineInput && lineIndex < question.codeTemplateLines.length) {
        final continuation = question.codeTemplateLines[lineIndex];
        if (continuation.type == 'code' &&
            continuation.content.startsWith(' ') &&
            continuation.content.trim().isNotEmpty) {
          codeLine = '$codeLine${continuation.content}';
          lineIndex++;
        }
      }

      lines.add(codeLine);
    }

    return lines.join('\n');
  }

  Widget _buildCodeSnippetCard(
    BuildContext context,
    MCQ question,
    ThemeData theme, {
    Future<void> Function()? onRunPlayground,
  }) {
    final canRun = question.isCodeChallenge || question.isFillCode || answered;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCodeHeader(
            question,
            theme,
            showPlaygroundButton: canRun,
            onRunPlayground: onRunPlayground,
          ),
          const SizedBox(height: 10),
          ...List.generate(question.codeSnippetLines.length, (index) {
            final codeLine = question.codeSnippetLines[index].isEmpty
                ? ' '
                : question.codeSnippetLines[index];
            return _buildCodeTextLine(
              lineNumber: index + 1,
              child: _buildHighlightedCodeText(codeLine, theme),
              theme: theme,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFillCodeCard(MCQ question, ThemeData theme) {
    final controllers = _fillCodeControllers[currentIndex] ?? const [];
    final rows = _codeTemplateRows(question);
    var inputIndex = 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCodeHeader(question, theme, showPlaygroundButton: true),
          const SizedBox(height: 10),
          ...List.generate(rows.length, (rowIndex) {
            final row = rows[rowIndex];

            if (row.length == 1 &&
                row.first.type == 'input' &&
                row.first.multiline) {
              final line = row.first;
              final hasController = inputIndex < controllers.length;
              final controller = hasController ? controllers[inputIndex] : null;
              final expected = line.expectedAnswer;
              final isCorrect =
                  hasController && controller?.text.trim() == expected.trim();
              inputIndex++;

              return _buildCodeTextLine(
                lineNumber: rowIndex + 1,
                child: TextField(
                  controller: controller,
                  enabled: !answered && hasController,
                  autocorrect: false,
                  enableSuggestions: false,
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  style: GoogleFonts.robotoMono(
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: answered
                        ? (isCorrect
                              ? Colors.green.withValues(alpha: 0.12)
                              : Colors.red.withValues(alpha: 0.12))
                        : theme.colorScheme.surface,
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                theme: theme,
              );
            }

            return _buildCodeTextLine(
              lineNumber: rowIndex + 1,
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: row.map((line) {
                  if (line.type == 'input') {
                    final hasController = inputIndex < controllers.length;
                    final controller = hasController
                        ? controllers[inputIndex]
                        : null;
                    final expected = line.expectedAnswer;
                    final isCorrect =
                        hasController &&
                        controller?.text.trim() == expected.trim();
                    inputIndex++;

                    return SizedBox(
                      width: max(58, line.width * 14).toDouble(),
                      height: 34,
                      child: TextField(
                        controller: controller,
                        enabled: !answered && hasController,
                        autocorrect: false,
                        enableSuggestions: false,
                        style: GoogleFonts.robotoMono(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: answered
                              ? (isCorrect
                                    ? Colors.green.withValues(alpha: 0.12)
                                    : Colors.red.withValues(alpha: 0.12))
                              : theme.colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    );
                  }

                  return _buildHighlightedCodeText(
                    line.content.isEmpty ? ' ' : line.content,
                    theme,
                  );
                }).toList(),
              ),
              theme: theme,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCodeHeader(
    MCQ question,
    ThemeData theme, {
    bool showPlaygroundButton = false,
    Future<void> Function()? onRunPlayground,
  }) {
    final title = question.fileName.isNotEmpty
        ? question.fileName
        : question.codeLanguage.toUpperCase();

    if (title.isEmpty && !showPlaygroundButton) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        if (title.isNotEmpty)
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          )
        else
          const Spacer(),
        if (showPlaygroundButton)
          TextButton.icon(
            onPressed: onRunPlayground == null
                ? () => _openCodePlayground(question)
                : () async => onRunPlayground(),
            icon: const Icon(Icons.terminal_rounded, size: 18),
            label: const Text('Run'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  Widget _buildCodeTextLine({
    required int lineNumber,
    required Widget child,
    required ThemeData theme,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            child: SizedBox(
              height: 19,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '$lineNumber',
                  textAlign: TextAlign.right,
                  style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    height: 1.45,
                    color: theme.textTheme.bodySmall?.color?.withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildHighlightedCodeText(String code, ThemeData theme) {
    return RichText(
      text: CppCodeController.highlightedTextSpan(
        code,
        theme,
        GoogleFonts.robotoMono(
          fontSize: 13,
          height: 1.45,
          color: theme.colorScheme.onSurface,
        ),
      ),
      softWrap: true,
      overflow: TextOverflow.visible,
      textWidthBasis: TextWidthBasis.parent,
    );
  }

  List<List<CodeTemplateLine>> _codeTemplateRows(MCQ question) {
    final rows = <List<CodeTemplateLine>>[];
    var index = 0;

    while (index < question.codeTemplateLines.length) {
      final current = question.codeTemplateLines[index];

      if (current.type == 'code' &&
          index + 1 < question.codeTemplateLines.length &&
          question.codeTemplateLines[index + 1].type == 'input' &&
          !question.codeTemplateLines[index + 1].multiline) {
        final row = <CodeTemplateLine>[current];
        index++;
        while (index < question.codeTemplateLines.length &&
            question.codeTemplateLines[index].type == 'input' &&
            !question.codeTemplateLines[index].multiline) {
          row.add(question.codeTemplateLines[index]);
          index++;
        }
        if (index < question.codeTemplateLines.length) {
          final possibleContinuation = question.codeTemplateLines[index];
          if (possibleContinuation.type == 'code' &&
              possibleContinuation.content.startsWith(' ') &&
              possibleContinuation.content.trim().isNotEmpty) {
            row.add(possibleContinuation);
            index++;
          }
        }
        rows.add(row);
        continue;
      }

      rows.add([current]);
      index++;
    }

    return rows;
  }
}

class CppPlaygroundScreen extends StatefulWidget {
  final String title;
  final String initialCode;
  final List<CodeChallengeTestCase> testCases;

  const CppPlaygroundScreen({
    super.key,
    required this.title,
    required this.initialCode,
    this.testCases = const [],
  });

  @override
  State<CppPlaygroundScreen> createState() => _CppPlaygroundScreenState();
}

class _CppPlaygroundScreenState extends State<CppPlaygroundScreen> {
  late final CppCodeController _codeController;
  final ScrollController _editorScrollController = ScrollController();
  final ScrollController _gutterScrollController = ScrollController();
  final CppCodeRunner _cppCodeRunner = CppCodeRunner();
  String _output = '';
  bool _hasRunError = false;
  bool _isRunning = false;
  bool _testsPassed = false;
  int _passedTests = 0;
  int _totalTests = 0;
  List<_PlaygroundTestResult> _testResults = const [];

  @override
  void initState() {
    super.initState();
    _codeController = CppCodeController(text: widget.initialCode);
    _editorScrollController.addListener(_syncScrollFromEditor);
    _gutterScrollController.addListener(_syncScrollFromGutter);
    _runCode();
  }

  @override
  void dispose() {
    _editorScrollController
      ..removeListener(_syncScrollFromEditor)
      ..dispose();
    _gutterScrollController
      ..removeListener(_syncScrollFromGutter)
      ..dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _syncScrollFromEditor() {
    if (!_gutterScrollController.hasClients ||
        !_editorScrollController.hasClients) {
      return;
    }
    if (_gutterScrollController.offset == _editorScrollController.offset)
      return;
    _gutterScrollController.jumpTo(_editorScrollController.offset);
  }

  void _syncScrollFromGutter() {
    if (!_gutterScrollController.hasClients ||
        !_editorScrollController.hasClients) {
      return;
    }
    if (_editorScrollController.offset == _gutterScrollController.offset)
      return;
    _editorScrollController.jumpTo(_gutterScrollController.offset);
  }

  Future<void> _runCode() async {
    if (_isRunning) return;

    setState(() {
      _output = widget.testCases.isEmpty
          ? 'Compiling and running...'
          : 'Compiling and running tests...';
      _hasRunError = false;
      _isRunning = true;
      _testsPassed = false;
      _passedTests = 0;
      _totalTests = widget.testCases.length;
      _testResults = const [];
    });

    try {
      if (widget.testCases.isEmpty) {
        final result = await _cppCodeRunner.run(_codeController.text);
        if (!mounted) return;

        setState(() {
          _output = result.output;
          _hasRunError = result.isError;
          _isRunning = false;
        });
        return;
      }

      final inputs = widget.testCases
          .map((testCase) => testCase.input)
          .toList();
      final runResults = await _cppCodeRunner.runBatch(
        _codeController.text,
        inputs,
      );
      if (!mounted) return;

      final testResults = <_PlaygroundTestResult>[];
      var passed = 0;

      for (var index = 0; index < widget.testCases.length; index++) {
        final testCase = widget.testCases[index];
        final runResult = runResults[index];
        final actual = _normalizeOutput(runResult.output);
        final expected = _normalizeOutput(testCase.expectedOutput);
        final isPassed = !runResult.isError && actual == expected;
        if (isPassed) passed++;

        testResults.add(
          _PlaygroundTestResult(
            index: index,
            testCase: testCase,
            runResult: runResult,
            passed: isPassed,
          ),
        );
      }

      setState(() {
        _passedTests = passed;
        _totalTests = widget.testCases.length;
        _testsPassed = passed == widget.testCases.length;
        _output = 'Passed $_passedTests/$_totalTests tests.';
        _testResults = testResults;
        _hasRunError = !_testsPassed;
        _isRunning = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _output = 'Failed to run code: $error';
        _hasRunError = true;
        _isRunning = false;
      });
    }
  }

  String _normalizeOutput(String text) {
    final normalized = text.replaceAll('\r\n', '\n');
    final lines = normalized
        .split('\n')
        .map((line) => line.trimRight())
        .toList();

    while (lines.isNotEmpty && lines.first.trim().isEmpty) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.trim().isEmpty) {
      lines.removeLast();
    }

    return lines.join('\n').trim();
  }

  Widget _buildSplitTestResultCard(
    ThemeData theme,
    _PlaygroundTestResult result,
  ) {
    final borderColor = result.passed
        ? Colors.green.withValues(alpha: 0.3)
        : theme.colorScheme.error.withValues(alpha: 0.3);
    final tintColor = result.passed
        ? Colors.green.withValues(alpha: 0.08)
        : theme.colorScheme.error.withValues(alpha: 0.08);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.label,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Icon(
                result.passed ? Icons.check_circle : Icons.cancel,
                color: result.passed ? Colors.green : theme.colorScheme.error,
                size: 20,
              ),
            ],
          ),
          if (result.input.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Input',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.5,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                result.input,
                style: GoogleFonts.robotoMono(
                  fontSize: 12.5,
                  height: 1.45,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildOutputSidePanel(
                  theme: theme,
                  title: 'Expected',
                  content: result.expectedOutput,
                  backgroundColor: tintColor,
                  borderColor: borderColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutputSidePanel(
                  theme: theme,
                  title: 'Actual',
                  content: result.actualOutput,
                  backgroundColor: result.passed
                      ? Colors.green.withValues(alpha: 0.04)
                      : theme.colorScheme.error.withValues(alpha: 0.04),
                  borderColor: borderColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            result.passed ? 'Passed' : 'Failed',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: result.passed ? Colors.green : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOutputSidePanel({
    required ThemeData theme,
    required String title,
    required String content,
    required Color backgroundColor,
    required Color borderColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            content.isEmpty ? '(no output)' : content,
            style: GoogleFonts.robotoMono(
              fontSize: 12.5,
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: InlineCodeText(widget.title, style: GoogleFonts.poppins()),
        backgroundColor: theme.colorScheme.primary,
        actions: [
          IconButton(
            tooltip: 'Run code',
            onPressed: _isRunning ? null : _runCode,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _PlaygroundPanel(
                title: 'Code',
                child: _NumberedCodeEditor(
                  controller: _codeController,
                  editorScrollController: _editorScrollController,
                  gutterScrollController: _gutterScrollController,
                  theme: theme,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning
                    ? null
                    : widget.testCases.isNotEmpty && _testsPassed
                    ? () => Navigator.pop(context, true)
                    : _runCode,
                icon: _isRunning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : widget.testCases.isNotEmpty && _testsPassed
                    ? const Icon(Icons.check_circle_outline)
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  _isRunning
                      ? 'Running...'
                      : widget.testCases.isNotEmpty && _testsPassed
                      ? 'Use This Solution'
                      : 'Run Code',
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              flex: 2,
              child: _PlaygroundPanel(
                title: widget.testCases.isEmpty ? 'Output' : 'Test Results',
                child: widget.testCases.isEmpty
                    ? SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          _output,
                          style: GoogleFonts.robotoMono(
                            fontSize: 13,
                            height: 1.45,
                            color: _hasRunError
                                ? theme.colorScheme.error
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _output,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _testsPassed
                                    ? Colors.green
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ..._testResults.map(
                              (result) =>
                                  _buildSplitTestResultCard(theme, result),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaygroundTestResult {
  final int index;
  final CodeChallengeTestCase testCase;
  final CppRunResult runResult;
  final bool passed;

  const _PlaygroundTestResult({
    required this.index,
    required this.testCase,
    required this.runResult,
    required this.passed,
  });

  String get label =>
      testCase.hidden ? 'Hidden Test ${index + 1}' : 'Test ${index + 1}';

  String get input => testCase.input;

  String get expectedOutput => testCase.expectedOutput;

  String get actualOutput => runResult.output;
}

class _NumberedCodeEditor extends StatefulWidget {
  final CppCodeController controller;
  final ScrollController editorScrollController;
  final ScrollController gutterScrollController;
  final ThemeData theme;

  const _NumberedCodeEditor({
    required this.controller,
    required this.editorScrollController,
    required this.gutterScrollController,
    required this.theme,
  });

  @override
  State<_NumberedCodeEditor> createState() => _NumberedCodeEditorState();
}

class _NumberedCodeEditorState extends State<_NumberedCodeEditor> {
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () => setState(() {});
    widget.controller.addListener(_listener);
  }

  @override
  void didUpdateWidget(covariant _NumberedCodeEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_listener);
      widget.controller.addListener(_listener);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_listener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final theme = widget.theme;
        final codeStyle = GoogleFonts.robotoMono(
          fontSize: 13,
          height: 1.45,
          color: theme.colorScheme.onSurface,
        );
        const gutterWidth = 25.0;
        const codeHorizontalPadding = 12.0 * 2;
        final availableWidth = max(
          0.0,
          constraints.maxWidth - gutterWidth - codeHorizontalPadding,
        );
        final gutterLabels = _buildGutterLabels(
          widget.controller.text,
          codeStyle,
          availableWidth,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: gutterWidth,
              child: ListView.builder(
                controller: widget.gutterScrollController,
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                itemExtent: 19,
                itemCount: gutterLabels.length,
                itemBuilder: (context, index) {
                  final label = gutterLabels[index];
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        label ?? '',
                        textAlign: TextAlign.right,
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          height: 1.45,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.55,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 0),
            Expanded(
              child: TextField(
                controller: widget.controller,
                scrollController: widget.editorScrollController,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                autocorrect: false,
                enableSuggestions: false,
                cursorColor: theme.colorScheme.primary,
                style: codeStyle,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: 11,
                    horizontal: 12,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<String?> _buildGutterLabels(
    String source,
    TextStyle style,
    double availableWidth,
  ) {
    final lines = source.isEmpty ? <String>[''] : source.split('\n');
    final labels = <String?>[];

    for (var index = 0; index < lines.length; index++) {
      final visualLineCount = _countWrappedVisualLines(
        lines[index],
        style,
        availableWidth,
      );
      labels.add('${index + 1}');
      for (
        var wrappedIndex = 1;
        wrappedIndex < visualLineCount;
        wrappedIndex++
      ) {
        labels.add(null);
      }
    }

    return labels.isEmpty ? <String?>[null] : labels;
  }

  int _countWrappedVisualLines(
    String text,
    TextStyle style,
    double availableWidth,
  ) {
    if (availableWidth <= 0) return 1;

    final painter = TextPainter(
      text: TextSpan(text: text.isEmpty ? ' ' : text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: availableWidth);

    return max(1, painter.computeLineMetrics().length);
  }
}

class CppCodeController extends TextEditingController {
  CppCodeController({super.text});

  static final RegExp _tokenPattern = RegExp(
    r'''(//.*$|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\b(?:#include|using|namespace|int|return|void|double|float|char|string|bool|if|else|for|while|class|struct|public|private|true|false)\b|\b(?:cout|cin|std|endl|main)\b|\b\d+(?:\.\d+)?\b|[{}()[\];,<>+\-*/=])''',
    multiLine: true,
  );

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final theme = Theme.of(context);
    final baseStyle = style ?? DefaultTextStyle.of(context).style;
    return highlightedTextSpan(text, theme, baseStyle);
  }

  static TextSpan highlightedTextSpan(
    String source,
    ThemeData theme,
    TextStyle baseStyle,
  ) {
    final spans = <TextSpan>[];
    var lastMatchEnd = 0;

    for (final match in _tokenPattern.allMatches(source)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(text: source.substring(lastMatchEnd, match.start)));
      }

      final token = source.substring(match.start, match.end);
      spans.add(TextSpan(text: token, style: _styleForToken(token, theme)));
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < source.length) {
      spans.add(TextSpan(text: source.substring(lastMatchEnd)));
    }

    return TextSpan(style: baseStyle, children: spans);
  }

  static TextStyle _styleForToken(String token, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    Color color;
    FontWeight fontWeight = FontWeight.w400;

    if (token.startsWith('//')) {
      color = isDark ? const Color(0xFF6A9955) : const Color(0xFF008000);
    } else if (token.startsWith('"') || token.startsWith("'")) {
      color = isDark ? const Color(0xFFCE9178) : const Color(0xFFA31515);
    } else if (RegExp(r'^\d').hasMatch(token)) {
      color = isDark ? const Color(0xFFB5CEA8) : const Color(0xFF098658);
    } else if (RegExp(
      r'^(#include|using|namespace|int|return|void|double|float|char|string|bool|if|else|for|while|class|struct|public|private|true|false)$',
    ).hasMatch(token)) {
      color = isDark ? const Color(0xFF569CD6) : const Color(0xFF0000FF);
      fontWeight = FontWeight.w600;
    } else if (RegExp(r'^(cout|cin|std|endl|main)$').hasMatch(token)) {
      color = isDark ? const Color(0xFFDCDCAA) : const Color(0xFF795E26);
    } else {
      color = isDark ? const Color(0xFFD4D4D4) : const Color(0xFF333333);
    }

    return TextStyle(color: color, fontWeight: fontWeight);
  }
}

class _PlaygroundPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _PlaygroundPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
