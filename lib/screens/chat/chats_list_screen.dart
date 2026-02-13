import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/chat/chat_contact.dart';
import '../../models/user/user.dart'; // Use your existing User model
import 'chat_screen.dart';
import 'user_tile.dart';
import '../../services/auth_service.dart';
import '../../services/chat/firebase_chat_service.dart';


class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final List<ChatContact> _contacts = [];
  final List<User> _chatUsers = []; // Using your User model
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChatContacts();
  }

  Future<void> _loadChatContacts() async {
    // Load contacts and their user data
    await Future.delayed(const Duration(milliseconds: 500));

    // Create sample chat users using your User model
    final sampleChatUsers = [
      User(
          username: "alexj",
          fullName: "Alex Johnson",
          tag: "Physics Student",
          age: 22,
          sex: "Male",
          profileImage: "https://randomuser.me/api/portraits/men/32.jpg",
          achievementsProgress: [],
          registeredCourses: [],
          registedCoursesIndexes: [],
        )
        ..isOnline = true
        ..lastSeen = DateTime.now(),

      User(
          username: "mariag",
          fullName: "Maria Garcia",
          tag: "Philosophy Major",
          age: 21,
          sex: "Female",
          profileImage: "https://randomuser.me/api/portraits/women/44.jpg",
          achievementsProgress: [],
          registeredCourses: [],
          registedCoursesIndexes: [],
        )
        ..isOnline = false
        ..lastSeen = DateTime.now().subtract(const Duration(hours: 2)),

      // Add more sample users...
    ];

    setState(() {
      _chatUsers.addAll(sampleChatUsers);
      _contacts.addAll([
        ChatContact(
          userId: "alexj",
          chatId: "chat1",
          lastMessageTime: DateTime.now().subtract(const Duration(minutes: 15)),
          lastMessage: "Hey, how's the cybersecurity course going?",
          unreadCount: 2,
        ),
        ChatContact(
          userId: "mariag",
          chatId: "chat2",
          lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
          lastMessage: "Can you help me with the ethics assignment?",
          unreadCount: 0,
        ),
      ]);
      _isLoading = false;
    });
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

  void _archiveChat(ChatContact contact) {
    // Implement archive logic
    print('Archiving chat: ${contact.userId}');
    setState(() {
      _contacts.removeWhere((c) => c.chatId == contact.chatId);
    });
  }

  Future<bool> _showDeleteConfirmation(ChatContact contact) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Chat'),
            content: const Text('Are you sure you want to delete this chat?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
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
            onPressed: () {
              // Implement search
            },
          ),
          IconButton(
            icon: const Icon(Icons.group_add, color: Colors.white),
            onPressed: () {
              // Create new group
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildUserList(),

      // : Column(
      //     children: [
      //       Padding(
      //         padding: const EdgeInsets.all(16),
      //         child: TextField(
      //           decoration: InputDecoration(
      //             hintText: 'Search chats...',
      //             hintStyle: GoogleFonts.poppins(),
      //             prefixIcon: const Icon(Icons.search),
      //             border: OutlineInputBorder(
      //               borderRadius: BorderRadius.circular(15),
      //               borderSide: BorderSide.none,
      //             ),
      //             filled: true,
      //             fillColor: theme.colorScheme.secondary,
      //             contentPadding: const EdgeInsets.symmetric(
      //               horizontal: 20,
      //               vertical: 12,
      //             ),
      //           ),
      //         ),
      //       ),
      //       Expanded(
      //         child: // Add pull to refresh
      //         RefreshIndicator(
      //           onRefresh: _loadChatContacts,
      //           child: ListView.separated(
      //             padding: const EdgeInsets.symmetric(horizontal: 16),
      //             itemCount: _contacts.length,
      //             separatorBuilder: (context, index) => Divider(
      //               height: 1,
      //               color: theme.dividerColor.withOpacity(0.3),
      //             ),
      //             itemBuilder: (context, index) {
      //               return Dismissible(
      //                 key: Key(_contacts[index].chatId),
      //                 background: Container(
      //                   color: Colors.red,
      //                   alignment: Alignment.centerLeft,
      //                   padding: const EdgeInsets.only(left: 20),
      //                   child: const Icon(
      //                     Icons.delete,
      //                     color: Colors.white,
      //                   ),
      //                 ),
      //                 secondaryBackground: Container(
      //                   color: Colors.grey,
      //                   alignment: Alignment.centerRight,
      //                   padding: const EdgeInsets.only(right: 20),
      //                   child: const Icon(
      //                     Icons.archive,
      //                     color: Colors.white,
      //                   ),
      //                 ),
      //                 onDismissed: (direction) {
      //                   if (direction == DismissDirection.startToEnd) {
      //                     _deleteChat(_contacts[index]);
      //                   } else {
      //                     _archiveChat(_contacts[index]);
      //                   }
      //                 },
      //                 confirmDismiss: (direction) async {
      //                   if (direction == DismissDirection.startToEnd) {
      //                     return await _showDeleteConfirmation(
      //                       _contacts[index],
      //                     );
      //                   }
      //                   return true;
      //                 },
      //                 child: _buildChatItem(_contacts[index]),
      //               );
      //             },
      //           ),
      //         ),
      //       ),
      //     ],
      //   ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: theme.colorScheme.primary,
        onPressed: () {
          // Start new chat
        },
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  Widget _buildUserList() {
    return StreamBuilder(
      stream: _chatService.getUsersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text("Error");
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Text("Loading");
        }
        return ListView(
          children: snapshot.data!
              .map<Widget>((userData) => _buildUserListItem(userData, context))
              .toList(),
        );
      },
    );
  }

  Widget _buildUserListItem(
    Map<String, dynamic> userData,
    BuildContext context,
  ) {
    if (userData["email"] != _authService.currentUserEmail) {
      return UserTile(
        text: userData["email"],

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) {
                return ChatScreen(
                  receiverEmail: userData["email"],
                  receiverID: userData['uid'],
                );
              },
            ),
          );
        },
      );
    }
    return Container();
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
}
