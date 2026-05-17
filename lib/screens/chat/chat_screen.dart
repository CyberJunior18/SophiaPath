import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/chat/chat_message.dart';
import '../../models/chat/chat_session_user.dart';
import '../../services/chat/chat_service.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? chatRoomId; // ADD THIS PARAMETER
  final String receiverEmail;
  final String receiverID;
  const ChatScreen({
    super.key,
    this.chatId,
    this.chatRoomId,
    required this.receiverEmail,
    required this.receiverID, // ADD THIS
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final List<ChatMessage> _messages = [];

  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  ChatSessionUser? _currentUser;
  bool _isLoading = true;
  bool _isConnected = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bootstrapChat();
  }

  Future<void> _bootstrapChat() async {
    try {
      final currentUser = await _chatService.getCurrentUser();
      final otherUserId = int.tryParse(widget.receiverID);
      if (otherUserId == null) {
        throw Exception('Invalid recipient id');
      }

      if (!mounted) return;
      _chatService.connect(currentUser.userId);

      _messageSubscription = _chatService.incomingMessages.listen((message) {
        if (!mounted) return;

        final isRelevant =
            (message.senderId == currentUser.userId &&
                message.recipientId == otherUserId) ||
            (message.senderId == otherUserId &&
                message.recipientId == currentUser.userId);

        if (!isRelevant) return;

        setState(() {
          final existingIndex = _messages.indexWhere(
            (item) => item.id == message.id,
          );
          if (existingIndex >= 0) {
            _messages[existingIndex] = message;
          } else {
            _messages.add(message);
          }
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        });
      });

      _errorSubscription = _chatService.errors.listen((error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = error;
        });
      });

      _connectionSubscription = _chatService.connectionChanges.listen((
        connected,
      ) {
        if (!mounted) return;
        setState(() {
          _isConnected = connected;
        });
      });

      final history = await _chatService.getConversationHistory(
        currentUser.userId,
        otherUserId,
      );

      if (!mounted) return;
      setState(() {
        _currentUser = currentUser;
        _messages
          ..clear()
          ..addAll(history);
        _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _isLoading = false;
      });

      await _chatService.markConversationAsRead(
        currentUser.userId,
        otherUserId,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _currentUser == null) return;

    final recipientId = int.tryParse(widget.receiverID);
    if (recipientId == null) {
      setState(() {
        _errorMessage = 'Recipient id is invalid';
      });
      return;
    }

    try {
      final outgoingMessage = await _chatService.sendMessage(
        senderId: _currentUser!.userId,
        recipientId: recipientId,
        username: _currentUser!.username,
        message: text,
        avatar: _currentUser!.avatar,
      );

      if (!mounted) return;
      setState(() {
        if (!_chatService.isConnected) {
          _messages.add(outgoingMessage);
          _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        }
        _messageController.clear();
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final localTime = timestamp.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildMessageBubble(ChatMessage message) {
    final currentUserId = _currentUser?.userId;
    final isMe = currentUserId != null && message.senderId == currentUserId;
    final theme = Theme.of(context);
    final otherBubbleColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surface;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? theme.colorScheme.primary : otherBubbleColor,
          border: isMe
              ? null
              : Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.75,
                  ),
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderUsername,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            Text(
              message.message,
              style: GoogleFonts.poppins(
                fontSize: 14,
                height: 1.35,
                color: isMe ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _formatTimestamp(message.timestamp),
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: isMe
                    ? Colors.white.withValues(alpha: 0.75)
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComposer() {
    final borderRadius = BorderRadius.circular(18);
    final theme = Theme.of(context);

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'Write a message...',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: borderRadius,
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: borderRadius,
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: borderRadius,
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: _sendMessage,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.send_rounded,
                  color: theme.colorScheme.onPrimary,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _errorSubscription?.cancel();
    _connectionSubscription?.cancel();
    _chatService.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainer
        : theme.colorScheme.surface;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        titleSpacing: 0,
        leading: BackButton(
          onPressed: () {
            Navigator.pop(context);
          },
          color: theme.colorScheme.onSurface,
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Text(
                widget.receiverEmail.isNotEmpty
                    ? widget.receiverEmail[0].toUpperCase()
                    : '?',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receiverEmail,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  _isConnected ? 'Connected' : 'Connecting...',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _isConnected
                        ? Colors.green
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: const Color(0xFFFFE8E8),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFB42318),
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No messages yet. Send the first one.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          color: const Color(0xFF607086),
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      return _buildMessageBubble(_messages[index]);
                    },
                  ),
          ),
          _buildComposer(),
        ],
      ),
    );
  }
}
  // Widget _buildMessageList() {
  //   String senderID = _authService.currentUserUid!;
  //   return StreamBuilder<QuerySnapshot>(
  //     stream: _chatService.getMessages(senderID, widget.receiverID),
  //     builder: (context, snapshot) {
  //       if (snapshot.hasError) {
  //         print('🔥 Stream error: ${snapshot.error}');
  //         print('🔥 Stack trace: ${snapshot.stackTrace}');
  //         return Center(
  //           child: Text("Error loading messages: ${snapshot.error}"),
  //         );
  //       }

  //       if (snapshot.connectionState == ConnectionState.waiting) {
  //         return const Center(child: CircularProgressIndicator());
  //       }

  //       if (!snapshot.hasData) {
  //         return const Center(child: Text("No data"));
  //       }

  //       try {
  //         // Log the first document to see its structure
  //         if (snapshot.data!.docs.isNotEmpty) {
  //           final firstDoc = snapshot.data!.docs.first;
  //           print('📄 First document type: ${firstDoc.runtimeType}');

  //           // Try to access data in different ways
  //           try {
  //             final data1 = firstDoc.data();
  //             print('📊 data(): $data1');
  //             print('📊 data() type: ${data1.runtimeType}');
  //           } catch (e) {
  //             print('❌ Error getting data(): $e');
  //           }

  //           try {
  //             final data2 = firstDoc.data() as Map<String, dynamic>;
  //             print('✅ Cast successful: $data2');
  //           } catch (e) {
  //             print('❌ Cast failed: $e');
  //           }
  //         }

  //         return ListView(
  //           reverse: true,
  //           children: snapshot.data!.docs.map((doc) {
  //             try {
  //               // Try to get and cast the data
  //               final data = doc.data();
  //               print('📨 Message data type: ${data.runtimeType}');

  //               if (data is Map<String, dynamic>) {
  //                 return _buildMessageItemFromData(data);
  //               } else {
  //                 print(
  //                   '❌ Data is not Map<String, dynamic>: ${data.runtimeType}',
  //                 );
  //                 return const SizedBox.shrink();
  //               }
  //             } catch (e, stack) {
  //               print('❌ Error processing message: $e');
  //               print('📚 Stack: $stack');
  //               return const SizedBox.shrink();
  //             }
  //           }).toList(),
  //         );
  //       } catch (e, stack) {
  //         print('❌ Fatal error in ListView building: $e');
  //         print('📚 Stack: $stack');
  //         return Center(child: Text('Error: $e'));
  //       }
  //     },
  //   );
  // }

  // Use this version that works with any Map type
  // Widget _buildMessageItemFromData(Map<String, dynamic> data) {
  //   try {
  //     final senderId = data['senderID']?.toString() ?? '';
  //     final isMe = senderId == _authService.currentUserUid;

  //     return Padding(
  //       padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
  //       child: Row(
  //         mainAxisAlignment: isMe
  //             ? MainAxisAlignment.end
  //             : MainAxisAlignment.start,
  //         children: [
  //           if (!isMe)
  //             ProfileImage(
  //               imageUrl:
  //                   "https://ui-avatars.com/api/?name=User&background=3D5CFF&color=fff&size=256",
  //               radius: 16,
  //             ),
  //           const SizedBox(width: 8),
  //           Flexible(
  //             child: Container(
  //               padding: const EdgeInsets.symmetric(
  //                 horizontal: 16,
  //                 vertical: 12,
  //               ),
  //               decoration: BoxDecoration(
  //                 color: isMe
  //                     ? Colors.blue
  //                     : const Color.fromARGB(255, 13, 80, 47),
  //                 borderRadius: BorderRadius.only(
  //                   topLeft: const Radius.circular(20),
  //                   topRight: const Radius.circular(20),
  //                   bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
  //                   bottomRight: isMe ? Radius.zero : const Radius.circular(20),
  //                 ),
  //               ),
  //               child: Column(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   if (!isMe)
  //                     Text(
  //                       data['senderName']?.toString() ?? 'Unknown User',
  //                       style: GoogleFonts.poppins(
  //                         fontSize: 12,
  //                         fontWeight: FontWeight.bold,
  //                         color: Colors.white,
  //                       ),
  //                     ),
  //                   Text(
  //                     data["message"]?.toString() ?? '',
  //                     style: GoogleFonts.poppins(
  //                       fontSize: 14,
  //                       color: Colors.white,
  //                     ),
  //                   ),
  //                   const SizedBox(height: 4),
  //                   Text(
  //                     data["timestamp"] != null
  //                         ? _formatTimestamp(data["timestamp"])
  //                         : '',
  //                     style: GoogleFonts.poppins(
  //                       fontSize: 10,
  //                       color: Colors.white70,
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     );
  //   } catch (e) {
  //     print('❌ Error building message item: $e');
  //     return const SizedBox.shrink();
  //   }
  // }

  // String _formatTimestamp(Timestamp timestamp) {
  //   final dateTime = timestamp.toDate();
  //   return '${dateTime.hour.toString().padLeft(2, "0")}:${dateTime.minute.toString().padLeft(2, "0")}';
  // }

  // Widget _buildMessageItem(DocumentSnapshot doc) {
  //   // ✅ Safely cast the data
  //   final data = doc.data() as Map<String, dynamic>;

  //   // Check if senderID exists
  //   final senderId = data['senderID'] ?? '';
  //   final isMe = senderId == _authService.currentUserUid;

  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
  //     child: Row(
  //       mainAxisAlignment: isMe
  //           ? MainAxisAlignment.end
  //           : MainAxisAlignment.start,
  //       children: [
  //         if (!isMe)
  //           ProfileImage(
  //             imageUrl:
  //                 "https://ui-avatars.com/api/?name=User&background=3D5CFF&color=fff&size=256",
  //             radius: 16,
  //           ),
  //         const SizedBox(width: 8),
  //         Flexible(
  //           child: Container(
  //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  //             decoration: BoxDecoration(
  //               color: isMe
  //                   ? Colors.blue
  //                   : const Color.fromARGB(255, 13, 80, 47),
  //               borderRadius: BorderRadius.only(
  //                 topLeft: const Radius.circular(20),
  //                 topRight: const Radius.circular(20),
  //                 bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
  //                 bottomRight: isMe ? Radius.zero : const Radius.circular(20),
  //               ),
  //             ),
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 if (!isMe)
  //                   Text(
  //                     data['senderName'] ?? 'Unknown User',
  //                     style: GoogleFonts.poppins(
  //                       fontSize: 12,
  //                       fontWeight: FontWeight.bold,
  //                       color: Colors.white,
  //                     ),
  //                   ),
  //                 Text(
  //                   data["message"] ?? '',
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 14,
  //                     color: Colors.white,
  //                   ),
  //                 ),
  //                 const SizedBox(height: 4),
  //                 Text(
  //                   data["timestamp"] != null
  //                       ? _formatTimestamp(data["timestamp"])
  //                       : '',
  //                   style: GoogleFonts.poppins(
  //                     fontSize: 10,
  //                     color: Colors.white70,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

//   // Widget _buildUserInput() {
//     return Row(
//       children: [
//         Expanded(
//           child: TextField(
//             decoration: InputDecoration(
//               hintText: "Type a message",
//               border: OutlineInputBorder(),
//             ),
//             controller: _messageController,
//             obscureText: false,
//           ),
//         ),
//         IconButton(onPressed: _sendMessage, icon: Icon(Icons.arrow_upward)),
//       ],
//     );
//   }
// // }






// this is old af, idk if worth checking :)
// class _ChatScreenState extends State<ChatScreen> {
//   final TextEditingController _messageController = TextEditingController();
//   List<ChatMessage> _messages = [];
//   late User _currentUser;
//   bool _isLoading = true;
//   bool _isTyping = false;
//   Timer? _typingTimer;

//   late FirebaseChatService _chatService;
//   late StreamSubscription<List<ChatMessage>> _messagesSubscription;
//   late StreamSubscription<bool> _typingSubscription;
//   late String _chatRoomId;

//   @override
//   void initState() {
//     super.initState();
//     _chatService = FirebaseChatService();
//     _initializeChat();
//   }

//   Future<void> _initializeChat() async {
//     await _loadCurrentUser();

//     // Use the passed chatRoomId if available, otherwise create one
//     if (widget.chatRoomId != null) {
//       _chatRoomId = widget.chatRoomId!;
//     } else if (widget.chatUser?.firebaseUid != null &&
//         _currentUser.firebaseUid != null) {
//       _chatRoomId = await _chatService.getOrCreateChatRoom(
//         widget.chatUser!.firebaseUid!,
//       );
//     } else {
//       setState(() => _isLoading = false);
//       return;
//     }

//     try {
//       _messagesSubscription = _chatService
//           .getMessagesStream(_chatRoomId)
//           .listen((messages) {
//             if (mounted) {
//               setState(() {
//                 _messages = messages;
//                 _isLoading = false;
//               });
//             }
//           });

//       if (widget.chatUser?.firebaseUid != null) {
//         _typingSubscription = _chatService
//             .getTypingStatusStream(_chatRoomId, widget.chatUser!.firebaseUid!)
//             .listen((isTyping) {
//               if (mounted) {
//                 setState(() {
//                   _isTyping = isTyping;
//                 });
//               }
//             });
//       }
//     } catch (e) {
//       print('Error initializing chat: $e');
//       setState(() => _isLoading = false);
//     }
//   }

//   void _onTextChanged(String text) {
//     if (widget.chatUser?.firebaseUid == null) return;

//     if (!_isTyping) {
//       _chatService.updateTypingStatus(_chatRoomId, true);
//     }

//     _typingTimer?.cancel();
//     _typingTimer = Timer(const Duration(seconds: 2), () {
//       _chatService.updateTypingStatus(_chatRoomId, false);
//     });
//   }

//   Future<void> _loadCurrentUser() async {
//     final profileState = context.read<ProfileState>();
//     final user = profileState.currentUser;

//     if (user != null) {
//       setState(() => _currentUser = user);
//     }
//   }

//   void _sendMessage() async {
//     final text = _messageController.text.trim();
//     if (text.isEmpty || widget.chatUser?.firebaseUid == null) return;

//     try {
//       await _chatService.sendMessage(
//         chatRoomId: _chatRoomId,
//         message: text,
//         receiverId: widget.chatUser!.firebaseUid!,
//       );

//       _messageController.clear();
//       _chatService.updateTypingStatus(_chatRoomId, false);
//       _typingTimer?.cancel();
//     } catch (e) {
//       print('Error sending message: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(const SnackBar(content: Text('Failed to send message')));
//       }
//     }
//   }

//   void _addReactionToMessage(ChatMessage message, String emoji) async {
//     if (_currentUser.firebaseUid == null) return;

//     try {
//       await _chatService.addReaction(
//         _chatRoomId, // ✅ Positional parameter
//         message.id, // ✅ Positional parameter
//         emoji, // ✅ Positional parameter
//       );
//     } catch (e) {
//       print('Error adding reaction: $e');
//     }
//   }

//   void _deleteMessage(ChatMessage message) async {
//     try {
//       await _chatService.deleteMessage(_chatRoomId, message.id);
//     } catch (e) {
//       print('Error deleting message: $e');
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Failed to delete message')),
//         );
//       }
//     }
//   }

//   void _showReactions(ChatMessage message) {
//     final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🎉', '🔥'];

//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return Container(
//           padding: const EdgeInsets.all(16),
//           child: Wrap(
//             spacing: 16,
//             runSpacing: 16,
//             alignment: WrapAlignment.center,
//             children: emojis.map((emoji) {
//               return GestureDetector(
//                 onTap: () {
//                   Navigator.pop(context);
//                   _addReactionToMessage(message, emoji);
//                 },
//                 child: Container(
//                   padding: const EdgeInsets.all(12),
//                   decoration: BoxDecoration(
//                     borderRadius: BorderRadius.circular(50),
//                     color: Colors.grey[200],
//                   ),
//                   child: Text(emoji, style: const TextStyle(fontSize: 28)),
//                 ),
//               );
//             }).toList(),
//           ),
//         );
//       },
//     );
//   }

//   void _showMessageOptions(ChatMessage message) {
//     showModalBottomSheet(
//       context: context,
//       builder: (context) {
//         return SafeArea(
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               ListTile(
//                 leading: const Icon(Icons.reply),
//                 title: const Text('Reply'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _replyToMessage(message);
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.edit),
//                 title: const Text('Edit'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _editMessage(message);
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.delete),
//                 title: const Text('Delete'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _deleteMessage(message);
//                 },
//               ),
//               ListTile(
//                 leading: const Icon(Icons.flag),
//                 title: const Text('Report'),
//                 onTap: () {
//                   Navigator.pop(context);
//                   _reportMessage(message);
//                 },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }

//   void _replyToMessage(ChatMessage message) {
//     _messageController.text = 'Replying to: ${message.message}';
//   }

//   void _editMessage(ChatMessage message) {
//     _messageController.text = message.message;
//   }

//   void _reportMessage(ChatMessage message) {
//     ScaffoldMessenger.of(
//       context,
//     ).showSnackBar(const SnackBar(content: Text('Message reported')));
//   }

//   @override
//   void dispose() {
//     _messagesSubscription.cancel();
//     _typingSubscription.cancel();
//     _typingTimer?.cancel();
//     _chatService.updateTypingStatus(_chatRoomId, false);
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);

//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: theme.colorScheme.primary,
//         elevation: 0,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back, color: Colors.white),
//           onPressed: () => Navigator.pop(context),
//         ),
//         title: Row(
//           children: [
//             CircleAvatar(
//               radius: 18,
//               backgroundImage: widget.chatUser?.profileImage.isNotEmpty == true
//                   ? NetworkImage(widget.chatUser!.profileImage)
//                   : const NetworkImage(
//                       'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg',
//                     ),
//             ),
//             const SizedBox(width: 12),
//             Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   widget.chatUser?.fullName ?? 'Study Partner',
//                   style: GoogleFonts.poppins(
//                     fontSize: 16,
//                     fontWeight: FontWeight.bold,
//                     color: Colors.white,
//                   ),
//                 ),
//                 Text(
//                   widget.chatUser?.isOnline == true ? 'Online' : 'Offline',
//                   style: GoogleFonts.poppins(
//                     fontSize: 12,
//                     color: Colors.white70,
//                   ),
//                 ),
//               ],
//             ),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.videocam, color: Colors.white),
//             onPressed: () => _startVideoCall(),
//           ),
//           IconButton(
//             icon: const Icon(Icons.call, color: Colors.white),
//             onPressed: () => _startVoiceCall(),
//           ),
//         ],
//       ),
//       body: Column(
//         children: [
//           if (_isTyping)
//             Container(
//               padding: const EdgeInsets.all(8),
//               child: Text(
//                 '${widget.chatUser?.fullName ?? 'User'} is typing...',
//                 style: GoogleFonts.poppins(
//                   fontSize: 12,
//                   color: Colors.grey,
//                   fontStyle: FontStyle.italic,
//                 ),
//               ),
//             ),

//           Expanded(
//             child: _isLoading
//                 ? const Center(child: CircularProgressIndicator())
//                 : _messages.isEmpty
//                 ? const Center(
//                     child: Text('No messages yet. Start the conversation!'),
//                   )
//                 : ListView.builder(
//                     padding: const EdgeInsets.only(top: 16),
//                     reverse: true,
//                     itemCount: _messages.length,
//                     itemBuilder: (context, index) {
//                       final message = _messages[_messages.length - 1 - index];
//                       final isMe = message.senderId == _currentUser.firebaseUid;

//                       return
// Padding(
//                         padding: const EdgeInsets.symmetric(
//                           vertical: 4,
//                           horizontal: 16,
//                         ),
//                         child: GestureDetector(
//                           onLongPress: () => _showReactions(message),
//                           onTap: () => _showMessageOptions(message),
//                           child: Row(
//                             mainAxisAlignment: isMe
//                                 ? MainAxisAlignment.end
//                                 : MainAxisAlignment.start,
//                             children: [
//                               if (!isMe)
//                                 CircleAvatar(
//                                   radius: 16,
//                                   backgroundImage:
//                                       widget
//                                               .chatUser
//                                               ?.profileImage
//                                               .isNotEmpty ==
//                                           true
//                                       ? NetworkImage(
//                                           widget.chatUser!.profileImage,
//                                         )
//                                       : const NetworkImage(
//                                           'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg',
//                                         ),
//                                 ),
//                               const SizedBox(width: 8),
//                               Flexible(
//                                 child: Container(
//                                   padding: const EdgeInsets.symmetric(
//                                     horizontal: 16,
//                                     vertical: 12,
//                                   ),
//                                   decoration: BoxDecoration(
//                                     color: isMe
//                                         ? theme.colorScheme.primary
//                                         : theme.colorScheme.secondary,
//                                     borderRadius: BorderRadius.only(
//                                       topLeft: const Radius.circular(20),
//                                       topRight: const Radius.circular(20),
//                                       bottomLeft: isMe
//                                           ? const Radius.circular(20)
//                                           : Radius.zero,
//                                       bottomRight: isMe
//                                           ? Radius.zero
//                                           : const Radius.circular(20),
//                                     ),
//                                   ),
//                                   child: Column(
//                                     crossAxisAlignment:
//                                         CrossAxisAlignment.start,
//                                     children: [
//                                       if (!isMe)
//                                         Text(
//                                           message.senderName,
//                                           style: GoogleFonts.poppins(
//                                             fontSize: 12,
//                                             fontWeight: FontWeight.bold,
//                                             color: theme
//                                                 .textTheme
//                                                 .bodySmall!
//                                                 .color,
//                                           ),
//                                         ),
//                                       Text(
//                                         message.message,
//                                         style: GoogleFonts.poppins(
//                                           fontSize: 14,
//                                           color: isMe
//                                               ? Colors.white
//                                               : theme
//                                                     .textTheme
//                                                     .bodyMedium!
//                                                     .color,
//                                         ),
//                                       ),

//                                       if (message.reactions.isNotEmpty)
//                                         Container(
//                                           margin: const EdgeInsets.only(top: 4),
//                                           child: Wrap(
//                                             spacing: 4,
//                                             children: message.reactions.entries
//                                                 .map((entry) {
//                                                   return Container(
//                                                     padding:
//                                                         const EdgeInsets.symmetric(
//                                                           horizontal: 8,
//                                                           vertical: 4,
//                                                         ),
//                                                     decoration: BoxDecoration(
//                                                       color: isMe
//                                                           ? Colors.blue[100]
//                                                           : Colors.green[100],
//                                                       borderRadius:
//                                                           BorderRadius.circular(
//                                                             16,
//                                                           ),
//                                                     ),
//                                                     child: Row(
//                                                       mainAxisSize:
//                                                           MainAxisSize.min,
//                                                       children: [
//                                                         Text(
//                                                           '${entry.value}',
//                                                           style:
//                                                               const TextStyle(
//                                                                 fontSize: 14,
//                                                               ),
//                                                         ),
//                                                         const SizedBox(
//                                                           width: 4,
//                                                         ),
//                                                         Text(
//                                                           '1',
//                                                           style: TextStyle(
//                                                             fontSize: 10,
//                                                             color: Colors
//                                                                 .grey[700],
//                                                           ),
//                                                         ),
//                                                       ],
//                                                     ),
//                                                   );
//                                                 })
//                                                 .toList(),
//                                           ),
//                                         ),

//                                       const SizedBox(height: 4),
//                                       Text(
//                                         '${message.timestamp.hour.toString().padLeft(2, "0")}:${message.timestamp.minute.toString().padLeft(2, "0")}',
//                                         style: GoogleFonts.poppins(
//                                           fontSize: 10,
//                                           color: isMe
//                                               ? Colors.white70
//                                               : Colors.grey[600],
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       );
//                     },
//                   ),
//           ),

//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
//             decoration: BoxDecoration(
//               color: theme.colorScheme.surface,
//               border: Border(top: BorderSide(color: theme.dividerColor)),
//             ),
//             child: Row(
//               children: [
//                 IconButton(
//                   icon: Icon(Icons.add, color: theme.colorScheme.primary),
//                   onPressed: () => _attachFile(),
//                 ),
//                 Expanded(
//                   child: TextField(
//                     controller: _messageController,
//                     onChanged: _onTextChanged,
//                     decoration: InputDecoration(
//                       hintText: 'Type a message...',
//                       hintStyle: GoogleFonts.poppins(
//                         color: theme.textTheme.bodyMedium!.color!.withValues(
//                           alpha: 0.5,
//                         ),
//                       ),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(25),
//                         borderSide: BorderSide.none,
//                       ),
//                       filled: true,
//                       fillColor: theme.colorScheme.secondary,
//                       contentPadding: const EdgeInsets.symmetric(
//                         horizontal: 20,
//                         vertical: 12,
//                       ),
//                     ),
//                     onSubmitted: (_) => _sendMessage(),
//                   ),
//                 ),
//                 IconButton(
//                   icon: Icon(Icons.send, color: theme.colorScheme.primary),
//                   onPressed: _sendMessage,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   void _startVideoCall() {
//     print('Starting video call');
//   }

//   void _startVoiceCall() {
//     print('Starting voice call');
//   }

//   void _attachFile() {
//     print('Attaching file');
//   }
// }
