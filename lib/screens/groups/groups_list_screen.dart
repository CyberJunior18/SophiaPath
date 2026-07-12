import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/social/group.dart';
import '../../services/social_service.dart';
import '../../services/user_preferences_services.dart';
import '../../models/user/user.dart';
import '../../services/chat/chat_service.dart';
import '../../models/chat/chat_session_user.dart';
import 'group_chat_screen.dart';
import '../../widgets/social/create_group_dialog.dart';
import '../../widgets/profileImage.dart';

class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final SocialService _socialService = SocialService();
  final UserPreferencesService _userService = UserPreferencesService.instance;

  User? _currentUser;
  ChatSessionUser? _chatSessionUser;
  List<Group> _groups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await _userService.getUser();
      if (_currentUser != null) {
        String? userId = await _userService.getUserId();
        if (userId == null || userId.isEmpty) {
          try {
            _chatSessionUser = await ChatService().getCurrentUser();
            userId = _chatSessionUser!.userId.toString();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_id', userId);
          } catch (_) {}
        } else {
          try {
            _chatSessionUser = await ChatService().getCurrentUser();
          } catch (_) {}
        }

        if (userId != null && userId.isNotEmpty) {
          final groups = await _socialService.getGroups(userId);
          if (mounted) {
            setState(() {
              _groups = groups;
            });
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _groups = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else {
      return '${time.day}/${time.month}';
    }
  }

  Widget _buildGroupItem(Group group) {
    final theme = Theme.of(context);
    String subtitleText = group.description;
    if (group.lastMessage != null) {
      if (group.lastMessage is Map) {
        subtitleText = '${group.lastMessageSender ?? 'User'}: ${group.lastMessage['text'] ?? group.lastMessage['message'] ?? ''}';
      } else {
        subtitleText = '${group.lastMessageSender != null ? '${group.lastMessageSender}: ' : ''}${group.lastMessage}';
      }
    } else if (group.description.isEmpty) {
      subtitleText = 'No messages yet';
    }

    DateTime? lastMsgTime;
    if (group.lastMessageTime != null) {
      lastMsgTime = DateTime.tryParse(group.lastMessageTime!);
    } else {
      lastMsgTime = group.createdAt;
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ProfileImage(
        imageUrl: group.avatar,
        radius: 28,
        name: group.name,
      ),
      title: Text(
        group.name,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodyLarge!.color,
        ),
      ),
      subtitle: Text(
        subtitleText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 14,
          color: theme.textTheme.bodyMedium!.color!.withOpacity(0.7),
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMsgTime != null)
            Text(
              _formatTime(lastMsgTime),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: theme.textTheme.bodySmall!.color,
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GroupChatScreen(group: group),
          ),
        ).then((_) => _loadData());
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainer
        : theme.colorScheme.surface;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
          ),
        ),
        title: Text(
          'Groups',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_off, size: 64, color: theme.colorScheme.secondary),
                      const SizedBox(height: 16),
                      Text(
                        'No groups yet',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: theme.textTheme.bodyLarge!.color,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  itemCount: _groups.length,
                  separatorBuilder: (context, index) => Divider(height: 1, color: theme.dividerColor.withOpacity(0.18)),
                  itemBuilder: (context, index) => _buildGroupItem(_groups[index]),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: () async {
          if (_currentUser == null) return;
          if (_chatSessionUser == null) {
            try {
              _chatSessionUser = await ChatService().getCurrentUser();
            } catch (_) {}
          }
          if (_chatSessionUser == null) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to load user profile. Please try again.')),
              );
            }
            return;
          }
          final created = await showDialog<bool>(
            context: context,
            builder: (context) => CreateGroupDialog(
              currentUser: _currentUser!,
              chatSessionUser: _chatSessionUser!,
              socialService: _socialService,
            ),
          );
          if (created == true) {
            _loadData();
          }
        },
        child: Icon(Icons.add, color: theme.colorScheme.onPrimary),
      ),
    );
  }
}
