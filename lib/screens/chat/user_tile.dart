import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/widgets/profileImage.dart';

class UserTile extends StatelessWidget {
  final String text;
  final String? subtitle;
  final String? imageUrl;
  final bool isOnline;
  final int unreadCount; // ✅ Add this
  final VoidCallback onTap;

  const UserTile({
    super.key,
    required this.text,
    this.subtitle,
    this.imageUrl,
    this.isOnline = false,
    this.unreadCount = 0, // ✅ Default to 0
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Stack(
        children: [
          ProfileImage(imageUrl: imageUrl, radius: 24, name: text),
          if (isOnline)
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        text,
        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
      ),
      trailing: _buildTrailing(),
      onTap: onTap,
    );
  }

  Widget _buildTrailing() {
    if (unreadCount > 0) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
        child: Text(
          unreadCount > 9 ? '9+' : unreadCount.toString(),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
