import 'dart:convert';

import 'lesson.dart';

class CourseInfo {
  final int? id;
  final String title;
  final String description;
  final int numberOfFinishedLessons;
  final int totalLessons;
  final String about;
  final String imageUrl;
  final List<Lesson> sections;
  final double progress;
  final bool isCompleted;
  final List<Lesson> lessons;
  CourseInfo({
    this.id,
    required this.title,
    required this.description,
    required this.numberOfFinishedLessons,
    required this.totalLessons,
    required this.about,
    required this.imageUrl,
    required this.sections,
    required this.lessons,
  }) : progress = totalLessons > 0 ? numberOfFinishedLessons / totalLessons : 0,
       isCompleted = numberOfFinishedLessons >= totalLessons;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'number_of_finished_lessons': numberOfFinishedLessons,
      'total_lessons': totalLessons,
      'about': about,
      'image_url': imageUrl,
      'is_completed': isCompleted ? 1 : 0,
      'progress': progress,
    };
  }

  factory CourseInfo.fromMap(Map<String, dynamic> map) {
    final dynamic rawSections = map['sections'];
    List<Lesson> parsedSections = const [];

    int _asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    List<Lesson> _parseLessons(dynamic value) {
      if (value is! List) return const [];

      return value.whereType<Map>().map((item) {
        final lessonMap = Map<String, dynamic>.from(item);
        return Lesson.fromMap(lessonMap);
      }).toList();
    }

    List<Lesson> _parseSections(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          return _parseSections(decoded);
        } catch (_) {
          return const [];
        }
      }

      if (value is! List) return const [];

      return value.whereType<Map>().map((item) {
        final sectionMap = Map<String, dynamic>.from(item);
        return Lesson.fromMap(sectionMap);
      }).toList();
    }

    List<Lesson> _parseLessonsFromSections(dynamic sectionsValue) {
      if (sectionsValue is! List) return const [];

      final sectionMaps = sectionsValue
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();

      if (sectionMaps.isEmpty) return const [];

      final nestedLessons = sectionMaps
          .expand((section) {
            final dynamic sectionLessons = section['lessons'];
            if (sectionLessons is! List) return const <dynamic>[];
            return sectionLessons;
          })
          .whereType<Map>()
          .map((item) => Lesson.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      if (nestedLessons.isNotEmpty) {
        return nestedLessons;
      }

      return _parseLessons(sectionMaps);
    }

    parsedSections = _parseSections(rawSections);

    final dynamic rawLessons = map['lessons'];
    final parsedLessons = rawLessons is List && rawLessons.isNotEmpty
        ? _parseLessons(rawLessons)
        : _parseLessonsFromSections(rawSections);
    final int parsedTotalLessons = _asInt(
      map['total_lessons'] ?? map['totalLessons'],
    );

    return CourseInfo(
      id: _asInt(map['id']),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      numberOfFinishedLessons: _asInt(
        map['number_of_finished_lessons'] ?? map['lessonsDoneCount'],
      ),
      totalLessons: parsedTotalLessons > 0
          ? parsedTotalLessons
          : (parsedLessons.isNotEmpty
                ? parsedLessons.length
                : parsedSections.length),
      about: map['about']?.toString() ?? '',
      imageUrl: (map['image_url'] ?? map['imageUrl'] ?? '').toString(),
      sections: parsedSections,
      lessons: parsedLessons,
    );
  }
}
