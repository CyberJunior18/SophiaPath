import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat/chat_contact.dart';
import '../../models/chat/chat_message.dart';
import '../../models/user/user.dart'; // Use your existing User model
import 'chat_screen.dart';
import '../../services/chat/chat_service.dart';
import '../../widgets/profileImage.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final ChatService _chatService = ChatService();
  StreamSubscription<ChatMessage>? _messageSubscription;
  final List<ChatContact> _contacts = [];
  final List<User> _chatUsers = []; // Using your User model
  final List<Map<String, dynamic>> _allBackendUsers =
      []; // All users from backend
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void initState() {
    super.initState();
    _loadChatContacts(initial: true);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageSubscription?.cancel();
    _chatService.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults.clear();
      });
    } else {
      setState(() {
        _isSearching = true;
        _searchResults = _allBackendUsers.where((user) {
          final fullName = (user['fullname'] ?? '').toString().toLowerCase();
          final username = (user['username'] ?? '').toString().toLowerCase();
          final query = _searchController.text.toLowerCase();
          return fullName.contains(query) || username.contains(query);
        }).toList();
      });
    }
  }

  Future<void> _loadChatContacts({bool initial = false}) async {
    if (!mounted) return;

    if (initial) {
      setState(() {
        _isLoading = true;
        _contacts.clear();
        _chatUsers.clear();
      });
    }

    try {
      final currentUser = await _chatService.getCurrentUser();

      // Connect socket if not connected
      _chatService.connect(currentUser.userId);

      // Listen to incoming messages for real-time updates
      if (_messageSubscription == null) {
        _messageSubscription = _chatService.incomingMessages.listen((message) {
          _handleIncomingMessage(message, currentUser.userId);
        });
      }

      final allUsers = await _chatService.getAllUsers();
      final contacts = <ChatContact>[];
      final users = <User>[];

      // Store all backend users for search
      if (mounted) {
        setState(() {
          _allBackendUsers.clear();
          _allBackendUsers.addAll(
            allUsers.where((u) => (u['id'] as int?) != currentUser.userId),
          );
        });
      }

      // Fetch conversations from the backend
      final conversations = await _chatService.getUserConversations(currentUser.userId);

      // Fetch history for active conversations in parallel
      final histories = await Future.wait(
        conversations.map((conv) {
          final otherUserId = conv['userId1'] == currentUser.userId ? conv['userId2'] : conv['userId1'];
          return _chatService.getConversationHistory(currentUser.userId, otherUserId);
        }),
      );

      for (var i = 0; i < conversations.length; i++) {
        final conv = conversations[i];
        final history = histories[i];
        final otherUserId = conv['userId1'] == currentUser.userId ? conv['userId2'] : conv['userId1'];

        final userData = allUsers.firstWhere(
          (u) => u['id'] == otherUserId,
          orElse: () => <String, dynamic>{},
        );
        if (userData.isEmpty) continue;

        final unreadCount = history
            .where(
              (message) =>
                  message.recipientId == currentUser.userId &&
                  !message.read,
            )
            .length;

        final lastMsg = conv['lastMessage'];
        final lastMsgText = lastMsg != null ? (lastMsg['message'] ?? '') as String : '';
        final lastMsgTimeStr = conv['lastMessageTime'] as String?;
        final lastMsgTime = lastMsgTimeStr != null
            ? (DateTime.tryParse(lastMsgTimeStr) ?? DateTime.now())
            : DateTime.now();

        contacts.add(
          ChatContact(
            userId: otherUserId.toString(),
            chatId: conv['id'] as String? ?? 'conversation-${currentUser.userId}-$otherUserId',
            lastMessageTime: lastMsgTime,
            lastMessage: lastMsgText,
            unreadCount: unreadCount,
          ),
        );

        users.add(
          User(
            username: (userData['username'] ?? 'user$otherUserId') as String,
            fullName: (userData['fullname'] ?? 'User $otherUserId') as String,
            tag: (userData['tag'] ?? '') as String,
            age: (userData['age'] ?? 0) as int,
            sex: (userData['gender'] ?? 'Not specified') as String,
            profileImage: (userData['avatar'] ?? userData['profileImage'] ?? '').toString(),
            achievementsProgress: const [],
            registeredCourses: const [],
            registedCoursesIndexes: const [],
          )
            ..isOnline = true
            ..lastSeen = lastMsgTime,
        );
      }

      if (!mounted) return;
      setState(() {
        _contacts.clear();
        _chatUsers.clear();
        _contacts.addAll(contacts);
        _chatUsers.addAll(users);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleIncomingMessage(ChatMessage message, int currentUserId) {
    if (!mounted) return;

    final otherUserId = message.senderId == currentUserId ? message.recipientId : message.senderId;
    final otherUserIdStr = otherUserId.toString();

    // Check if we already have this contact in our active list
    final existingIndex = _contacts.indexWhere((c) => c.userId == otherUserIdStr);

    if (existingIndex >= 0) {
      setState(() {
        final contact = _contacts[existingIndex];
        final user = _chatUsers[existingIndex];

        final updatedContact = ChatContact(
          userId: contact.userId,
          chatId: contact.chatId,
          lastMessageTime: message.timestamp,
          lastMessage: message.message,
          unreadCount: message.senderId != currentUserId ? contact.unreadCount + 1 : contact.unreadCount,
        );

        // Move to the top
        _contacts.removeAt(existingIndex);
        _contacts.insert(0, updatedContact);

        user.lastSeen = message.timestamp;
        _chatUsers.removeAt(existingIndex);
        _chatUsers.insert(0, user);
      });
    } else {
      // New conversation! Find this user in all backend users
      final userData = _allBackendUsers.firstWhere(
        (u) => u['id'] == otherUserId,
        orElse: () => <String, dynamic>{},
      );

      if (userData.isNotEmpty) {
        setState(() {
          _contacts.insert(
            0,
            ChatContact(
              userId: otherUserIdStr,
              chatId: 'conversation-$currentUserId-$otherUserId',
              lastMessageTime: message.timestamp,
              lastMessage: message.message,
              unreadCount: message.senderId != currentUserId ? 1 : 0,
            ),
          );

          _chatUsers.insert(
            0,
            User(
              username: (userData['username'] ?? 'user$otherUserId') as String,
              fullName: (userData['fullname'] ?? 'User $otherUserId') as String,
              tag: (userData['tag'] ?? '') as String,
              age: (userData['age'] ?? 0) as int,
              sex: (userData['gender'] ?? 'Not specified') as String,
              profileImage: (userData['avatar'] ?? userData['profileImage'] ?? '').toString(),
              achievementsProgress: const [],
              registeredCourses: const [],
              registedCoursesIndexes: const [],
            )
              ..isOnline = true
              ..lastSeen = message.timestamp,
          );
        });
      } else {
        // If not in cache, reload the list silently
        _loadChatContacts(initial: false);
      }
    }
  }

  Widget _buildSearchResultItem(Map<String, dynamic> userData) {
    final theme = Theme.of(context);
    final userId = userData['id'] as int? ?? 0;
    final fullName = userData['fullname'] ?? 'User $userId';
    final username = userData['username'] ?? 'user$userId';
    final tag = userData['tag'] ?? '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ProfileImage(
        imageUrl: (userData['avatar'] ?? userData['profileImage'] ?? '').toString(),
        radius: 24,
        name: fullName,
      ),
      title: Text(
        fullName,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodyLarge!.color,
        ),
      ),
      subtitle: Text(
        '@$username${tag.isNotEmpty ? ' • $tag' : ''}',
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: theme.textTheme.bodyMedium!.color!.withOpacity(0.7),
        ),
      ),
      trailing: Icon(Icons.chevron_right, color: theme.colorScheme.primary),
      onTap: () => _startChatWithUser(userId, fullName),
    );
  }

  Future<void> _startChatWithUser(int userId, String displayName) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          receiverEmail: displayName,
          receiverID: userId.toString(),
        ),
      ),
    ).then((_) {
      _searchController.clear();
      _loadChatContacts(initial: false);
    });
  }

  String _displayNameForContact(int index) {
    if (index < _chatUsers.length) {
      return _chatUsers[index].fullName;
    }

    return 'Conversation ${_contacts[index].userId}';
  }

  String _avatarForContact(int index) {
    if (index < _chatUsers.length &&
        _chatUsers[index].profileImage.isNotEmpty) {
      return _chatUsers[index].profileImage;
    }

    return User.defaultProfileImage;
  }

  Widget _buildChatItem(int index) {
    final contact = _contacts[index];
    final theme = Theme.of(context);
    final displayName = _displayNameForContact(index);
    final avatar = _avatarForContact(index);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: ProfileImage(
        imageUrl: avatar,
        radius: 28,
        name: displayName,
      ),
      title: Text(
        displayName,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: theme.textTheme.bodyLarge!.color,
        ),
      ),
      subtitle: Text(
        contact.lastMessage,
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
          Text(
            _formatTime(contact.lastMessageTime),
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: theme.textTheme.bodySmall!.color,
            ),
          ),
          const SizedBox(height: 4),
          if (contact.unreadCount > 0)
            CircleAvatar(
              radius: 10,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                contact.unreadCount.toString(),
                style: TextStyle(
                  fontSize: 10,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            )
          else if (index < _chatUsers.length && _chatUsers[index].isOnline)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiary,
                borderRadius: BorderRadius.circular(5),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              receiverEmail: displayName,
              receiverID: contact.userId,
            ),
          ),
        ).then((_) {
          _searchController.clear();
          _loadChatContacts(initial: false);
        });
      },
      onLongPress: () {
        if (index < _chatUsers.length) {
          _showChatOptions(contact, _chatUsers[index]);
        }
      },
    );
  }

  // Widget _buildChatItem(ChatContact contact) {
  //   final theme = Theme.of(context);
  //   final user = _chatUsers.firstWhere(
  //     (u) => u.username == contact.userId,
  //     orElse: () => User(
  //       username: contact.userId,
  //       fullName: "Unknown User",
  //       tag: "",
  //       age: 0,
  //       sex: "",
  //       profileImage: "",
  //       achievementsProgress: [],
  //       registeredCourses: [],
  //       registedCoursesIndexes: [],
  //     ),
  //   );

  //   return GestureDetector(
  //     onLongPress: () {
  //       _showChatOptions(contact, user);
  //     },
  //     child: ListTile(
  //       leading: CircleAvatar(
  //         radius: 28,
  //         backgroundImage: user.profileImage.isNotEmpty
  //             ? NetworkImage(user.profileImage)
  //             : null,
  //         backgroundColor: theme.colorScheme.secondary,
  //         child: user.profileImage.isEmpty
  //             ? Icon(Icons.person, color: theme.colorScheme.primary, size: 28)
  //             : null,
  //       ),
  //       title: Text(
  //         user.fullName,
  //         style: GoogleFonts.poppins(
  //           fontSize: 16,
  //           fontWeight: FontWeight.w600,
  //           color: theme.textTheme.bodyLarge!.color,
  //         ),
  //       ),
  //       subtitle: Text(
  //         contact.lastMessage,
  //         maxLines: 1,
  //         overflow: TextOverflow.ellipsis,
  //         style: GoogleFonts.poppins(
  //           fontSize: 14,
  //           color: theme.textTheme.bodyMedium!.color!.withOpacity(0.7),
  //         ),
  //       ),
  //       trailing: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         crossAxisAlignment: CrossAxisAlignment.end,
  //         children: [
  //           Text(
  //             _formatTime(contact.lastMessageTime),
  //             style: GoogleFonts.poppins(
  //               fontSize: 12,
  //               color: theme.textTheme.bodySmall!.color,
  //             ),
  //           ),
  //           const SizedBox(height: 4),
  //           if (contact.unreadCount > 0)
  //             CircleAvatar(
  //               radius: 10,
  //               backgroundColor: theme.colorScheme.primary,
  //               child: Text(
  //                 contact.unreadCount.toString(),
  //                 style: const TextStyle(fontSize: 10, color: Colors.white),
  //               ),
  //             )
  //           else if (user.isOnline)
  //             Container(
  //               width: 10,
  //               height: 10,
  //               decoration: BoxDecoration(
  //                 color: Colors.green,
  //                 borderRadius: BorderRadius.circular(5),
  //               ),
  //             ),
  //         ],
  //       ),
  //       onTap: () {
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(builder: (context) => ChatScreen(chatUser: user)),
  //         );
  //       },
  //     ),
  //   );
  // }

  // Long press menu
  void _showChatOptions(ChatContact contact, User user) {
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
                  _muteChat(contact);
                },
              ),
              ListTile(
                leading: const Icon(Icons.pin),
                title: const Text('Pin chat'),
                onTap: () {
                  Navigator.pop(context);
                  _pinChat(contact);
                },
              ),
              ListTile(
                leading: const Icon(Icons.block),
                title: const Text('Block user'),
                onTap: () {
                  Navigator.pop(context);
                  _blockUser(user);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete chat'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteChat(contact);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _muteChat(ChatContact contact) {
    // Implement mute logic
    print('Muting chat: ${contact.userId}');
  }

  void _pinChat(ChatContact contact) {
    // Implement pin logic
    print('Pinning chat: ${contact.userId}');
  }

  void _blockUser(User user) {
    // Implement block logic
    print('Blocking user: ${user.username}');
  }

  void _deleteChat(ChatContact contact) {
    // Implement delete logic
    print('Deleting chat: ${contact.userId}');
    setState(() {
      _contacts.removeWhere((c) => c.chatId == contact.chatId);
    });
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
          'Chats',
          style: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: BackButton(
          onPressed: () {
            Navigator.pop(context);
          },
          color: theme.colorScheme.onSurface,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.group_add, color: theme.colorScheme.primary),
            onPressed: () {
              // Create new group
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search users by name...',
                      hintStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Theme.of(context).hintColor,
                      ),
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                // Content: search results or chat list
                Expanded(
                  child: _isSearching
                      ? _searchResults.isEmpty
                            ? Center(
                                child: Text(
                                  'No users found',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color
                                        ?.withOpacity(0.6),
                                  ),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                                itemCount: _searchResults.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1,
                                  color: theme.dividerColor.withOpacity(0.18),
                                ),
                                itemBuilder: (context, index) =>
                                    _buildSearchResultItem(
                                      _searchResults[index],
                                    ),
                              )
                      : RefreshIndicator(
                          onRefresh: () => _loadChatContacts(initial: false),
                          child: _contacts.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    const SizedBox(height: 120),
                                    Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.chat_bubble_outline,
                                            size: 64,
                                            color: theme.colorScheme.secondary,
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            'No chats yet',
                                            style: GoogleFonts.poppins(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: theme
                                                  .textTheme
                                                  .bodyLarge!
                                                  .color,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Search for users above to start a conversation',
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: theme
                                                  .textTheme
                                                  .bodyMedium!
                                                  .color!
                                                  .withOpacity(0.7),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.separated(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  itemCount: _contacts.length,
                                  separatorBuilder: (context, index) => Divider(
                                    height: 1,
                                    color: theme.dividerColor.withOpacity(0.18),
                                  ),
                                  itemBuilder: (context, index) =>
                                      _buildChatItem(index),
                                ),
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: () {
          _loadChatContacts(initial: false);
        },
        child: Icon(Icons.message, color: theme.colorScheme.onPrimary),
      ),
    );
  }

  // Widget _buildUserList() {
  //   return StreamBuilder(
  //     stream: _chatService.getUsersStream(),
  //     builder: (context, snapshot) {
  //       if (snapshot.hasError) {
  //         return const Text("Error");
  //       }
  //       if (snapshot.connectionState == ConnectionState.waiting) {
  //         return const Text("Loading");
  //       }
  //       return ListView(
  //         children: snapshot.data!
  //             .map<Widget>((userData) => _buildUserListItem(userData, context))
  //             .toList(),
  //       );
  //     },
  //   );
  // }

  // Widget _buildUserListItem(
  //   Map<String, dynamic> userData,
  //   BuildContext context,
  // ) {
  //   return Container();
  //   // if (userData["email"] == _authService.currentUserEmail) {
  //   //   return Container();
  //   // }
  //   // return UserTile(
  //   //   text: userData["email"],

  //   //   onTap: () {
  //   //     Navigator.push(
  //   //       context,
  //   //       MaterialPageRoute(
  //   //         builder: (ctx) {
  //   //           return ChatScreen(
  //   //             receiverEmail: userData["email"],
  //   //             receiverID: userData['uid'],
  //   //           );
  //   //         },
  //   //       ),
  //   //     );
  //   //   },
  //   // );
  // }
  // // Widget _buildChatItem(ChatContact contact) {
  //   final theme = Theme.of(context);
  //   final user = _chatUsers.firstWhere(
  //     (u) => u.username == contact.userId,
  //     orElse: () => User(
  //       username: contact.userId,
  //       fullName: "Unknown User",
  //       tag: "",
  //       age: 0,
  //       sex: "",
  //       profileImage: "",
  //       achievementsProgress: [],
  //       registeredCourses: [],
  //       registedCoursesIndexes: [],
  //     ),
  //   );

  //   return GestureDetector(
  //     onLongPress: () {
  //       _showChatOptions(contact, user);
  //     },
  //     child: ListTile(
  //       leading: CircleAvatar(
  //         radius: 28,
  //         backgroundImage: user.profileImage.isNotEmpty
  //             ? NetworkImage(user.profileImage)
  //             : null,
  //         backgroundColor: theme.colorScheme.secondary,
  //         child: user.profileImage.isEmpty
  //             ? Icon(Icons.person, color: theme.colorScheme.primary, size: 28)
  //             : null,
  //       ),
  //       title: Text(
  //         user.fullName,
  //         style: GoogleFonts.poppins(
  //           fontSize: 16,
  //           fontWeight: FontWeight.w600,
  //           color: theme.textTheme.bodyLarge!.color,
  //         ),
  //       ),
  //       subtitle: Text(
  //         contact.lastMessage,
  //         maxLines: 1,
  //         overflow: TextOverflow.ellipsis,
  //         style: GoogleFonts.poppins(
  //           fontSize: 14,
  //           color: theme.textTheme.bodyMedium!.color!.withOpacity(0.7),
  //         ),
  //       ),
  //       trailing: Column(
  //         mainAxisAlignment: MainAxisAlignment.center,
  //         crossAxisAlignment: CrossAxisAlignment.end,
  //         children: [
  //           Text(
  //             _formatTime(contact.lastMessageTime),
  //             style: GoogleFonts.poppins(
  //               fontSize: 12,
  //               color: theme.textTheme.bodySmall!.color,
  //             ),
  //           ),
  //           const SizedBox(height: 4),
  //           if (contact.unreadCount > 0)
  //             CircleAvatar(
  //               radius: 10,
  //               backgroundColor: theme.colorScheme.primary,
  //               child: Text(
  //                 contact.unreadCount.toString(),
  //                 style: const TextStyle(fontSize: 10, color: Colors.white),
  //               ),
  //             )
  //           else if (user.isOnline)
  //             Container(
  //               width: 10,
  //               height: 10,
  //               decoration: BoxDecoration(
  //                 color: Colors.green,
  //                 borderRadius: BorderRadius.circular(5),
  //               ),
  //             ),
  //         ],
  //       ),
  //       onTap: () {
  //         Navigator.push(
  //           context,
  //           MaterialPageRoute(builder: (context) => ChatScreen(chatUser: user)),
  //         );
  //       },
  //     ),
  //   );
  // }
}
