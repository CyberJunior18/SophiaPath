import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat/chat_message.dart';

class DmMessageActionMenu extends StatelessWidget {
  final ChatMessage message;
  final bool isMyMessage;
  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onPin;
  final VoidCallback onStar;
  final VoidCallback onCopy;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const DmMessageActionMenu({
    super.key,
    required this.message,
    required this.isMyMessage,
    required this.onReply,
    required this.onForward,
    required this.onPin,
    required this.onStar,
    required this.onCopy,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Preview of message
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      message.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _buildActionTile(
              context,
              icon: Icons.reply,
              label: 'Reply',
              onTap: () {
                Navigator.pop(context);
                onReply();
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.copy,
              label: 'Copy',
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.message));
                Navigator.pop(context);
                onCopy();
              },
            ),
            _buildActionTile(
              context,
              icon: message.pinned ? Icons.push_pin : Icons.push_pin_outlined,
              label: message.pinned ? 'Unpin' : 'Pin',
              onTap: () {
                Navigator.pop(context);
                onPin();
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.star_outline,
              label: 'Star',
              onTap: () {
                Navigator.pop(context);
                onStar();
              },
            ),
            _buildActionTile(
              context,
              icon: Icons.forward,
              label: 'Forward',
              onTap: () {
                Navigator.pop(context);
                onForward();
              },
            ),
            if (isMyMessage && onEdit != null)
              _buildActionTile(
                context,
                icon: Icons.edit,
                label: 'Edit',
                onTap: () {
                  Navigator.pop(context);
                  onEdit!();
                },
              ),
            if (isMyMessage && onDelete != null)
              _buildActionTile(
                context,
                icon: Icons.delete_outline,
                label: 'Delete',
                color: theme.colorScheme.error,
                onTap: () {
                  Navigator.pop(context);
                  onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final itemColor = color ?? theme.colorScheme.onSurface;

    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: itemColor),
      title: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: itemColor,
        ),
      ),
      onTap: onTap,
    );
  }
}
