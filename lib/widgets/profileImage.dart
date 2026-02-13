import 'package:flutter/material.dart';

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
      return NetworkImage(imageUrl!);
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
