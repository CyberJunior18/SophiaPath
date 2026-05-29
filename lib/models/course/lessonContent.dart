// ignore_for_file: public_member_api_docs, sort_constructors_first, constant_identifier_names, non_constant_identifier_names
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

class LessonPage {
  final int pageId;
  final String pageTitle;
  final int orderIndex;
  final List<LessonBlock> blocks;

  const LessonPage({
    required this.pageId,
    required this.pageTitle,
    required this.orderIndex,
    required this.blocks,
  });

  factory LessonPage.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final dynamic rawBlocks = map['blocks'];
    final blocks = rawBlocks is List
        ? rawBlocks
              .whereType<Map>()
              .map(
                (item) => LessonBlock.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const <LessonBlock>[];

    return LessonPage(
      pageId: asInt(map['pageId'] ?? map['id']),
      pageTitle: (map['pageTitle'] ?? map['title'] ?? '').toString(),
      orderIndex: asInt(map['orderIndex']),
      blocks: blocks,
    );
  }
}

class LessonBlock {
  final Map<String, dynamic> raw;

  const LessonBlock({required this.raw});

  factory LessonBlock.fromMap(Map<String, dynamic> map) {
    return LessonBlock(raw: Map<String, dynamic>.from(map));
  }

  String get type => (raw['type'] ?? '').toString().toLowerCase();

  String get text => (raw['text'] ?? '').toString();

  int get level {
    final value = raw['level'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 1;
  }

  String get variant => (raw['variant'] ?? '').toString().toLowerCase();

  List<Map<String, dynamic>> get items {
    final dynamic rawItems = raw['items'];
    if (rawItems is! List) return const [];

    return rawItems
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<String> get headers {
    final dynamic rawHeaders = raw['headers'];
    if (rawHeaders is! List) return const [];

    return rawHeaders.map((item) => item.toString()).toList();
  }

  List<List<Map<String, dynamic>>> get rows {
    final dynamic rawRows = raw['rows'];
    if (rawRows is! List) return const [];

    return rawRows
        .whereType<List>()
        .map(
          (row) => row
              .whereType<Map>()
              .map((cell) => Map<String, dynamic>.from(cell))
              .toList(),
        )
        .toList();
  }
}

class LessonContent {
  final int id;
  final LessonContentCategory category;
  final LessonContentType type;
  final int orderIndex;
  final String partTitle;
  final String chapterName;
  final List<LessonPage> pages;
  final Map<String, dynamic> data;
  final int timeToFinish; //hours

  const LessonContent({
    required this.id,
    required this.category,
    required this.type,
    required this.orderIndex,
    required this.partTitle,
    this.chapterName = '',
    required this.pages,
    required this.data,
    required this.timeToFinish,
  });

  static LessonContentType _inferTypeFromRawPages(dynamic rawPages) {
    if (rawPages is! List || rawPages.isEmpty) {
      return LessonContentType.TEXT;
    }

    for (final pageItem in rawPages.whereType<Map>()) {
      final page = Map<String, dynamic>.from(pageItem);
      final hasQuizFields =
          page.containsKey('question') ||
          page.containsKey('answers') ||
          page.containsKey('correctAnswer') ||
          page.containsKey('correctAnswerIndex');

      if (hasQuizFields) {
        return LessonContentType.MCQ;
      }

      final rawBlocks = page['blocks'];
      if (rawBlocks is List) {
        for (final blockItem in rawBlocks.whereType<Map>()) {
          final block = Map<String, dynamic>.from(blockItem);
          final blockType = (block['type'] ?? '').toString().toLowerCase();
          if (blockType == 'mcq' ||
              blockType == 'fill_code' ||
              blockType == 'find_error') {
            return LessonContentType.MCQ;
          }
        }
      }
    }

    return LessonContentType.TEXT;
  }

  factory LessonContent.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final dynamic rawPages = map['pages'];
    final parsedPages = rawPages is List
        ? rawPages
              .whereType<Map>()
              .map(
                (item) => LessonPage.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList()
        : const <LessonPage>[];

    final categoryRaw = (map['category'] ?? '').toString().toLowerCase();
    final typeRaw = (map['type'] ?? '').toString().toLowerCase();
    final bool hasPages = parsedPages.isNotEmpty;

    final inferredType = typeRaw.isNotEmpty
        ? stringToLessonContentType[typeRaw]
        : _inferTypeFromRawPages(rawPages);

    final category =
        stringToLessonContentCategory[categoryRaw] ??
        (hasPages
            ? LessonContentCategory.LEARNING
            : LessonContentCategory.EXERCISE);
    final type =
        inferredType ??
        (category == LessonContentCategory.EXERCISE
            ? LessonContentType.MCQ
            : LessonContentType.TEXT);

    if (!_isTypeAllowedForCategory(category: category, type: type)) {
      throw FormatException(
        'Invalid lesson content type "$typeRaw" for category "$categoryRaw"',
      );
    }

    final rawData = map['data'];
    final parsedData = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : Map<String, dynamic>.from(map);

    return LessonContent(
      id: asInt(map['id'] ?? map['pageId']),
      category: category,
      type: type,
      orderIndex: asInt(map['orderIndex']),
      partTitle: (map['partTitle'] ?? map['pageTitle'] ?? '').toString(),
      chapterName: (map['chapterName'] ?? '').toString(),
      pages: parsedPages,
      data: parsedData,
      timeToFinish: asInt(map['timeToFinish']),
    );
  }

  MCQ? asMcqOrNull() {
    if (type != LessonContentType.MCQ) return null;

    final questions = extractQuestions();
    if (questions.isNotEmpty) return questions.first;

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final rawOptions = data['options'];
    final options = rawOptions is List
        ? rawOptions
              .map(
                (item) => Answer(
                  answer: item is Map
                      ? (item['answer'] ?? '').toString()
                      : item?.toString() ?? '',
                ),
              )
              .toList()
        : <Answer>[];

    return MCQ(
      question: (data['question'] ?? '').toString(),
      options: options,
      correctAnswerIndex: asInt(data['correctAnswerIndex']),
    );
  }

  List<MCQ> extractQuestions() {
    final rawPages = data['pages'];
    if (rawPages is! List) return const [];

    final questions = <MCQ>[];

    for (final pageItem in rawPages.whereType<Map>()) {
      final page = Map<String, dynamic>.from(pageItem);
      final pageTitle = (page['pageTitle'] ?? page['title'] ?? '').toString();
      final rawBlocks = page['blocks'];

      if (rawBlocks is List && rawBlocks.isNotEmpty) {
        for (final blockItem in rawBlocks.whereType<Map>()) {
          final question = MCQ.fromExerciseMap(
            Map<String, dynamic>.from(blockItem),
            fallbackTitle: pageTitle,
          );
          if (question != null) questions.add(question);
        }
        continue;
      }

      final question = MCQ.fromExerciseMap(page, fallbackTitle: pageTitle);
      if (question != null) questions.add(question);
    }

    return questions;
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
  final String exerciseType;
  final String instruction;
  final String fileName;
  final String codeLanguage;
  final List<CodeTemplateLine> codeTemplateLines;
  final List<String> codeSnippetLines;

  MCQ({
    required this.question,
    required this.options,
    this.correctAnswerIndex = 0,
    this.answeredTip =
        'Focus on the core concept and compare all options before choosing.', // tobeadded for each lesson
    this.exerciseType = 'mcq',
    this.instruction = '',
    this.fileName = '',
    this.codeLanguage = '',
    this.codeTemplateLines = const [],
    this.codeSnippetLines = const [],
  });

  String get answerComment => 'Tip: $answeredTip';

  bool get isFillCode => exerciseType == 'fill_code';
  bool get hasCodeSnippet => codeSnippetLines.isNotEmpty;

  List<CodeTemplateLine> get inputLines =>
      codeTemplateLines.where((line) => line.type == 'input').toList();

  factory MCQ.fillCode({
    required String instruction,
    required String fileName,
    required String codeLanguage,
    required List<CodeTemplateLine> codeTemplateLines,
  }) {
    return MCQ(
      question: instruction,
      options: const [],
      instruction: instruction,
      fileName: fileName,
      codeLanguage: codeLanguage,
      codeTemplateLines: codeTemplateLines,
      exerciseType: 'fill_code',
      answeredTip: 'Compare each blank with the surrounding code.',
    );
  }

  static MCQ? fromExerciseMap(
    Map<String, dynamic> map, {
    String fallbackTitle = '',
  }) {
    final type = (map['type'] ?? 'mcq').toString().toLowerCase();

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    List<Answer> parseOptions(dynamic rawOptions) {
      if (rawOptions is! List) return const [];

      return rawOptions
          .map(
            (item) => Answer(
              answer: item is Map
                  ? (item['answer'] ?? '').toString()
                  : item?.toString() ?? '',
            ),
          )
          .where((answer) => answer.answer.isNotEmpty)
          .toList();
    }

    if (type == 'fill_code') {
      final rawTemplate = map['codeTemplate'];
      final template = rawTemplate is Map
          ? Map<String, dynamic>.from(rawTemplate)
          : <String, dynamic>{};
      final rawLines = template['lines'];
      final codeLines = rawLines is List
          ? rawLines
                .whereType<Map>()
                .map(
                  (line) =>
                      CodeTemplateLine.fromMap(Map<String, dynamic>.from(line)),
                )
                .toList()
          : const <CodeTemplateLine>[];

      if (codeLines.isEmpty) return null;

      return MCQ.fillCode(
        instruction: (map['instruction'] ?? fallbackTitle).toString(),
        fileName: (map['fileName'] ?? '').toString(),
        codeLanguage: (template['language'] ?? '').toString(),
        codeTemplateLines: codeLines,
      );
    }

    final rawSnippet = map['codeSnippet'];
    final snippet = rawSnippet is Map
        ? Map<String, dynamic>.from(rawSnippet)
        : <String, dynamic>{};
    final rawSnippetLines = snippet['lines'];
    final snippetLines = rawSnippetLines is List
        ? rawSnippetLines.map((line) => line.toString()).toList()
        : const <String>[];

    final question = (map['question'] ?? map['instruction'] ?? fallbackTitle)
        .toString();
    final options = parseOptions(map['options'] ?? map['answers']);

    if (question.isEmpty || options.isEmpty) return null;

    return MCQ(
      question: question,
      options: options,
      correctAnswerIndex: map.containsKey('correctAnswerIndex')
          ? asInt(map['correctAnswerIndex'])
          : asInt(map['correctAnswer']),
      exerciseType: type == 'find_error' ? 'find_error' : 'mcq',
      instruction: (map['instruction'] ?? question).toString(),
      fileName: (map['fileName'] ?? '').toString(),
      codeLanguage: (snippet['language'] ?? '').toString(),
      codeSnippetLines: snippetLines,
      answeredTip: type == 'find_error'
          ? 'Read the code from top to bottom and check the syntax carefully.'
          : 'Focus on the core concept and compare all options before choosing.',
    );
  }
}

class Answer {
  final String answer;

  Answer({required this.answer});
}

class CodeTemplateLine {
  final String type;
  final String content;
  final int width;
  final String expectedAnswer;

  const CodeTemplateLine({
    required this.type,
    this.content = '',
    this.width = 6,
    this.expectedAnswer = '',
  });

  factory CodeTemplateLine.fromMap(Map<String, dynamic> map) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return CodeTemplateLine(
      type: (map['type'] ?? 'code').toString().toLowerCase(),
      content: (map['content'] ?? '').toString(),
      width: asInt(map['width']) > 0 ? asInt(map['width']) : 6,
      expectedAnswer: (map['expectedAnswer'] ?? '').toString(),
    );
  }
}

// Backend now refers to section content items as "Lesson".
typedef Lesson = LessonContent;
