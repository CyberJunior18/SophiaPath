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
  final List<String> sections;
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
    List<String> parsedSections = const [];

    if (rawSections is String && rawSections.trim().isNotEmpty) {
      final decoded = jsonDecode(rawSections);
      if (decoded is List) {
        parsedSections = decoded.map((item) => item.toString()).toList();
      }
    } else if (rawSections is List) {
      parsedSections = rawSections.map((item) => item.toString()).toList();
    }

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

    final dynamic rawLessons = map['lessons'];
    final int lessonsCount = rawLessons is List ? rawLessons.length : 0;
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
          : (lessonsCount > 0 ? lessonsCount : parsedSections.length),
      about: map['about']?.toString() ?? '',
      imageUrl: (map['image_url'] ?? map['imageUrl'] ?? '').toString(),
      sections: parsedSections,
      lessons: _parseLessons(rawLessons),
    );
  }
}
