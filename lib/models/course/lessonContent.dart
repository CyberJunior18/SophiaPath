// ignore_for_file: public_member_api_docs, sort_constructors_first
enum LessonContentType { TEXT, VIDEO, IMAGE, MCQ, FILLBLANK }

enum LessonContentLearningType { TEXT, VIDEO, IMAGE }

enum LessonContentExcerciseType { MCQ, FILLBLANK }

enum LessonContentCategory { LEARNING, EXERCISE }

Map<LessonContentType, String> LessonContentTypeToString = {
  LessonContentType.TEXT: 'text',
  LessonContentType.VIDEO: 'video',
  LessonContentType.IMAGE: 'image',
  LessonContentType.MCQ: 'mcq',
  LessonContentType.FILLBLANK: 'fillblank',
};

Map<String, LessonContentType> stringToLessonContentType = {
  'text': LessonContentType.TEXT,
  'video': LessonContentType.VIDEO,
  'image': LessonContentType.IMAGE,
  'mcq': LessonContentType.MCQ,
  'fillblank': LessonContentType.FILLBLANK,
};

Map<String, LessonContentCategory> stringToLessonContentCategory = {
  'learning': LessonContentCategory.LEARNING,
  'exercise': LessonContentCategory.EXERCISE,
};

Map<LessonContentCategory, String> LessonContentCategoryToString = {
  LessonContentCategory.LEARNING: 'learning',
  LessonContentCategory.EXERCISE: 'exercise',
};

class TextLearningContent {
  String text;
  TextLearningContent({required this.text});
}

class LessonContent {
  final int id;
  final LessonContentCategory category;
  final LessonContentType type;
  final int orderIndex;
  final Map<String, dynamic> data;

  const LessonContent({
    required this.id,
    required this.category,
    required this.type,
    required this.orderIndex,
    required this.data,
  });

  factory LessonContent.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final categoryRaw = (map['category'] ?? '').toString().toLowerCase();
    final typeRaw = (map['type'] ?? '').toString().toLowerCase();

    final category =
        stringToLessonContentCategory[categoryRaw] ??
        LessonContentCategory.EXERCISE;
    final type = stringToLessonContentType[typeRaw] ?? LessonContentType.MCQ;

    if (!_isTypeAllowedForCategory(category: category, type: type)) {
      throw FormatException(
        'Invalid lesson content type "$typeRaw" for category "$categoryRaw"',
      );
    }

    final rawData = map['data'];
    final parsedData = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    return LessonContent(
      id: asInt(map['id']),
      category: category,
      type: type,
      orderIndex: asInt(map['orderIndex']),
      data: parsedData,
    );
  }

  MCQ? asMcqOrNull() {
    if (type != LessonContentType.MCQ) return null;

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final rawOptions = data['options'];
    final options = rawOptions is List
        ? rawOptions
              .map((item) => Answer(answer: item?.toString() ?? ''))
              .toList()
        : <Answer>[];

    return MCQ(
      question: (data['question'] ?? '').toString(),
      options: options,
      correctAnswerIndex: asInt(data['correctAnswerIndex']),
    );
  }
}

bool _isTypeAllowedForCategory({
  required LessonContentCategory category,
  required LessonContentType type,
}) {
  switch (category) {
    case LessonContentCategory.LEARNING:
      return LessonContentLearningType.values.any(
        (learningType) => learningType.name == type.name,
      );
    case LessonContentCategory.EXERCISE:
      return LessonContentExcerciseType.values.any(
        (exerciseType) => exerciseType.name == type.name,
      );
  }
}

class MCQ {
  final String question;
  final List<Answer> options;
  final int correctAnswerIndex;
  final String answeredTip;

  MCQ({
    required this.question,
    required this.options,
    this.correctAnswerIndex = 0,
    this.answeredTip =
        'Focus on the core concept and compare all options before choosing.', // tobeadded for each lesson
  });

  String get answerComment => 'Tip: $answeredTip';
}

class Answer {
  final String answer;

  Answer({required this.answer});
}
