import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/models/user/user.dart';
import 'package:sophia_path/screens/chat/chat_screen.dart';
import 'package:sophia_path/services/chat/firebase_chat_service.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  late FirebaseChatService _chatService;
  late StreamSubscription? _chatsSubscription;
  final List<Map<String, dynamic>> _chatRooms = [];
  final Map<String, User> _chatUsers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _chatService = FirebaseChatService();
    _loadChats();
  }

  void _loadChats() {
    _chatsSubscription = _chatService.getChatRoomsStream().listen((chatRooms) async {
      setState(() {
        _chatRooms.clear();
        _chatUsers.clear();
        _isLoading = true;
      });
      
      for (final chatRoom in chatRooms) {
        final otherUserId = chatRoom['otherUserId'] as String;
        if (otherUserId.isNotEmpty) {
          final userData = await _chatService.getUserData(otherUserId);
          if (userData != null) {
            final user = User.fromFirestore(userData);
            _chatUsers[otherUserId] = user;
          }
          _chatRooms.add(chatRoom);
        }
      }
      
      if (mounted) {
        setState(() => _isLoading = false);
      }
    });
  }

  Widget _buildChatItem(Map<String, dynamic> chatRoom) {
    final theme = Theme.of(context);
    final otherUserId = chatRoom['otherUserId'] as String;
    final user = _chatUsers[otherUserId];
    
    if (user == null) {
      return const SizedBox.shrink();
    }

    final lastMessageTime = chatRoom['lastMessageTime'] as DateTime?;
    final lastMessage = chatRoom['lastMessage'] as String? ?? '';
    final unreadCount = chatRoom['unreadCount'] as int? ?? 0;
    final chatRoomId = chatRoom['chatRoomId'] as String;

    return GestureDetector(
      onLongPress: () => _showChatOptions(chatRoom, user),
      child: ListTile(
        leading: CircleAvatar(
          radius: 28,
          backgroundImage: user.profileImage.isNotEmpty
              ? NetworkImage(user.profileImage)
              : null,
          backgroundColor: theme.colorScheme.secondary,
          child: user.profileImage.isEmpty
              ? Icon(Icons.person, color: theme.colorScheme.primary, size: 28)
              : null,
        ),
        title: Text(
          user.fullName,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.textTheme.bodyLarge!.color,
          ),
        ),
        subtitle: Text(
          lastMessage,
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
            if (lastMessageTime != null)
              Text(
                _formatTime(lastMessageTime),
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall!.color,
                ),
              ),
            const SizedBox(height: 4),
            if (unreadCount > 0)
              CircleAvatar(
                radius: 10,
                backgroundColor: theme.colorScheme.primary,
                child: Text(
                  unreadCount.toString(),
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              )
            else if (user.isOnline)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
          ],
        ),
        onTap: () async {
          await _chatService.markMessagesAsRead(chatRoomId);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                chatUser: user,
                chatId: chatRoomId,
                chatRoomId: chatRoomId,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _chatsSubscription?.cancel();
    super.dispose();
  }

  void _showChatOptions(Map<String, dynamic> chatRoom, User user) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.notifications),
                title: const Text('Mute notifications'),
                onTap: () {
                  Navigator.pop(context);
                  print('Muting chat: ${user.username}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.pin),
                title: const Text('Pin chat'),
                onTap: () {
                  Navigator.pop(context);
                  print('Pinning chat: ${user.username}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Block user'),
                onTap: () {
                  Navigator.pop(context);
                  print('Blocking user: ${user.username}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete chat'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteChat(chatRoom);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteChat(Map<String, dynamic> chatRoom) {
    final chatRoomId = chatRoom['chatRoomId'] as String;
    print('Deleting chat: $chatRoomId');
    setState(() {
      _chatRooms.removeWhere((c) => c['chatRoomId'] == chatRoomId);
    });
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        title: Text(
          'Chats',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _showSearchDialog(),
          ),
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.white),
            onPressed: () => _createNewGroup(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: _searchChats,
                    decoration: InputDecoration(
                      hintText: 'Search chats...',
                      hintStyle: GoogleFonts.poppins(),
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.secondary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      _chatRooms.clear();
                      _chatUsers.clear();
                      setState(() => _isLoading = true);
                      _loadChats();
                      return Future.delayed(const Duration(seconds: 1));
                    },
                    child: _chatRooms.isEmpty
                        ? const Center(
                            child: Text('No chats yet. Start a conversation!'),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _chatRooms.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 1,
                              color: theme.dividerColor.withOpacity(0.3),
                            ),
                            itemBuilder: (context, index) {
                              return Dismissible(
                                key: Key(_chatRooms[index]['chatRoomId'] as String),
                                background: Container(
                                  color: Colors.red,
                                  alignment: Alignment.centerLeft,
                                  padding: const EdgeInsets.only(left: 20),
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                secondaryBackground: Container(
                                  color: Colors.grey,
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(Icons.archive, color: Colors.white),
                                ),
                                onDismissed: (direction) {
                                  final chatRoom = _chatRooms[index];
                                  if (direction == DismissDirection.startToEnd) {
                                    _deleteChat(chatRoom);
                                  } else {
                                    print('Archiving chat: ${chatRoom['chatRoomId']}');
                                  }
                                },
                                child: _buildChatItem(_chatRooms[index]),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: () => _startNewChat(),
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search Chats'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Enter name or message...'),
          onChanged: _searchChats,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _searchChats(String query) {
    // Implement search logic
  }

  void _createNewGroup() {
    // TODO: Implement group creation
    print('Create new group');
  }

  void _startNewChat() {
    // TODO: Implement new chat screen
    print('Start new chat');
  }
}