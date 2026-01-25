import 'package:sophia_path/models/course/question.dart';

class Lesson {
  final String title;
  final List<Question> questions;
  final bool done;
  int get numberOfQuestions => questions.length;
  int answeredQuestions = 0;

  Lesson({required this.title, required this.questions, required this.done});
}
