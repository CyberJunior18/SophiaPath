import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/social/group.dart';
import '../../models/social/group_message.dart';
import '../../services/social_service.dart';
import '../../services/chat/chat_service.dart';
import '../../services/user_preferences_services.dart';
import '../../services/local_social_storage.dart';
import '../../models/chat/chat_session_user.dart';
import '../../models/user/user.dart';
import '../../widgets/social/message_action_menu.dart';
import '../../widgets/social/group_info_dialog.dart';
import '../../widgets/social/poll_composer_dialog.dart';
import '../../widgets/social/poll_message_widget.dart';
import '../../widgets/profileImage.dart';
import '../../widgets/base64_image_cache.dart';

class GroupChatScreen extends StatefulWidget {
  final Group group;
  const GroupChatScreen({super.key, required this.group});

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final SocialService _socialService = SocialService();
  final ChatService _chatService = ChatService();
  final UserPreferencesService _userService = UserPreferencesService.instance;
  final LocalSocialStorage _localStorage = LocalSocialStorage.instance;
  final ScrollController _scrollController = ScrollController();

  late Group _currentGroup;
  List<GroupMessage> _messages = [];
  bool _isLoading = true;
  User? _currentUser;
  ChatSessionUser? _chatSessionUser;
  Timer? _pollingTimer;
  Timer? _typingPollTimer;
  Timer? _typingDebounceTimer;

  bool _isSearchMode = false;
  String _searchQuery = '';

  GroupMessage? _replyingTo;
  GroupMessage? _editingMessage;
  bool _isDisposed = false;

  // Typing indicators
  List<Map<String, dynamic>> _typingUsers = [];
  bool _iAmTyping = false;

  String get _draftKey => 'group_${_currentGroup.id}';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _currentGroup = widget.group;
    _initUserAndLoadMessages();
    _restoreDraft();
  }

  Future<void> _restoreDraft() async {
    final draft = await _localStorage.getDraft(_draftKey);
    if (draft != null && draft.isNotEmpty && mounted) {
      _messageController.text = draft;
    }
  }

  Future<void> _initUserAndLoadMessages() async {
    try {
      _currentUser = await _userService.getUser();
      try {
        _chatSessionUser = await _chatService.getCurrentUser();
      } catch (e) {
        final cachedIdStr = await _userService.getUserId();
        final cachedId = cachedIdStr != null ? int.tryParse(cachedIdStr) : null;
        if (_currentUser != null && cachedId != null) {
          _chatSessionUser = ChatSessionUser(
            userId: cachedId,
            username: _currentUser!.username,
            displayName: _currentUser!.fullName,
            avatar: _currentUser!.profileImage,
          );
        } else {
          rethrow;
        }
      }
      await _loadMessages();

      _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        _loadMessages(silent: true);
      });

      // Start polling for typing status
      _typingPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _pollTypingStatus();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => _isLoading = true);

    try {
      final messages = await _socialService.getGroupMessages(
        _currentGroup.id,
        userId: _chatSessionUser?.userId.toString(),
      );
      if (mounted) {
        messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        bool hasChanges = !silent || (messages.length != _messages.length);
        if (!hasChanges) {
          for (int i = 0; i < messages.length; i++) {
            if (messages[i].id != _messages[i].id ||
                messages[i].text != _messages[i].text ||
                messages[i].pinned != _messages[i].pinned ||
                messages[i].deleted != _messages[i].deleted ||
                messages[i].edited != _messages[i].edited ||
                messages[i].pollVotes?.toString() != _messages[i].pollVotes?.toString()) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          setState(() {
            _messages = messages;
            _isLoading = false;
          });
        } else if (_isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && !silent) setState(() => _isLoading = false);
    }
  }

  Future<void> _pollTypingStatus() async {
    try {
      final typingUsers = await _socialService.getGroupTypingStatus(
        _currentGroup.id,
      );
      if (mounted) {
        final filtered = typingUsers
            .where(
              (t) =>
                  t['userId']?.toString() !=
                  _chatSessionUser?.userId.toString(),
            )
            .toList();

        bool hasChanges = filtered.length != _typingUsers.length;
        if (!hasChanges) {
          for (int i = 0; i < filtered.length; i++) {
            if (filtered[i]['userId'] != _typingUsers[i]['userId'] ||
                filtered[i]['username'] != _typingUsers[i]['username']) {
              hasChanges = true;
              break;
            }
          }
        }

        if (hasChanges) {
          setState(() {
            _typingUsers = filtered;
          });
        }
      }
    } catch (_) {}
  }

  void _onTextChanged(String text) {
    _localStorage.saveDraft(_draftKey, text);

    if (_chatSessionUser == null) return;

    if (!_iAmTyping) {
      _iAmTyping = true;
      _socialService.setGroupTypingStatus(
        _currentGroup.id,
        _chatSessionUser!.userId.toString(),
        _chatSessionUser!.displayName,
        true,
      );
    }

    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(seconds: 2), () {
      _iAmTyping = false;
      _socialService.setGroupTypingStatus(
        _currentGroup.id,
        _chatSessionUser!.userId.toString(),
        _chatSessionUser!.displayName,
        false,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatSessionUser == null) return;

    // Handle edit mode
    if (_editingMessage != null) {
      final result = await _socialService.editGroupMessage(
        _editingMessage!.id,
        text,
        _chatSessionUser!.userId.toString(),
      );
      if (result != null && mounted) {
        setState(() {
          final idx = _messages.indexWhere((m) => m.id == _editingMessage!.id);
          if (idx >= 0) {
            _messages[idx].text = text;
            _messages[idx].edited = true;
          }
          _editingMessage = null;
          _messageController.clear();
        });
      }
      _localStorage.clearDraft(_draftKey);
      return;
    }

    final outgoing = await _socialService.sendGroupMessage(
      groupId: _currentGroup.id,
      senderId: _chatSessionUser!.userId.toString(),
      senderName: _chatSessionUser!.displayName,
      senderAvatar: _chatSessionUser!.avatar ?? User.defaultProfileImage,
      text: text,
      replyToId: _replyingTo?.id,
      replyToMessage: _replyingTo?.text,
      replyToUsername: _replyingTo?.senderName,
    );

    if (outgoing != null && mounted) {
      setState(() {
        _messages.add(outgoing);
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        _messageController.clear();
        _replyingTo = null;
      });
      _localStorage.clearDraft(_draftKey);
      _scrollToBottom();
    }
  }

  Future<void> _sendPoll() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const PollComposerDialog(),
    );

    if (result == null || _chatSessionUser == null) return;

    // Send poll as a message via the API
    final outgoing = await _socialService.sendGroupMessage(
      groupId: _currentGroup.id,
      senderId: _chatSessionUser!.userId.toString(),
      senderName: _chatSessionUser!.displayName,
      senderAvatar: _chatSessionUser!.avatar ?? User.defaultProfileImage,
      text: '📊 ${result['question']}',
      pollQuestion: result['question'],
      pollOptions: List<String>.from(result['options']),
    );

    if (outgoing != null && mounted) {
      setState(() {
        _messages.add(outgoing);
        _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
    );

    if (pickedFile == null || _chatSessionUser == null) return;

    if (!mounted) return;

    final captionController = TextEditingController();
    final send = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Send Image',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(File(pickedFile.path), fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: captionController,
              decoration: InputDecoration(
                hintText: 'Add a caption...',
                hintStyle: GoogleFonts.poppins(fontSize: 14),
                border: const UnderlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Send',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (send == true) {
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64String = base64Encode(bytes);

      final extension = pickedFile.path.split('.').last.toLowerCase();
      final mimeType =
          (extension == 'png' || extension == 'gif' || extension == 'webp')
          ? 'image/$extension'
          : 'image/jpeg';

      final dataUrl = 'data:$mimeType;base64,$base64String';
      final caption = captionController.text.trim();
      final text = '[IMAGE]:$dataUrl${caption.isNotEmpty ? '|$caption' : ''}';

      final outgoing = await _socialService.sendGroupMessage(
        groupId: _currentGroup.id,
        senderId: _chatSessionUser!.userId.toString(),
        senderName: _chatSessionUser!.displayName,
        senderAvatar: _chatSessionUser!.avatar ?? User.defaultProfileImage,
        text: text,
      );

      if (outgoing != null && mounted) {
        setState(() {
          _messages.add(outgoing);
          _messages.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        });
        _scrollToBottom();
      }
    }
  }

  bool _showScrollToBottomButton = false;

  void _scrollListener() {
    if (_isDisposed || !_scrollController.hasClients) return;
    final currentScroll = _scrollController.offset;
    final showButton = currentScroll > 200;
    if (showButton != _showScrollToBottomButton) {
      setState(() {
        _showScrollToBottomButton = showButton;
      });
    }
  }

  void _scrollToBottom() {
    if (_isDisposed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && _scrollController.hasClients) {
        _scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showGroupInfo() {
    if (_currentUser == null || _chatSessionUser == null) return;
    showDialog(
      context: context,
      builder: (context) => GroupInfoDialog(
        group: _currentGroup,
        chatSessionUser: _chatSessionUser!,
        socialService: _socialService,
        onGroupUpdated: () {
          _loadMessages();
        },
      ),
    );
  }

  void _showMessageActionMenu(GroupMessage message, bool isMe) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => MessageActionMenu(
        message: message,
        isMyMessage: isMe,
        onReply: () => setState(() => _replyingTo = message),
        onForward: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Forward will be available soon')),
          );
        },
        onPin: () async {
          final success = await _socialService.pinGroupMessage(
            message.id,
            !message.pinned,
          );
          if (success) {
            setState(() {
              message.pinned = !message.pinned;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    message.pinned ? 'Message pinned' : 'Message unpinned',
                  ),
                ),
              );
            }
          }
        },
        onStar: () async {
          await _localStorage.toggleStarMessage(
            'group_${_currentGroup.id}',
            message.id,
          );
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Message starred')));
          }
        },
        onCopy: () {
          Clipboard.setData(ClipboardData(text: message.text));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
        },
        onDelete: () async {
          if (_chatSessionUser == null) return;
          final success = await _socialService.deleteGroupMessage(
            message.id,
            _chatSessionUser!.userId.toString(),
          );
          if (success) {
            setState(() {
              message.deleted = true;
              message.text = 'This message was deleted';
            });
          }
        },
        onEdit: isMe
            ? () {
                setState(() {
                  _editingMessage = message;
                  _messageController.text = message.text;
                });
              }
            : null,
      ),
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.removeListener(_scrollListener);
    _pollingTimer?.cancel();
    _typingPollTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime timestamp) {
    final localTime = timestamp.toLocal();
    final hour = localTime.hour.toString().padLeft(2, '0');
    final minute = localTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Widget _buildMessageBubble(GroupMessage message) {
    final isMe =
        _chatSessionUser != null &&
        message.senderId == _chatSessionUser!.userId.toString();
    final theme = Theme.of(context);
    final otherBubbleColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainerHighest
        : theme.colorScheme.surface;

    // Check for poll message
    if (message.pollQuestion != null && message.pollOptions != null) {
      return _buildPollBubble(message, isMe, theme);
    }

    final bool isImage =
        !message.deleted && message.text.startsWith('[IMAGE]:');
    String? imageUrl;
    String? caption;
    if (isImage) {
      final content = message.text.substring(8);
      final parts = content.split('|');
      imageUrl = parts[0];
      if (parts.length > 1) {
        caption = parts.sublist(1).join('|');
      }
    }

    Widget buildImageWidget(String dataUrl) {
      try {
        final placeholderColor = theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.1);

        if (dataUrl.startsWith('data:') && dataUrl.contains(';base64,')) {
          final base64Content = dataUrl.split(';base64,').last;
          final bytes = Base64ImageCache.decode(base64Content);
          return Container(
            width: 250,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: placeholderColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                fit: BoxFit.cover,
                width: 250,
                height: 200,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image),
              ),
            ),
          );
        } else {
          return Container(
            width: 250,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: placeholderColor,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                dataUrl,
                fit: BoxFit.cover,
                width: 250,
                height: 200,
                errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image),
              ),
            ),
          );
        }
      } catch (_) {
        return const Icon(Icons.broken_image);
      }
    }

    final actualText = message.deleted
        ? 'This message was deleted'
        : message.text;

    return GestureDetector(
      onLongPress: () => _showMessageActionMenu(message, isMe),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: isMe
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (message.pinned)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 8, right: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.push_pin,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pinned Message',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isMe ? theme.colorScheme.primary : otherBubbleColor,
                  border: isMe
                      ? null
                      : Border.all(
                          color: theme.colorScheme.outlineVariant.withOpacity(
                            0.75,
                          ),
                        ),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
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
                          message.senderName,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    // Reply preview (proper fields)
                    if (message.replyToMessage != null &&
                        message.replyToMessage!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
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
                                fontStyle: FontStyle.italic,
                                color: isMe ? Colors.white70 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    // Forwarded indicator
                    if (message.forwarded)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.forward,
                              size: 12,
                              color: isMe
                                  ? Colors.white70
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Forwarded',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: isMe
                                    ? Colors.white70
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (isImage && imageUrl != null) ...[
                      GestureDetector(
                        onTap: () {
                          final localImageUrl = imageUrl;
                          if (localImageUrl == null) return;
                          showDialog(
                            context: context,
                            builder: (context) => Dialog(
                              backgroundColor: Colors.transparent,
                              insetPadding: EdgeInsets.zero,
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                behavior: HitTestBehavior.opaque,
                                child: Stack(
                                  children: [
                                    Center(
                                      child: GestureDetector(
                                        onTap: () {}, // Prevent tap from bubbling up to close the dialog
                                        child: InteractiveViewer(
                                          child: localImageUrl.startsWith('data:')
                                              ? Image.memory(
                                                  Base64ImageCache.decode(
                                                    localImageUrl
                                                        .split(';base64,')
                                                        .last,
                                                  ),
                                                )
                                              : Image.network(localImageUrl),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 40,
                                      right: 20,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.close,
                                          color: Colors.white,
                                          size: 30,
                                        ),
                                        onPressed: () => Navigator.pop(context),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                        child: buildImageWidget(imageUrl),
                      ),
                      if (caption != null && caption.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          caption,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: isMe
                                ? Colors.white
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ] else
                      Text(
                        actualText,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: isMe
                              ? Colors.white
                              : theme.colorScheme.onSurface,
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
                                    ? Colors.white.withOpacity(0.6)
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        Text(
                          _formatTimestamp(message.timestamp),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: isMe
                                ? Colors.white.withOpacity(0.75)
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

  Widget _buildPollBubble(GroupMessage message, bool isMe, ThemeData theme) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: isMe
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4, left: 4),
                child: Text(
                  message.senderName,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            PollMessageWidget(
              question: message.pollQuestion!,
              options: message.pollOptions!,
              votes: message.pollVotes,
              currentUserId: _chatSessionUser?.userId.toString(),
              onVote: (optionIndex) async {
                if (_chatSessionUser == null) return;
                final result = await _socialService.voteGroupPoll(
                  message.id,
                  optionIndex,
                  _chatSessionUser!.userId.toString(),
                );
                if (result != null) {
                  _loadMessages(silent: true);
                }
              },
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(message.timestamp),
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    if (_typingUsers.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final names = _typingUsers
        .map((t) => t['username'] ?? 'Someone')
        .take(3)
        .join(', ');

    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 4),
      child: Text(
        '$names ${_typingUsers.length == 1 ? 'is' : 'are'} typing...',
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontStyle: FontStyle.italic,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainer
        : theme.colorScheme.surface;

    final filteredMessages = _messages
        .where(
          (m) =>
              _searchQuery.isEmpty ||
              m.text.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: theme.colorScheme.onSurface,
        title: _isSearchMode
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              )
            : InkWell(
                onTap: _showGroupInfo,
                child: Row(
                  children: [
                     ProfileImage(
                       imageUrl: _currentGroup.avatar,
                       radius: 18,
                       name: _currentGroup.name,
                     ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentGroup.name,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _typingUsers.isNotEmpty
                                ? '${_typingUsers.map((t) => t['username']).take(2).join(', ')} typing...'
                                : '${_currentGroup.members?.length ?? _currentGroup.membersCount ?? 0} members',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: _typingUsers.isNotEmpty
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearchMode ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearchMode = !_isSearchMode;
                if (!_isSearchMode) _searchQuery = '';
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: _showGroupInfo,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredMessages.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isNotEmpty
                              ? 'No messages found'
                              : 'No messages yet',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: filteredMessages.length,
                        itemBuilder: (context, index) =>
                            _buildMessageBubble(filteredMessages[index]),
                      ),
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: AnimatedOpacity(
                    opacity: _showScrollToBottomButton ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: _showScrollToBottomButton
                        ? GestureDetector(
                            onTap: _scrollToBottom,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.25),
                                    blurRadius: 6,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.arrow_downward,
                                color: Colors.white,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          _buildTypingIndicator(),
          if (_replyingTo != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyingTo!.senderName}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        Text(
                          _replyingTo!.text,
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
            ),
          if (_editingMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
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
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              color: theme.colorScheme.surface,
              child: Row(
                children: [
                  // Poll button
                  IconButton(
                    icon: Icon(
                      Icons.poll_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: _sendPoll,
                    tooltip: 'Create Poll',
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.image_outlined,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    onPressed: _pickImage,
                    tooltip: 'Send Image',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        hintText: _editingMessage != null
                            ? 'Edit message...'
                            : 'Message',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(
                      _editingMessage != null ? Icons.check : Icons.send,
                    ),
                    color: theme.colorScheme.primary,
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
