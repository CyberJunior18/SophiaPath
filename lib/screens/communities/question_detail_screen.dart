import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/social/community.dart';
import '../../models/social/question.dart';
import '../../models/social/comment.dart';
import '../../models/user/user_role.dart';
import '../../services/user_preferences_services.dart';
import '../../services/social_service.dart';
import '../../services/chat/chat_service.dart';
import '../../services/communities_socket_service.dart';
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
  List<StreamSubscription> _socketSubscriptions = [];

  // Reply context state
  Comment? _replyingToComment;

  // Edit states
  Comment? _editingComment;

  @override
  void initState() {
    super.initState();
    _question = widget.question;
    _initData();
  }

  UserRole? _currentUserGlobalRole;

  @override
  void dispose() {
    for (var sub in _socketSubscriptions) {
      sub.cancel();
    }
    final questionIdInt = int.tryParse(_question.id);
    if (questionIdInt != null) {
      CommunitiesSocketService().leaveQuestionRoom(questionIdInt);
    }
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

    final localUser = await UserPreferencesService.instance.getUser();
    if (localUser != null) {
      _currentUserGlobalRole = localUser.role;
    }

    _loadComments();
    _refreshQuestion();
    final saved = await LocalSocialStorage.instance.isPostSaved(_question.id);
    if (mounted) {
      setState(() {
        _isSaved = saved;
      });
    }

    // Connect socket and listen to events
    final userIdInt = int.tryParse(_currentUserId ?? '1') ?? 1;
    final socketService = CommunitiesSocketService();
    socketService.connect(userIdInt);
    
    final questionIdInt = int.tryParse(_question.id);
    if (questionIdInt != null) {
      socketService.joinQuestionRoom(questionIdInt);
    }

    _socketSubscriptions.add(socketService.onQuestionVoted.listen((data) {
      if (data['id'].toString() == _question.id) {
        setState(() {
          _question = _parseQuestionFromSocket(data);
        });
      }
    }));

    _socketSubscriptions.add(socketService.onQuestionUpdated.listen((data) {
      if (data['id'].toString() == _question.id) {
        setState(() {
          _question = _parseQuestionFromSocket(data);
        });
      }
    }));

    _socketSubscriptions.add(socketService.onQuestionDeleted.listen((data) {
      if (data['id'].toString() == _question.id && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This question was deleted.')),
        );
        Navigator.pop(context);
      }
    }));

    _socketSubscriptions.add(socketService.onCommentAdded.listen((data) {
      if (data['questionId'].toString() == _question.id) {
        final comment = _parseCommentFromSocket(data);
        setState(() {
          // Remove optimistic duplicates
          _comments.removeWhere((c) =>
              c.id.startsWith('temp_') &&
              c.authorId == comment.authorId &&
              c.content.trim() == comment.content.trim());

          final idx = _comments.indexWhere((c) => c.id == comment.id);
          if (idx == -1) {
            _comments.add(comment);
          } else {
            _comments[idx] = comment;
          }
          _comments.sort((a, b) {
            final voteDiff = (b.upvotes) - (a.upvotes);
            if (voteDiff != 0) return voteDiff;
            return a.timestamp.compareTo(b.timestamp);
          });
        });
      }
    }));

    _socketSubscriptions.add(socketService.onCommentVoted.listen((data) {
      if (data['questionId'].toString() == _question.id) {
        final comment = _parseCommentFromSocket(data);
        setState(() {
          final idx = _comments.indexWhere((c) => c.id == comment.id);
          if (idx != -1) {
            final existingReplies = _comments[idx].replies;
            _comments[idx] = Comment(
              id: comment.id,
              questionId: comment.questionId,
              content: comment.content,
              authorId: comment.authorId,
              authorName: comment.authorName,
              authorAvatar: comment.authorAvatar,
              timestamp: comment.timestamp,
              upvotes: comment.upvotes,
              upvotedUsers: comment.upvotedUsers,
              downvotedUsers: comment.downvotedUsers,
              userUpvoted: comment.userUpvoted,
              userDownvoted: comment.userDownvoted,
              replies: comment.replies.isNotEmpty ? comment.replies : existingReplies,
            );
          }
        });
      }
    }));

    _socketSubscriptions.add(socketService.onCommentUpdated.listen((data) {
      if (data['questionId'].toString() == _question.id) {
        final comment = _parseCommentFromSocket(data);
        setState(() {
          final idx = _comments.indexWhere((c) => c.id == comment.id);
          if (idx != -1) {
            final existingReplies = _comments[idx].replies;
            _comments[idx] = Comment(
              id: comment.id,
              questionId: comment.questionId,
              content: comment.content,
              authorId: comment.authorId,
              authorName: comment.authorName,
              authorAvatar: comment.authorAvatar,
              timestamp: comment.timestamp,
              upvotes: comment.upvotes,
              upvotedUsers: comment.upvotedUsers,
              downvotedUsers: comment.downvotedUsers,
              userUpvoted: comment.userUpvoted,
              userDownvoted: comment.userDownvoted,
              replies: comment.replies.isNotEmpty ? comment.replies : existingReplies,
            );
          }
        });
      }
    }));

    _socketSubscriptions.add(socketService.onCommentDeleted.listen((data) {
      final commentId = data['id'].toString();
      setState(() {
        _comments.removeWhere((c) => c.id == commentId);
      });
    }));

    _socketSubscriptions.add(socketService.onReplyAdded.listen((data) {
      final parentCommentId = data['commentId']?.toString();
      if (parentCommentId != null) {
        final reply = _parseCommentFromSocket(data);
        setState(() {
          final parentIdx = _comments.indexWhere((c) => c.id == parentCommentId);
          if (parentIdx != -1) {
            final parent = _comments[parentIdx];
            
            // Remove optimistic duplicates
            final updatedReplies = List<Comment>.from(parent.replies)
              ..removeWhere((r) =>
                  r.id.startsWith('temp_') &&
                  r.authorId == reply.authorId &&
                  r.content.trim() == reply.content.trim());

            final exists = updatedReplies.any((r) => r.id == reply.id);
            if (!exists) {
              updatedReplies.add(reply);
            } else {
              final idx = updatedReplies.indexWhere((r) => r.id == reply.id);
              if (idx != -1) {
                updatedReplies[idx] = reply;
              }
            }

            _comments[parentIdx] = Comment(
              id: parent.id,
              questionId: parent.questionId,
              content: parent.content,
              authorId: parent.authorId,
              authorName: parent.authorName,
              authorAvatar: parent.authorAvatar,
              timestamp: parent.timestamp,
              upvotes: parent.upvotes,
              upvotedUsers: parent.upvotedUsers,
              downvotedUsers: parent.downvotedUsers,
              userUpvoted: parent.userUpvoted,
              userDownvoted: parent.userDownvoted,
              replies: updatedReplies,
            );
          }
        });
      }
    }));

    _socketSubscriptions.add(socketService.onReplyUpdated.listen((data) {
      final parentCommentId = data['commentId']?.toString();
      if (parentCommentId != null) {
        final reply = _parseCommentFromSocket(data);
        setState(() {
          final parentIdx = _comments.indexWhere((c) => c.id == parentCommentId);
          if (parentIdx != -1) {
            final parent = _comments[parentIdx];
            final replyIdx = parent.replies.indexWhere((r) => r.id == reply.id);
            if (replyIdx != -1) {
              final updatedReplies = List<Comment>.from(parent.replies);
              updatedReplies[replyIdx] = reply;
              _comments[parentIdx] = Comment(
                id: parent.id,
                questionId: parent.questionId,
                content: parent.content,
                authorId: parent.authorId,
                authorName: parent.authorName,
                authorAvatar: parent.authorAvatar,
                timestamp: parent.timestamp,
                upvotes: parent.upvotes,
                upvotedUsers: parent.upvotedUsers,
                downvotedUsers: parent.downvotedUsers,
                userUpvoted: parent.userUpvoted,
                userDownvoted: parent.userDownvoted,
                replies: updatedReplies,
              );
            }
          }
        });
      }
    }));

    _socketSubscriptions.add(socketService.onReplyDeleted.listen((data) {
      final replyId = data['id'].toString();
      final parentCommentId = data['commentId']?.toString();
      if (parentCommentId != null) {
        setState(() {
          final parentIdx = _comments.indexWhere((c) => c.id == parentCommentId);
          if (parentIdx != -1) {
            final parent = _comments[parentIdx];
            final updatedReplies = List<Comment>.from(parent.replies)
              ..removeWhere((r) => r.id == replyId);
            _comments[parentIdx] = Comment(
              id: parent.id,
              questionId: parent.questionId,
              content: parent.content,
              authorId: parent.authorId,
              authorName: parent.authorName,
              authorAvatar: parent.authorAvatar,
              timestamp: parent.timestamp,
              upvotes: parent.upvotes,
              upvotedUsers: parent.upvotedUsers,
              downvotedUsers: parent.downvotedUsers,
              userUpvoted: parent.userUpvoted,
              userDownvoted: parent.userDownvoted,
              replies: updatedReplies,
            );
          }
        });
      }
    }));

    _socketSubscriptions.add(socketService.onPollVoted.listen((data) {
      if (data['id'].toString() == _question.id) {
        setState(() {
          _question = _parseQuestionFromSocket(data);
        });
      }
    }));
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
      final oldComments = List<Comment>.from(_comments);
      final commentToEdit = _editingComment!;
      setState(() {
        final idx = _comments.indexWhere((c) => c.id == commentToEdit.id);
        if (idx != -1) {
          _comments[idx] = Comment(
            id: commentToEdit.id,
            questionId: commentToEdit.questionId,
            content: text,
            authorId: commentToEdit.authorId,
            authorName: commentToEdit.authorName,
            authorAvatar: commentToEdit.authorAvatar,
            timestamp: commentToEdit.timestamp,
            upvotes: commentToEdit.upvotes,
            upvotedUsers: commentToEdit.upvotedUsers,
            downvotedUsers: commentToEdit.downvotedUsers,
            userUpvoted: commentToEdit.userUpvoted,
            userDownvoted: commentToEdit.userDownvoted,
            replies: commentToEdit.replies,
          );
        }
        _editingComment = null;
        _inputController.clear();
      });

      final response = await _socialService.updateComment(commentToEdit.id, text);
      if (response == null && mounted) {
        setState(() {
          _comments = oldComments;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update comment.')),
        );
      }
      return;
    }

    if (_replyingToComment != null) {
      final oldComments = List<Comment>.from(_comments);
      final parentComment = _replyingToComment!;
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      final optimisticReply = Comment(
        id: tempId,
        questionId: parentComment.id,
        content: text,
        authorId: _currentUserId ?? "1",
        authorName: _currentUsername ?? "You",
        authorAvatar: "",
        timestamp: DateTime.now(),
        upvotes: 0,
        replies: [],
      );

      setState(() {
        final idx = _comments.indexWhere((c) => c.id == parentComment.id);
        if (idx != -1) {
          final updatedReplies = List<Comment>.from(_comments[idx].replies)..add(optimisticReply);
          _comments[idx] = Comment(
            id: parentComment.id,
            questionId: parentComment.questionId,
            content: parentComment.content,
            authorId: parentComment.authorId,
            authorName: parentComment.authorName,
            authorAvatar: parentComment.authorAvatar,
            timestamp: parentComment.timestamp,
            upvotes: parentComment.upvotes,
            upvotedUsers: parentComment.upvotedUsers,
            downvotedUsers: parentComment.downvotedUsers,
            userUpvoted: parentComment.userUpvoted,
            userDownvoted: parentComment.userDownvoted,
            replies: updatedReplies,
          );
        }
        _replyingToComment = null;
        _inputController.clear();
      });

      final success = await _socialService.addReply(
        questionId: _question.id,
        commentId: parentComment.id,
        content: text,
        authorId: _currentUserId ?? "1",
        authorName: _currentUsername ?? "You",
        authorAvatar: "",
      );
      if (!success && mounted) {
        setState(() {
          _comments = oldComments;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add reply.')),
        );
      }
      return;
    }

    // Default post a comment
    final oldComments = List<Comment>.from(_comments);
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticComment = Comment(
      id: tempId,
      questionId: _question.id,
      content: text,
      authorId: _currentUserId ?? "1",
      authorName: _currentUsername ?? "You",
      authorAvatar: "",
      timestamp: DateTime.now(),
      upvotes: 0,
      replies: [],
    );

    setState(() {
      _comments.add(optimisticComment);
      _inputController.clear();
    });

    final success = await _socialService.addComment(
      questionId: _question.id,
      content: text,
      authorId: _currentUserId ?? "1",
      authorName: _currentUsername ?? "You",
      authorAvatar: "",
    );

    if (!success && mounted) {
      setState(() {
        _comments = oldComments;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to add comment.')),
      );
    }
  }

  Future<void> _handleQuestionVote(bool up) async {
    if (_currentUserId == null) return;
    final oldQuestion = _question;

    final userIdInt = int.tryParse(_currentUserId!);
    final upvotedUsers = List<dynamic>.from(_question.upvotedUsers);
    final downvotedUsers = List<dynamic>.from(_question.downvotedUsers);

    bool newUserUpvoted = _question.userUpvoted;
    bool newUserDownvoted = _question.userDownvoted;

    if (up) {
      if (_question.userUpvoted) {
        newUserUpvoted = false;
        upvotedUsers.remove(userIdInt);
        upvotedUsers.remove(_currentUserId);
      } else {
        newUserUpvoted = true;
        upvotedUsers.add(userIdInt);
        if (_question.userDownvoted) {
          newUserDownvoted = false;
          downvotedUsers.remove(userIdInt);
          downvotedUsers.remove(_currentUserId);
        }
      }
    } else {
      if (_question.userDownvoted) {
        newUserDownvoted = false;
        downvotedUsers.remove(userIdInt);
        downvotedUsers.remove(_currentUserId);
      } else {
        newUserDownvoted = true;
        downvotedUsers.add(userIdInt);
        if (_question.userUpvoted) {
          newUserUpvoted = false;
          upvotedUsers.remove(userIdInt);
          upvotedUsers.remove(_currentUserId);
        }
      }
    }

    final newUpvotes = upvotedUsers.length - downvotedUsers.length;

    setState(() {
      _question = Question(
        id: _question.id,
        roomId: _question.roomId,
        title: _question.title,
        content: _question.content,
        authorId: _question.authorId,
        authorName: _question.authorName,
        authorAvatar: _question.authorAvatar,
        timestamp: _question.timestamp,
        upvotes: newUpvotes,
        upvotedUsers: upvotedUsers,
        downvotedUsers: downvotedUsers,
        userUpvoted: newUserUpvoted,
        userDownvoted: newUserDownvoted,
        commentsCount: _question.commentsCount,
        pollQuestion: _question.pollQuestion,
        pollOptions: _question.pollOptions,
        pollVotes: _question.pollVotes,
      );
    });

    Map<String, dynamic>? result;
    try {
      if (up) {
        result = await _socialService.upvoteQuestion(_question.id, _currentUserId!);
      } else {
        result = await _socialService.downvoteQuestion(_question.id, _currentUserId!);
      }
    } catch (_) {}

    if (result == null && mounted) {
      setState(() {
        _question = oldQuestion;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to vote. Please check your connection.')),
      );
    }
  }

  Future<void> _handleCommentVote(Comment comment, bool up) async {
    if (_currentUserId == null) return;
    final oldComments = List<Comment>.from(_comments);

    final userIdInt = int.tryParse(_currentUserId!);
    final upvotedUsers = List<dynamic>.from(comment.upvotedUsers);
    final downvotedUsers = List<dynamic>.from(comment.downvotedUsers);

    bool newUserUpvoted = comment.userUpvoted;
    bool newUserDownvoted = comment.userDownvoted;

    if (up) {
      if (comment.userUpvoted) {
        newUserUpvoted = false;
        upvotedUsers.remove(userIdInt);
        upvotedUsers.remove(_currentUserId);
      } else {
        newUserUpvoted = true;
        upvotedUsers.add(userIdInt);
        if (comment.userDownvoted) {
          newUserDownvoted = false;
          downvotedUsers.remove(userIdInt);
          downvotedUsers.remove(_currentUserId);
        }
      }
    } else {
      if (comment.userDownvoted) {
        newUserDownvoted = false;
        downvotedUsers.remove(userIdInt);
        downvotedUsers.remove(_currentUserId);
      } else {
        newUserDownvoted = true;
        downvotedUsers.add(userIdInt);
        if (comment.userUpvoted) {
          newUserUpvoted = false;
          upvotedUsers.remove(userIdInt);
          upvotedUsers.remove(_currentUserId);
        }
      }
    }

    final newUpvotes = upvotedUsers.length - downvotedUsers.length;
    
    setState(() {
      final idx = _comments.indexWhere((c) => c.id == comment.id);
      if (idx != -1) {
        _comments[idx] = Comment(
          id: comment.id,
          questionId: comment.questionId,
          content: comment.content,
          authorId: comment.authorId,
          authorName: comment.authorName,
          authorAvatar: comment.authorAvatar,
          timestamp: comment.timestamp,
          upvotes: newUpvotes,
          upvotedUsers: upvotedUsers,
          downvotedUsers: downvotedUsers,
          userUpvoted: newUserUpvoted,
          userDownvoted: newUserDownvoted,
          replies: comment.replies,
        );
      }
    });

    Map<String, dynamic>? result;
    try {
      if (up) {
        result = await _socialService.upvoteComment(comment.id, _currentUserId!);
      } else {
        result = await _socialService.downvoteComment(comment.id, _currentUserId!);
      }
    } catch (_) {}

    if (result == null && mounted) {
      setState(() {
        _comments = oldComments;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to vote on comment. Please check connection.')),
      );
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

  Future<void> _handleDeleteReply(Comment reply) async {
    if (_currentUserId == null) return;
    final success = await _socialService.deleteReply(reply.id, _currentUserId!);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reply deleted')),
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

  bool _canDeleteComment(Comment comment) {
    if (_currentUserId == null) return false;
    
    // 1. Author can delete their own comment
    if (comment.authorId == _currentUserId) return true;
    
    // 2. Global Admin or Moderator
    if (_currentUserGlobalRole == UserRole.admin || _currentUserGlobalRole == UserRole.moderator) {
      return true;
    }
    
    // 3. Community Owner
    if (widget.community != null && widget.community!.ownerId == _currentUserId) {
      return true;
    }
    
    // 4. Community Moderator
    if (widget.community != null && widget.community!.moderatorIds.contains(_currentUserId)) {
      return true;
    }
    
    return false;
  }

  void _showCommentOptions(Comment comment, {bool isReply = false}) {
    final isMe = comment.authorId == _currentUserId;
    final canDelete = _canDeleteComment(comment);

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
              if (isMe)
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(isReply ? 'Edit Reply' : 'Edit Comment', style: GoogleFonts.poppins()),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingComment = comment;
                      _replyingToComment = null;
                      _inputController.text = comment.content;
                    });
                  },
                ),
              if (canDelete)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(
                    isReply ? 'Delete Reply' : 'Delete Comment',
                    style: GoogleFonts.poppins(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    if (isReply) {
                      _handleDeleteReply(comment);
                    } else {
                      _handleDeleteComment(comment);
                    }
                  },
                ),
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
            onLongPress: () => _showCommentOptions(comment, isReply: isReply),
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

  Question _parseQuestionFromSocket(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    final userIdVal = int.tryParse(_currentUserId ?? '');
    final userIdStr = _currentUserId;
    map['userUpvoted'] = map['upvotedUsers'] is List &&
        ((map['upvotedUsers'] as List).contains(userIdVal) || (map['upvotedUsers'] as List).contains(userIdStr));
    map['userDownvoted'] = map['downvotedUsers'] is List &&
        ((map['downvotedUsers'] as List).contains(userIdVal) || (map['downvotedUsers'] as List).contains(userIdStr));
    return Question.fromMap(map);
  }

  Comment _parseCommentFromSocket(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    final userIdVal = int.tryParse(_currentUserId ?? '');
    final userIdStr = _currentUserId;
    map['userUpvoted'] = map['upvotedUsers'] is List &&
        ((map['upvotedUsers'] as List).contains(userIdVal) || (map['upvotedUsers'] as List).contains(userIdStr));
    map['userDownvoted'] = map['downvotedUsers'] is List &&
        ((map['downvotedUsers'] as List).contains(userIdVal) || (map['downvotedUsers'] as List).contains(userIdStr));
    
    if (map['replies'] is List) {
      map['replies'] = (map['replies'] as List).map((r) {
        final rMap = Map<String, dynamic>.from(r);
        rMap['userUpvoted'] = rMap['upvotedUsers'] is List &&
            ((rMap['upvotedUsers'] as List).contains(userIdVal) || (rMap['upvotedUsers'] as List).contains(userIdStr));
        rMap['userDownvoted'] = rMap['downvotedUsers'] is List &&
            ((rMap['downvotedUsers'] as List).contains(userIdVal) || (rMap['downvotedUsers'] as List).contains(userIdStr));
        return rMap;
      }).toList();
    }
    return Comment.fromMap(map);
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
