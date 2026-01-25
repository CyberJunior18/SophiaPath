import 'package:flutter/material.dart';

class Achievement {
  final IconData icon;
  final String name;
  final String description;
  final double progress;
  final int target;
  final bool isUnlocked;
  final AchievementType type;
  final Color color;

  Achievement({
    required this.icon,
    required this.name,
    required this.description,
    this.progress = 0,
    required this.target,
    this.isUnlocked = false,
    required this.type,
    required this.color,
  });

  double get percentage => (progress / target).clamp(0.0, 1.0);
  bool get isCompleted => progress >= target;

  Achievement copyWith({double? progress, bool? isUnlocked}) {
    return Achievement(
      icon: icon,
      name: name,
      description: description,
      progress: progress ?? this.progress,
      target: target,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      type: type,
      color: color,
    );
  }
}

enum AchievementType {
  courseCompletion,
  perfectScore,
  streak,
  speed,
  consistency,
  explorer,
  master,
  social,
}

double iconSize = 30;
