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

    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    List<Lesson> parseLessons(dynamic value) {
      if (value is! List) return const [];

      return value.whereType<Map>().map((item) {
        final lessonMap = Map<String, dynamic>.from(item);
        return Lesson.fromMap(lessonMap);
      }).toList();
    }

    List<Lesson> parseSections(dynamic value) {
      if (value is String && value.trim().isNotEmpty) {
        try {
          final decoded = jsonDecode(value);
          return parseSections(decoded);
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

    List<Lesson> parseLessonsFromSections(dynamic sectionsValue) {
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

      return parseLessons(sectionMaps);
    }

    parsedSections = parseSections(rawSections);

    final dynamic rawLessons = map['lessons'];
    final parsedLessons = rawLessons is List && rawLessons.isNotEmpty
        ? parseLessons(rawLessons)
        : parseLessonsFromSections(rawSections);
    final int parsedTotalLessons = asInt(
      map['total_lessons'] ?? map['totalLessons'],
    );

    String rawImageUrl = (map['image_url'] ?? map['imageUrl'] ?? '').toString();
    if (rawImageUrl.contains('dropbox.com')) {
      if (rawImageUrl.contains('dl=0')) {
        rawImageUrl = rawImageUrl.replaceAll('dl=0', 'raw=1');
      } else if (!rawImageUrl.contains('raw=1')) {
        rawImageUrl += '${rawImageUrl.contains('?') ? '&' : '?'}raw=1';
      }
    }

    return CourseInfo(
      id: asInt(map['id']),
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      numberOfFinishedLessons: asInt(
        map['number_of_finished_lessons'] ?? map['lessonsDoneCount'],
      ),
      totalLessons: parsedTotalLessons > 0
          ? parsedTotalLessons
          : (parsedLessons.isNotEmpty
                ? parsedLessons.length
                : parsedSections.length),
      about: map['about']?.toString() ?? '',
      imageUrl: rawImageUrl,
      sections: parsedSections,
      lessons: parsedLessons,
    );
  }
}
