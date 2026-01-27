import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sophia_path/models/chat/chat_message.dart';
import 'package:sophia_path/models/user/user.dart';
import 'package:provider/provider.dart';
import 'package:sophia_path/services/chat/chat_service.dart';
import 'package:sophia_path/services/profile_state.dart';

class ChatScreen extends StatefulWidget {
  final User? chatUser;
  final String? chatId;

  const ChatScreen({super.key, this.chatUser, this.chatId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController =
      TextEditingController(); // input of message controller
  List<ChatMessage> _messages =
      []; // list of ChatMessages that will be presented
  late User _currentUser;
  bool _isLoading = true;
  bool _isTyping = false;
  Timer? _typingTimer;

  void _onTextChanged(String text) {
    // Debounce typing indicator: restart timer on each keystroke to avoid multiple sends
    if (!_isTyping) {
      _isTyping = true;
      // Send typing indicator to server
      _sendTypingIndicator(true);
    }

    // Cancel previous timer and start new one (2 second debounce)
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      setState(() {
        _isTyping = false;
      });
      // Send typing stopped indicator
      _sendTypingIndicator(false);
    });
  }

  void _sendTypingIndicator(bool isTyping) {}

  // Add message reactions
  void _showMessageOptions(ChatMessage message) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(context);
                  _replyToMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  _editMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  _deleteMessage(message);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag),
                title: const Text('Report'),
                onTap: () {
                  Navigator.pop(context);
                  _reportMessage(message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadMessages();
  }

  Future<void> _loadCurrentUser() async {
    final profileState = context.read<ProfileState>();
    final user = profileState.currentUser;

    if (user != null) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _loadMessages() async {
    await Future.delayed(const Duration(milliseconds: 500));

    // demo data - replace with actual API call
    setState(() {
      _messages.addAll([
        ChatMessage(
          id: '1',
          senderId: widget.chatUser?.username ?? 'other',
          senderName: widget.chatUser?.fullName ?? 'Study Partner',
          message: 'Hello! How are your studies going?',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: true,
        ),
        ChatMessage(
          id: '2',
          senderId: _currentUser.username,
          senderName: 'You',
          message: 'Going well! Just finished the Philosophy lesson.',
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          isRead: true,
        ),
      ]);
      _isLoading = false;
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    // Don't send empty messages
    if (text.isEmpty) return;

    // Generate unique ID using current timestamp in milliseconds
    final newMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      senderId: _currentUser.username,
      senderName: 'You',
      message: text,
      timestamp: DateTime.now(),
      isRead: true,
    );

    setState(() {
      _messages.add(newMessage);
    });

    _messageController.clear();
  }

  void _replyToMessage(ChatMessage message) {
    // TODO: Implement reply functionality
    print('Replying to message: ${message.id}');
    _messageController.text = 'Replying to: ${message.message}';
  }

  void _editMessage(ChatMessage message) {
    // TODO: Implement edit functionality
    print('Editing message: ${message.id}');
    _messageController.text = message.message;
  }

  void _deleteMessage(ChatMessage message) {
    // TODO: Implement delete functionality
    print('Deleting message: ${message.id}');
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });
  }

  void _reportMessage(ChatMessage message) {
    // TODO: Implement report functionality
    print('Reporting message: ${message.id}');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Message reported')));
  }

  void _showReactions(ChatMessage message) {
    final emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🎉', '🔥'];

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: emojis.map((emoji) {
              return GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _addReactionToMessage(message, emoji);
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: Colors.grey[200],
                  ),
                  child: Text(emoji, style: const TextStyle(fontSize: 28)),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _addReactionToMessage(ChatMessage message, String emoji) {
    setState(() {
      // Immutable pattern: create new list instead of modifying existing
      // This ensures Flutter detects the state change and rebuilds
      _messages = _messages.map((m) {
        if (m.id == message.id) {
          // Copy reactions map and add emoji from current user
          // User can update reaction by tapping again with different emoji
          final updatedReactions = Map<String, String>.from(m.reactions);
          updatedReactions[_currentUser.username] = emoji;
          return m.copyWith(reactions: updatedReactions);
        }
        return m;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundImage: widget.chatUser?.profileImage.isNotEmpty == true
                  ? NetworkImage(widget.chatUser!.profileImage)
                  : const NetworkImage(
                      'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg', //default image incase of error
                    ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.chatUser?.fullName ?? 'Study Partner',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  widget.chatUser?.isOnline == true ? 'Online' : 'Offline',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam, color: Colors.white),
            onPressed: () {
              // Implement video call
            },
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () {
              // Implement voice call
            },
          ),
        ],
      ),
      body: Column(
        children: [
          StreamBuilder<String?>(
            stream: Stream.periodic(const Duration(milliseconds: 500)).asyncMap(
              (_) async {
                if (widget.chatId != null) {
                  return await ChatService().getTypingStatus(widget.chatId!);
                }
                return null;
              },
            ),
            builder: (context, snapshot) {
              if (snapshot.hasData &&
                  snapshot.data != null &&
                  snapshot.data!.isNotEmpty &&
                  snapshot.data != _currentUser.username) {
                return Container(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    '${widget.chatUser?.fullName ?? 'User'} is typing...',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 16),
                    reverse: true, // Show newest messages at bottom
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      // Access message in reverse order (newest first in UI)
                      final message = _messages[_messages.length - 1 - index];
                      final isMe = message.senderId == _currentUser.username;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 4,
                          horizontal: 16,
                        ),
                        child: GestureDetector(
                          // Long press to react with emoji
                          onLongPress: () => _showReactions(message),
                          child: Row(
                            // Align sent messages right, received to left
                            mainAxisAlignment: isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                            children: [
                              // Only show avatar for received messages (not ours)
                              if (!isMe)
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage:
                                      widget
                                              .chatUser
                                              ?.profileImage
                                              .isNotEmpty ==
                                          true
                                      ? NetworkImage(
                                          widget.chatUser!.profileImage,
                                        )
                                      : const NetworkImage(
                                          'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg',
                                        ),
                                ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    // Different colors: sent (primary) vs received (secondary)
                                    color: isMe
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.secondary,
                                    // Sharp corner on the side message comes from
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(20),
                                      topRight: const Radius.circular(20),
                                      // Sent: sharp bottom-left, Received: sharp bottom-right
                                      bottomLeft: isMe
                                          ? const Radius.circular(20)
                                          : Radius.zero,
                                      bottomRight: isMe
                                          ? Radius.zero
                                          : const Radius.circular(20),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Show sender name only for received messages
                                      if (!isMe)
                                        Text(
                                          message.senderName,
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme
                                                .textTheme
                                                .bodySmall!
                                                .color,
                                          ),
                                        ),
                                      Text(
                                        message.message,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: isMe
                                              ? Colors.white
                                              : theme
                                                    .textTheme
                                                    .bodyMedium!
                                                    .color,
                                        ),
                                      ),

                                      // Display emoji reactions if any exist
                                      if (message.reactions.isNotEmpty)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          child: Wrap(
                                            spacing: 4,
                                            // Map each reaction entry to a visual pill
                                            children: message.reactions.entries
                                                .map((entry) {
                                                  return Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isMe
                                                          ? Colors.blue[100]
                                                          : Colors.green[100],
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          '${entry.value}',
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 14,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          '1',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            color: Colors
                                                                .grey[700],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                          ),
                                        ),

                                      const SizedBox(height: 4),
                                      Text(
                                        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          color: isMe
                                              ? Colors.white70
                                              : Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(top: BorderSide(color: theme.dividerColor)),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(Icons.add, color: theme.colorScheme.primary),
                  onPressed: () {
                    // Add attachment
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.poppins(
                        color: theme.textTheme.bodyMedium!.color!.withOpacity(
                          0.5,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colorScheme.secondary,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send, color: theme.colorScheme.primary),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
