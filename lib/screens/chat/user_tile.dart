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
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? theme.colorScheme.surfaceContainer
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                    color: theme.colorScheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surface,
                      width: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          subtitle ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: _buildTrailing(context),
        onTap: onTap,
      ),
    );
  }

  Widget _buildTrailing(BuildContext context) {
    if (unreadCount > 0) {
      return Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
        child: Text(
          unreadCount > 9 ? '9+' : unreadCount.toString(),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimary,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
