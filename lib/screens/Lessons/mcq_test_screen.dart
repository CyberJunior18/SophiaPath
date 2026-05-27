import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/course/lessonContent.dart';
import '../authentication/authService.dart';
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
  late List<Answer> currentAnswers;
  final UserStatsService _statsService = UserStatsService();

  @override
  void initState() {
    super.initState();
    _shuffleCurrentAnswers();
  }

  void _shuffleCurrentAnswers() {
    final question = widget.questions[currentIndex];
    List<Answer> answers = List.from(question.options);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = widget.questions[currentIndex];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.section),
        backgroundColor: theme.colorScheme.primary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                            Text(
                              'Q${currentIndex + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              question.question,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
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
                    ...List.generate(currentAnswers.length, (i) {
                      bool isSelected = i == selectedIndex;
                      bool isCorrect = i == currentCorrectIndex;

                      Color? bgColor;
                      IconData? icon;
                      Color? iconColor;

                      if (!answered) {
                        bgColor = theme.colorScheme.secondary.withValues(
                          alpha: 0.1,
                        );
                      } else {
                        if (isSelected) {
                          bgColor = isCorrect
                              ? Colors.green.withValues(alpha: 0.2)
                              : Colors.red.withValues(alpha: 0.2);
                          icon = isCorrect ? Icons.check_circle : Icons.cancel;
                          iconColor = isCorrect ? Colors.green : Colors.red;
                        } else if (isCorrect) {
                          bgColor = Colors.green.withValues(alpha: 0.2);
                          icon = Icons.check_circle;
                          iconColor = Colors.green;
                        } else {
                          bgColor = theme.colorScheme.secondary.withValues(
                            alpha: 0.1,
                          );
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
                                        color: theme.textTheme.bodyLarge?.color,
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
                          _shuffleCurrentAnswers();
                        });
                      } else {
                        int score =
                            ((correctAnswers / widget.questions.length) * 100)
                                .round();
                        _showTestResult(score);
                      }
                    },
                    style: ElevatedButton.styleFrom(
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
      if (isCorrect) correctAnswers++;
    });
  }
}
