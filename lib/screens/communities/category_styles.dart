import 'package:flutter/material.dart';

class CategoryStyle {
  final String icon;
  final Color color;
  final Color bg;

  const CategoryStyle(this.icon, this.color, this.bg);
}

final Map<String, CategoryStyle> categoryStyles = {
  'Software Engineering': CategoryStyle('💻', const Color(0xFF3D5CFF), const Color(0x143D5CFF)),
  'Artificial Intelligence & ML': CategoryStyle('🧠', const Color(0xFF8B5CF6), const Color(0x148B5CF6)),
  'Data Science & Analytics': CategoryStyle('📊', const Color(0xFF10B981), const Color(0x1410B981)),
  'Cybersecurity & Networking': CategoryStyle('🛡️', const Color(0xFFEF4444), const Color(0x14EF4444)),
  'Mobile Development': CategoryStyle('📱', const Color(0xFFEC4899), const Color(0x14EC4899)),
  'Cloud Computing & DevOps': CategoryStyle('☁️', const Color(0xFF0EA5E9), const Color(0x140EA5E9)),
  'Web Development': CategoryStyle('🌐', const Color(0xFFF59E0B), const Color(0x14F59E0B)),
  'UI/UX Design': CategoryStyle('🎨', const Color(0xFFF43F5E), const Color(0x14F43F5E)),
  'Blockchain & Web3': CategoryStyle('⛓️', const Color(0xFF6366F1), const Color(0x146366F1)),
  'Product Management': CategoryStyle('🚀', const Color(0xFF14B8A6), const Color(0x1414B8A6)),
  'Mathematics & Statistics': CategoryStyle('📐', const Color(0xFF06B6D4), const Color(0x1406B6D4)),
  'Physics & Astronomy': CategoryStyle('🌌', const Color(0xFF3F51B5), const Color(0x143F51B5)),
  'Chemistry & Material Sciences': CategoryStyle('🧪', const Color(0xFF4CAF50), const Color(0x144CAF50)),
  'Biology & Biotechnology': CategoryStyle('🧬', const Color(0xFF009688), const Color(0x14009688)),
  'Medicine & Health Sciences': CategoryStyle('🏥', const Color(0xFFE91E63), const Color(0x14E91E63)),
  'Economics & Finance': CategoryStyle('📈', const Color(0xFFFF5722), const Color(0x14FF5722)),
  'History & Social Sciences': CategoryStyle('🏛️', const Color(0xFF795548), const Color(0x14795548)),
  'Languages & Linguistics': CategoryStyle('🗣️', const Color(0xFF9C27B0), const Color(0x149C27B0)),
  'Art & Creative Writing': CategoryStyle('✍️', const Color(0xFF673AB7), const Color(0x14673AB7)),
  'Business & Entrepreneurship': CategoryStyle('💼', const Color(0xFF607D8B), const Color(0x14607D8B)),
};

final List<String> communityCategories = categoryStyles.keys.toList();
