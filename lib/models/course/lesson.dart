import 'lessonContent.dart';

class Lesson {
  final int? id;
  final String title;
  final List<MCQ> questions;
  final List<LessonContent> contents;
  final bool done;
  final String description;
  int get numberOfQuestions => questions.length;
  int answeredQuestions = 0;

  Lesson({
    this.id,
    required this.title,
    required this.questions,
    this.contents = const [],
    required this.done,
    required this.description,
  });

  factory Lesson.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    List<MCQ> parseQuestions(dynamic value) {
      if (value is! List) return const [];

      return value.whereType<Map>().map((item) {
        final q = Map<String, dynamic>.from(item);
        final rawOptions = q['options'] ?? q['answers'];
        final options = rawOptions is List
            ? rawOptions
                  .map(
                    (entry) => Answer(
                      answer: entry is Map
                          ? (entry['answer'] ?? '').toString()
                          : entry.toString(),
                    ),
                  )
                  .toList()
            : <Answer>[];

        return MCQ(
          question: (q['question'] ?? '').toString(),
          options: options,
          correctAnswerIndex: asInt(q['correctAnswerIndex']),
        );
      }).toList();
    }

    List<LessonContent> parseContents(dynamic value) {
      if (value is! List) return const [];

      return value
          .whereType<Map>()
          .map((item) {
            try {
              return LessonContent.fromMap(Map<String, dynamic>.from(item));
            } catch (_) {
              return null;
            }
          })
          .whereType<LessonContent>()
          .toList();
    }

    final parsedContents = parseContents(map['contents']);
    var parsedQuestions = parseQuestions(map['questions']);

    if (parsedQuestions.isEmpty && parsedContents.isNotEmpty) {
      parsedQuestions = parsedContents
          .map((content) => content.asMcqOrNull())
          .whereType<MCQ>()
          .toList();
    }

    return Lesson(
      id: asInt(map['id']),
      title: (map['title'] ?? map['name'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      done: map['done'] == true,
      questions: parsedQuestions,
      contents: parsedContents,
    );
  }

  @override
  String toString() {
    return 'Lesson(title: $title, questions: ${questions.length}, done: $done, description: $description)';
  }
}
