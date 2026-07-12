import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/social/community.dart';
import '../../models/social/question.dart';
import '../../models/social/comment.dart';
import '../../services/social_service.dart';
import '../../services/chat/chat_service.dart';
import '../../widgets/social/poll_message_widget.dart';
import '../../services/local_social_storage.dart';
import '../../widgets/profileImage.dart';

class QuestionDetailScreen extends StatefulWidget {
  final Community? community;
  final Room? room;
  final Question question;

  const QuestionDetailScreen({
    super.key,
    this.community,
    this.room,
    required this.question,
  });

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  final SocialService _socialService = SocialService();
  final ChatService _chatService = ChatService();
  final TextEditingController _inputController = TextEditingController();

  late Question _question;
  List<Comment> _comments = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _currentUsername;
  bool _isSaved = false;

  // Reply context state
  Comment? _replyingToComment;

  // Edit states
  Question? _editingQuestion;
  Comment? _editingComment;

  @override
  void initState() {
    super.initState();
    _question = widget.question;
    _initData();
  }

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _initData() async {
    try {
      final user = await _chatService.getCurrentUser();
      _currentUserId = user.userId.toString();
      _currentUsername = user.username;
    } catch (_) {
      _currentUserId = "1";
      _currentUsername = "you";
    }
    _loadComments();
    _refreshQuestion();
    final saved = await LocalSocialStorage.instance.isPostSaved(_question.id);
    if (mounted) {
      setState(() {
        _isSaved = saved;
      });
    }
  }

  Future<void> _refreshQuestion() async {
    try {
      final updated = await _socialService.getQuestions(_question.roomId, _currentUserId ?? "1");
      final match = updated.firstWhere((q) => q.id == _question.id);
      if (mounted) {
        setState(() {
          _question = match;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final comments = await _socialService.getComments(_question.id, _currentUserId ?? "1");
      if (mounted) {
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSubmit() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    if (_editingComment != null) {
      final response = await _socialService.updateComment(_editingComment!.id, text);
      if (response != null && mounted) {
        setState(() {
          _editingComment = null;
          _inputController.clear();
        });
        _loadComments();
      }
      return;
    }

    if (_replyingToComment != null) {
      final success = await _socialService.addReply(
        questionId: _question.id,
        commentId: _replyingToComment!.id,
        content: text,
        authorId: _currentUserId ?? "1",
        authorName: _currentUsername ?? "You",
        authorAvatar: "",
      );
      if (success && mounted) {
        setState(() {
          _replyingToComment = null;
          _inputController.clear();
        });
        _loadComments();
      }
      return;
    }

    // Default post a comment
    final success = await _socialService.addComment(
      questionId: _question.id,
      content: text,
      authorId: _currentUserId ?? "1",
      authorName: _currentUsername ?? "You",
      authorAvatar: "",
    );

    if (success && mounted) {
      _inputController.clear();
      _loadComments();
    }
  }

  Future<void> _handleQuestionVote(bool up) async {
    if (_currentUserId == null) return;
    Map<String, dynamic>? result;
    if (up) {
      result = await _socialService.upvoteQuestion(_question.id, _currentUserId!);
    } else {
      result = await _socialService.downvoteQuestion(_question.id, _currentUserId!);
    }
    if (result != null) {
      _refreshQuestion();
    }
  }

  Future<void> _handleCommentVote(Comment comment, bool up) async {
    if (_currentUserId == null) return;
    Map<String, dynamic>? result;
    if (up) {
      result = await _socialService.upvoteComment(comment.id, _currentUserId!);
    } else {
      result = await _socialService.downvoteComment(comment.id, _currentUserId!);
    }
    if (result != null) {
      _loadComments();
    }
  }

  Future<void> _handleDeleteComment(Comment comment) async {
    if (_currentUserId == null) return;
    final success = await _socialService.deleteComment(comment.id, _currentUserId!);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comment deleted')),
      );
      _loadComments();
    }
  }

  Future<void> _handleDeleteQuestion() async {
    if (_currentUserId == null) return;
    final success = await _socialService.deleteQuestion(_question.id, _currentUserId!);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Question deleted')),
      );
      Navigator.pop(context);
    }
  }

  void _showCommentOptions(Comment comment) {
    final isMe = comment.authorId == _currentUserId;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.reply),
                title: Text('Reply', style: GoogleFonts.poppins()),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _replyingToComment = comment;
                    _editingComment = null;
                  });
                },
              ),
              if (isMe) ...[
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text('Edit Comment', style: GoogleFonts.poppins()),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingComment = comment;
                      _replyingToComment = null;
                      _inputController.text = comment.content;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text('Delete Comment', style: GoogleFonts.poppins(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _handleDeleteComment(comment);
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildComment(Comment comment, {bool isReply = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: isReply ? 36.0 : 16.0,
        right: 16.0,
        top: 12.0,
        bottom: 8.0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _showCommentOptions(comment),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withOpacity(0.4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ProfileImage(
                        imageUrl: comment.authorAvatar,
                        radius: 12,
                        name: comment.authorName,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        comment.authorName,
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(comment.timestamp),
                        style: GoogleFonts.poppins(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment.content,
                    style: GoogleFonts.poppins(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          comment.userUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                          size: 14,
                          color: comment.userUpvoted ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => _handleCommentVote(comment, true),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 4),
                      Text('${comment.upvotes}', style: GoogleFonts.poppins(fontSize: 11)),
                      const SizedBox(width: 16),
                      IconButton(
                        icon: Icon(
                          comment.userDownvoted ? Icons.thumb_down : Icons.thumb_down_outlined,
                          size: 14,
                          color: comment.userDownvoted ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                        ),
                        onPressed: () => _handleCommentVote(comment, false),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                      const SizedBox(width: 16),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _replyingToComment = comment;
                            _editingComment = null;
                          });
                        },
                        icon: const Icon(Icons.reply, size: 14),
                        label: Text('Reply', style: GoogleFonts.poppins(fontSize: 11)),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (comment.replies.isNotEmpty)
            Column(
              children: comment.replies.map((r) => _buildComment(r, isReply: true)).toList(),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildPollSection(ThemeData theme) {
    if (_question.pollQuestion == null || _question.pollOptions == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: PollMessageWidget(
        question: _question.pollQuestion!,
        options: _question.pollOptions!,
        votes: _question.pollVotes,
        currentUserId: _currentUserId,
        onVote: (idx) async {
          if (_currentUserId == null) return;
          final res = await _socialService.votePostPoll(_question.id, idx, _currentUserId!);
          if (res != null) {
            _refreshQuestion();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appBarColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.surfaceContainer
        : theme.colorScheme.surface;

    final isQuestionAuthor = _question.authorId == _currentUserId;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          _question.title,
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: () async {
              final newState = await LocalSocialStorage.instance.toggleSavePost(_question.id);
              setState(() {
                _isSaved = newState;
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(newState ? 'Post saved' : 'Post removed from saved list')),
                );
              }
            },
            tooltip: _isSaved ? 'Remove Bookmark' : 'Bookmark Post',
          ),
          if (isQuestionAuthor)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: _handleDeleteQuestion,
              tooltip: 'Delete Question',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Post Container
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: theme.colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ProfileImage(
                              imageUrl: _question.authorAvatar,
                              radius: 18,
                              name: _question.authorName,
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _question.authorName,
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  _formatDate(_question.timestamp),
                                  style: GoogleFonts.poppins(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _question.title,
                          style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _question.content,
                          style: GoogleFonts.poppins(fontSize: 16),
                        ),
                        _buildPollSection(theme),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      _question.userUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                                      size: 16,
                                      color: _question.userUpvoted ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                    ),
                                    onPressed: () => _handleQuestionVote(true),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                  const SizedBox(width: 4),
                                  Text('${_question.upvotes}', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(
                                      _question.userDownvoted ? Icons.thumb_down : Icons.thumb_down_outlined,
                                      size: 16,
                                      color: _question.userDownvoted ? theme.colorScheme.error : theme.colorScheme.onSurface,
                                    ),
                                    onPressed: () => _handleQuestionVote(false),
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Comments section title
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      'Comments (${_comments.length})',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_comments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Text(
                          'No comments yet. Be the first!',
                          style: GoogleFonts.poppins(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    Column(
                      children: _comments.map((c) => _buildComment(c)).toList(),
                    ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),

          // Input field for comment / reply
          if (_replyingToComment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Replying to ${_replyingToComment!.authorName}',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => setState(() => _replyingToComment = null),
                  ),
                ],
              ),
            ),
          if (_editingComment != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.primaryContainer.withOpacity(0.3),
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Editing comment',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _editingComment = null;
                        _inputController.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: InputDecoration(
                        hintText: _editingComment != null
                            ? 'Edit comment...'
                            : _replyingToComment != null
                                ? 'Add a reply...'
                                : 'Add a comment...',
                        filled: true,
                        fillColor: theme.colorScheme.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(_editingComment != null ? Icons.check : Icons.send),
                    color: theme.colorScheme.primary,
                    onPressed: _handleSubmit,
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
