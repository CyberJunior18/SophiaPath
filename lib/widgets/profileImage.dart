import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'base64_image_cache.dart';

class ProfileImage extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? name;

  const ProfileImage({super.key, this.imageUrl, this.radius = 25, this.name});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundImage: _getImageProvider(),
      backgroundColor: Colors.grey[300],
      onBackgroundImageError: imageUrl != null && imageUrl!.isNotEmpty
          ? (_, __) {}
          : null,
      child: _buildFallback(),
    );
  }

  ImageProvider? _getImageProvider() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return null;
    }

    try {
      final value = imageUrl!.trim();
      if (value.startsWith('http://') || value.startsWith('https://')) {
        return NetworkImage(value);
      }

      if (value.startsWith('data:image/')) {
        final base64String = value.split(',').last;
        return MemoryImage(Base64ImageCache.decode(base64String));
      }

      if (value.length > 100 && !value.contains('/') && !value.contains('\\')) {
        return MemoryImage(Base64ImageCache.decode(value));
      }

      if (!kIsWeb) {
        return FileImage(File(value));
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  Widget? _buildFallback() {
    // If no image, show initials
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Text(
        _getInitials(),
        style: TextStyle(
          fontSize: radius * 0.6,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }
    return null;
  }

  String _getInitials() {
    if (name == null || name!.isEmpty) return '?';

    List<String> nameParts = name!.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name![0].toUpperCase();
  }
}
