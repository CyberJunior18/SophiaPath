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

      return value.whereType<Map>().expand((item) {
        final q = Map<String, dynamic>.from(item);
        final blocks = q['blocks'];

        if (blocks is List && blocks.isNotEmpty) {
          return blocks
              .whereType<Map>()
              .map(
                (block) => MCQ.fromExerciseMap(
                  Map<String, dynamic>.from(block),
                  fallbackTitle: (q['pageTitle'] ?? q['title'] ?? '')
                      .toString(),
                ),
              )
              .whereType<MCQ>();
        }

        final parsedQuestion = MCQ.fromExerciseMap(q);
        if (parsedQuestion != null) return [parsedQuestion];

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

        return [
          MCQ(
            question: (q['question'] ?? '').toString(),
            options: options,
            correctAnswerIndex: asInt(
              q['correctAnswerIndex'] ?? q['correctAnswer'],
            ),
          ),
        ];
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

    final dynamic rawPages = map['pages'];
    final parsedContents = <LessonContent>[
      ...parseContents(map['contents'] ?? map['lessons'] ?? []),
    ];

    if (parsedContents.isEmpty && rawPages is List && rawPages.isNotEmpty) {
      final syntheticContent = Map<String, dynamic>.from(map)
        ..putIfAbsent('id', () => map['id'] ?? map['lessonId'])
        ..putIfAbsent('category', () => map['category'] ?? 'learning')
        ..putIfAbsent(
          'type',
          () => (map['category'] ?? '').toString().toLowerCase() == 'exercise'
              ? 'mcq'
              : map['type'] ?? 'text',
        )
        ..putIfAbsent('orderIndex', () => map['orderIndex'] ?? 0)
        ..putIfAbsent('partTitle', () => map['partTitle'] ?? map['title'])
        ..putIfAbsent('chapterName', () => map['chapterName'] ?? '')
        ..['pages'] = rawPages;

      parsedContents.add(LessonContent.fromMap(syntheticContent));
    }

    var parsedQuestions = parseQuestions(map['questions']);

    if (parsedQuestions.isEmpty && rawPages is List) {
      parsedQuestions = parseQuestions(rawPages);
    }

    if (parsedQuestions.isEmpty && parsedContents.isNotEmpty) {
      parsedQuestions = parsedContents
          .expand((content) => content.extractQuestions())
          .toList();
    }

    return Lesson(
      id: asInt(map['id']),
      title: (map['title'] ?? map['name'] ?? map['partTitle'] ?? '').toString(),
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

// Backend now refers to course units as "Section".
typedef Section = Lesson;
