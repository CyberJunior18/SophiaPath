import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/chat/chat_message.dart';
import '../../models/chat/chat_session_user.dart';
import '../../services/chat/chat_service.dart';
import '../../services/local_social_storage.dart';
import '../../widgets/social/dm_message_action_menu.dart';

class ChatScreen extends StatefulWidget {
  final String? chatId;
  final String? chatRoomId;
  final String receiverEmail;
  final String receiverID;
  const ChatScreen({
    super.key,
    this.chatId,
    this.chatRoomId,
    required this.receiverEmail,
    required this.receiverID,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final LocalSocialStorage _localStorage = LocalSocialStorage.instance;
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];

  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  ChatSessionUser? _currentUser;
  bool _isLoading = true;
  bool _isConnected = false;
  String? _errorMessage;

  // Typing indicator state
  bool _otherUserTyping = false;
  Timer? _typingPollTimer;
  Timer? _typingDebounceTimer;
  bool _iAmTyping = false;

  // Reply state
  ChatMessage? _replyingTo;

  // Edit state
  ChatMessage? _editingMessage;

  String get _draftKey => 'dm_${widget.receiverID}';

  @override
  void initState() {
    super.initState();
    _bootstrapChat();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final draft = await _localStorage.getDraft(_draftKey);
    if (draft != null && draft.isNotEmpty && mounted) {
      _messageController.text = draft;
    }
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
        _scrollToBottom();
      });

      _errorSubscription = _chatService.errors.listen((error) {
        if (!mounted) return;
        setState(() {
          _errorMessage = error;
        });
      });

      _connectionSubscription = _chatService.connectionChanges.listen(
        (connected) {
          if (!mounted) return;
          setState(() {
            _isConnected = connected;
          });
        },
      );

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

      // Start polling for typing status
      _typingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _pollTypingStatus();
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = error.toString();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _pollTypingStatus() async {
    if (_currentUser == null) return;
    final otherUserId = int.tryParse(widget.receiverID);
    if (otherUserId == null) return;

    final isTyping = await _chatService.getTypingStatus(
      otherUserId,
      _currentUser!.userId,
    );
    if (mounted && _otherUserTyping != isTyping) {
      setState(() {
        _otherUserTyping = isTyping;
      });
    }
  }

  void _onTextChanged(String text) {
    // Save draft
    _localStorage.saveDraft(_draftKey, text);

    // Send typing indicator
    if (_currentUser == null) return;
    final otherUserId = int.tryParse(widget.receiverID);
    if (otherUserId == null) return;

    if (!_iAmTyping) {
      _iAmTyping = true;
      _chatService.updateTypingStatus(
        _currentUser!.userId,
        otherUserId,
        _currentUser!.username,
        true,
      );
    }

    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(seconds: 2), () {
      _iAmTyping = false;
      _chatService.updateTypingStatus(
        _currentUser!.userId,
        otherUserId,
        _currentUser!.username,
        false,
      );
    });
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

    // If editing, call editMessage API instead
    if (_editingMessage != null) {
      final updated = await _chatService.editMessage(
        _editingMessage!.id,
        text,
        _currentUser!.userId,
      );
      if (updated != null && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == _editingMessage!.id);
          if (idx >= 0) {
            _messages[idx] = updated;
          }
          _editingMessage = null;
          _messageController.clear();
          _errorMessage = null;
        });
      }
      _localStorage.clearDraft(_draftKey);
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
        _replyingTo = null;
        _errorMessage = null;
      });
      _localStorage.clearDraft(_draftKey);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    }
  }

  void _showMessageActionMenu(ChatMessage message) {
    final currentUserId = _currentUser?.userId;
    final isMe = currentUserId != null && message.senderId == currentUserId;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DmMessageActionMenu(
        message: message,
        isMyMessage: isMe,
        onReply: () {
          setState(() => _replyingTo = message);
        },
        onForward: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Forward will be available soon')),
          );
        },
        onPin: () async {
          final success = await _chatService.pinMessage(
            message.id,
            !message.pinned,
          );
          if (success && mounted) {
            setState(() {
              final idx = _messages.indexWhere((m) => m.id == message.id);
              if (idx >= 0) {
                _messages[idx] = _messages[idx].copyWith(
                  pinned: !message.pinned,
                );
              }
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    message.pinned ? 'Message unpinned' : 'Message pinned',
                  ),
                ),
              );
            }
          }
        },
        onStar: () async {
          await _localStorage.toggleStarMessage(
            'dm_${widget.receiverID}',
            message.id,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Message starred')),
            );
          }
        },
        onCopy: () {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Copied to clipboard')),
            );
          }
        },
        onEdit: isMe
            ? () {
                setState(() {
                  _editingMessage = message;
                  _messageController.text = message.message;
                });
              }
            : null,
        onDelete: isMe
            ? () async {
                final success = await _chatService.deleteDirectMessage(
                  message.id,
                  _currentUser!.userId,
                );
                if (success && mounted) {
                  setState(() {
                    final idx = _messages.indexWhere(
                      (m) => m.id == message.id,
                    );
                    if (idx >= 0) {
                      _messages[idx] = _messages[idx].copyWith(
                        message: 'This message was deleted',
                        deleted: true,
                      );
                    }
                  });
                }
              }
            : null,
      ),
    );
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

    return GestureDetector(
      onLongPress: () => _showMessageActionMenu(message),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment:
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Pinned indicator
              if (message.pinned)
                Padding(
                  padding:
                      const EdgeInsets.only(bottom: 4, left: 8, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.push_pin,
                          size: 12, color: theme.colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Pinned',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isMe ? theme.colorScheme.primary : otherBubbleColor,
                  border: isMe
                      ? null
                      : Border.all(
                          color: theme.colorScheme.outlineVariant
                              .withValues(alpha: 0.75),
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
                    // Reply preview
                    if (message.replyToMessage != null &&
                        message.replyToMessage!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(
                            left: BorderSide(
                              color: isMe
                                  ? Colors.white
                                  : theme.colorScheme.primary,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.replyToUsername != null)
                              Text(
                                message.replyToUsername!,
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isMe
                                      ? Colors.white70
                                      : theme.colorScheme.primary,
                                ),
                              ),
                            Text(
                              message.replyToMessage!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: isMe ? Colors.white60 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Text(
                      message.deleted
                          ? 'This message was deleted'
                          : message.message,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        height: 1.35,
                        color:
                            isMe ? Colors.white : theme.colorScheme.onSurface,
                        fontStyle: message.deleted
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (message.edited)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Text(
                              'edited',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: isMe
                                    ? Colors.white.withValues(alpha: 0.6)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (message.forwarded)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.forward,
                              size: 10,
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.6)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyBar() {
    if (_replyingTo == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest,
      child: Row(
        children: [
          Icon(Icons.reply, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replying to ${_replyingTo!.senderUsername}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Text(
                  _replyingTo!.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => setState(() => _replyingTo = null),
          ),
        ],
      ),
    );
  }

  Widget _buildEditBar() {
    if (_editingMessage == null) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        children: [
          Icon(Icons.edit, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Editing message',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _editingMessage = null;
                _messageController.clear();
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (!_otherUserTyping) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(3, (i) {
                return TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Duration(milliseconds: 600 + i * 200),
                  builder: (context, value, child) {
                    return Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.4 + value * 0.6),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${widget.receiverEmail} is typing...',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
                onChanged: _onTextChanged,
                decoration: InputDecoration(
                  hintText: _editingMessage != null
                      ? 'Edit message...'
                      : 'Write a message...',
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
                  _editingMessage != null
                      ? Icons.check_rounded
                      : Icons.send_rounded,
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
    _typingPollTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _chatService.dispose();
    _messageController.dispose();
    _scrollController.dispose();
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
                  _otherUserTyping
                      ? 'Typing...'
                      : _isConnected
                          ? 'Connected'
                          : 'Connecting...',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: _otherUserTyping
                        ? theme.colorScheme.primary
                        : _isConnected
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                        controller: _scrollController,
                        padding:
                            const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          return _buildMessageBubble(_messages[index]);
                        },
                      ),
          ),
          _buildTypingIndicator(),
          _buildReplyBar(),
          _buildEditBar(),
          _buildComposer(),
        ],
      ),
    );
  }
}
