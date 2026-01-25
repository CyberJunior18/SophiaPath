import 'dart:convert';

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

  CourseInfo({
    this.id,
    required this.title,
    required this.description,
    required this.numberOfFinishedLessons,
    required this.totalLessons,
    required this.about,
    required this.imageUrl,
    required this.sections,
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
    return CourseInfo(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      numberOfFinishedLessons: map['number_of_finished_lessons'] ?? 0,
      totalLessons: map['total_lessons'] ?? 0,
      about: map['about'],
      imageUrl: map['image_url'],
      sections:
          (jsonDecode(map['sections']) as List)
              .map((item) => item.toString())
              .toList(),
    );
  }
}
