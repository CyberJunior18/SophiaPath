import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/social/group_message.dart';

class MessageActionMenu extends StatelessWidget {
  final GroupMessage message;
  final bool isMyMessage;
  final VoidCallback onReply;
  final VoidCallback onForward;
  final VoidCallback onPin;
  final VoidCallback onStar;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback? onEdit;

  const MessageActionMenu({
    super.key,
    required this.message,
    required this.isMyMessage,
    required this.onReply,
    required this.onForward,
    required this.onPin,
    required this.onStar,
    required this.onCopy,
    required this.onDelete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.reply),
            title: Text('Reply', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              onReply();
            },
          ),
          ListTile(
            leading: const Icon(Icons.forward),
            title: Text('Forward', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              onForward();
            },
          ),
          ListTile(
            leading: Icon(message.pinned ? Icons.push_pin_outlined : Icons.push_pin),
            title: Text(message.pinned ? 'Unpin' : 'Pin', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              onPin();
            },
          ),
          ListTile(
            leading: const Icon(Icons.star_border),
            title: Text('Star', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              onStar();
            },
          ),
          ListTile(
            leading: const Icon(Icons.copy),
            title: Text('Copy Text', style: GoogleFonts.poppins()),
            onTap: () {
              Navigator.pop(context);
              onCopy();
            },
          ),
          if (isMyMessage && onEdit != null)
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text('Edit', style: GoogleFonts.poppins()),
              onTap: () {
                Navigator.pop(context);
                onEdit!();
              },
            ),
          if (isMyMessage)
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                onDelete();
              },
            ),
        ],
      ),
    );
  }
}
