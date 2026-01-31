import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:sophia_path/models/chat/chat_message.dart';
import 'package:sophia_path/models/user/user.dart';
import 'package:sophia_path/services/chat/firebase_chat_service.dart';
import 'package:sophia_path/services/profile_state.dart';

class ChatScreen extends StatefulWidget {
  final User? chatUser;
  final String? chatId;
  final String? chatRoomId; // ADD THIS PARAMETER

  const ChatScreen({
    super.key, 
    this.chatUser, 
    this.chatId,
    this.chatRoomId, // ADD THIS
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  List<ChatMessage> _messages = [];
  late User _currentUser;
  bool _isLoading = true;
  bool _isTyping = false;
  Timer? _typingTimer;
  
  late FirebaseChatService _chatService;
  late StreamSubscription<List<ChatMessage>> _messagesSubscription;
  late StreamSubscription<bool> _typingSubscription;
  late String _chatRoomId;

  @override
  void initState() {
    super.initState();
    _chatService = FirebaseChatService();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _loadCurrentUser();
    
    // Use the passed chatRoomId if available, otherwise create one
    if (widget.chatRoomId != null) {
      _chatRoomId = widget.chatRoomId!;
    } else if (widget.chatUser?.firebaseUid != null && _currentUser.firebaseUid != null) {
      _chatRoomId = await _chatService.getOrCreateChatRoom(
        widget.chatUser!.firebaseUid!,
      );
    } else {
      setState(() => _isLoading = false);
      return;
    }
    
    try {
      _messagesSubscription = _chatService
          .getMessagesStream(_chatRoomId)
          .listen((messages) {
        if (mounted) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
        }
      });

      if (widget.chatUser?.firebaseUid != null) {
        _typingSubscription = _chatService
            .getTypingStatusStream(_chatRoomId, widget.chatUser!.firebaseUid!)
            .listen((isTyping) {
          if (mounted) {
            setState(() {
              _isTyping = isTyping;
            });
          }
        });
      }
      
    } catch (e) {
      print('Error initializing chat: $e');
      setState(() => _isLoading = false);
    }
  }

  void _onTextChanged(String text) {
    if (widget.chatUser?.firebaseUid == null) return;
    
    if (!_isTyping) {
      _chatService.updateTypingStatus(_chatRoomId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatService.updateTypingStatus(_chatRoomId, false);
    });
  }

  Future<void> _loadCurrentUser() async {
    final profileState = context.read<ProfileState>();
    final user = profileState.currentUser;

    if (user != null) {
      setState(() => _currentUser = user);
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || widget.chatUser?.firebaseUid == null) return;

    try {
      await _chatService.sendMessage(
        chatRoomId: _chatRoomId,
        message: text,
        receiverId: widget.chatUser!.firebaseUid!,
      );
      
      _messageController.clear();
      _chatService.updateTypingStatus(_chatRoomId, false);
      _typingTimer?.cancel();
    } catch (e) {
      print('Error sending message: $e');
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send message')),
      );}
    }
  }

  void _addReactionToMessage(ChatMessage message, String emoji) async {
  if (_currentUser.firebaseUid == null) return;
  
  try {
    await _chatService.addReaction(
      _chatRoomId,     // ✅ Positional parameter
      message.id,      // ✅ Positional parameter
      emoji,           // ✅ Positional parameter
    );
  } catch (e) {
    print('Error adding reaction: $e');
  }
}

  void _deleteMessage(ChatMessage message) async {
    try {
      await _chatService.deleteMessage(_chatRoomId, message.id);
    } catch (e) {
      print('Error deleting message: $e');
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete message')),
      );}
    }
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

  void _replyToMessage(ChatMessage message) {
    _messageController.text = 'Replying to: ${message.message}';
  }

  void _editMessage(ChatMessage message) {
    _messageController.text = message.message;
  }

  void _reportMessage(ChatMessage message) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Message reported')),
    );
  }

  @override
void dispose() {
  _messagesSubscription.cancel();
  _typingSubscription.cancel();
  _typingTimer?.cancel();
  _chatService.updateTypingStatus(_chatRoomId, false);
  super.dispose();
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
                      'https://cdn.wallpapersafari.com/95/19/uFaSYI.jpg',
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
            onPressed: () => _startVideoCall(),
          ),
          IconButton(
            icon: const Icon(Icons.call, color: Colors.white),
            onPressed: () => _startVoiceCall(),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_isTyping)
            Container(
              padding: const EdgeInsets.all(8),
              child: Text(
                '${widget.chatUser?.fullName ?? 'User'} is typing...',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(
                        child: Text('No messages yet. Start the conversation!'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 16),
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[_messages.length - 1 - index];
                          final isMe = message.senderId == _currentUser.firebaseUid;

                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 4,
                              horizontal: 16,
                            ),
                            child: GestureDetector(
                              onLongPress: () => _showReactions(message),
                              onTap: () => _showMessageOptions(message),
                              child: Row(
                                mainAxisAlignment: isMe
                                    ? MainAxisAlignment.end
                                    : MainAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundImage:
                                          widget.chatUser?.profileImage.isNotEmpty == true
                                              ? NetworkImage(widget.chatUser!.profileImage)
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
                                        color: isMe
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.secondary,
                                        borderRadius: BorderRadius.only(
                                          topLeft: const Radius.circular(20),
                                          topRight: const Radius.circular(20),
                                          bottomLeft: isMe
                                              ? const Radius.circular(20)
                                              : Radius.zero,
                                          bottomRight: isMe
                                              ? Radius.zero
                                              : const Radius.circular(20),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (!isMe)
                                            Text(
                                              message.senderName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: theme.textTheme.bodySmall!.color,
                                              ),
                                            ),
                                          Text(
                                            message.message,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              color: isMe
                                                  ? Colors.white
                                                  : theme.textTheme.bodyMedium!.color,
                                            ),
                                          ),

                                          if (message.reactions.isNotEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(top: 4),
                                              child: Wrap(
                                                spacing: 4,
                                                children: message.reactions.entries
                                                    .map((entry) {
                                                      return Container(
                                                        padding: const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                        decoration: BoxDecoration(
                                                          color: isMe
                                                              ? Colors.blue[100]
                                                              : Colors.green[100],
                                                          borderRadius: BorderRadius.circular(16),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              '${entry.value}',
                                                              style: const TextStyle(fontSize: 14),
                                                            ),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              '1',
                                                              style: TextStyle(
                                                                fontSize: 10,
                                                                color: Colors.grey[700],
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
                                            '${message.timestamp.hour.toString().padLeft(2, "0")}:${message.timestamp.minute.toString().padLeft(2, "0")}',
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
                  onPressed: () => _attachFile(),
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: _onTextChanged,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: GoogleFonts.poppins(
                        color: theme.textTheme.bodyMedium!.color!.withValues(alpha: 0.5),
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

  void _startVideoCall() {
    print('Starting video call');
  }

  void _startVoiceCall() {
    print('Starting voice call');
  }

  void _attachFile() {
    print('Attaching file');
  }
}