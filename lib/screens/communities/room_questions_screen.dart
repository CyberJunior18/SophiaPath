import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/social/community.dart';
import '../../models/social/question.dart';
import '../../services/social_service.dart';
import '../../services/user_preferences_services.dart';
import '../../services/chat/chat_service.dart';
import '../../services/communities_socket_service.dart';
import 'question_detail_screen.dart';
import 'create_post_screen.dart';
import '../../widgets/profileImage.dart';

class RoomQuestionsScreen extends StatefulWidget {
  final Community community;
  final Room room;
  const RoomQuestionsScreen({
    super.key,
    required this.community,
    required this.room,
  });

  @override
  State<RoomQuestionsScreen> createState() => _RoomQuestionsScreenState();
}

class _RoomQuestionsScreenState extends State<RoomQuestionsScreen> {
  final SocialService _socialService = SocialService();
  List<Question> _questions = [];
  bool _isLoading = true;
  String? _currentUserId;
  String _currentUsername = 'User';
  String _currentUserAvatar = '';
  final List<StreamSubscription> _socketSubscriptions = [];

  @override
  void initState() {
    super.initState();
    _initUserAndLoad();
  }

  Future<void> _initUserAndLoad() async {
    try {
      final user = await ChatService().getCurrentUser();
      _currentUserId = user.userId.toString();
      _currentUsername = user.displayName;
      _currentUserAvatar = user.avatar ?? '';
    } catch (_) {
      final localUser = await UserPreferencesService.instance.getUser();
      if (localUser != null) {
        _currentUsername = localUser.fullName.isNotEmpty
            ? localUser.fullName
            : localUser.username;
        _currentUserAvatar = localUser.profileImage;
      }
      _currentUserId = await UserPreferencesService.instance.getUserId();
    }
    _loadQuestions();

    // Set up WebSocket listeners
    final userIdInt = int.tryParse(_currentUserId ?? '1') ?? 1;
    final socketService = CommunitiesSocketService();
    socketService.connect(userIdInt);

    final roomIdInt = int.tryParse(widget.room.id);
    if (roomIdInt != null) {
      socketService.joinRoom(roomIdInt);
    }

    _socketSubscriptions.add(
      socketService.onQuestionCreated.listen((data) {
        if (data['roomId'].toString() == widget.room.id) {
          final question = _parseQuestionFromSocket(data);
          setState(() {
            final idx = _questions.indexWhere((q) => q.id == question.id);
            if (idx == -1) {
              _questions.insert(0, question);
            }
          });
        }
      }),
    );

    _socketSubscriptions.add(
      socketService.onQuestionVoted.listen((data) {
        if (data['roomId'].toString() == widget.room.id) {
          final question = _parseQuestionFromSocket(data);
          setState(() {
            final idx = _questions.indexWhere((q) => q.id == question.id);
            if (idx != -1) {
              _questions[idx] = question;
            }
          });
        }
      }),
    );

    _socketSubscriptions.add(
      socketService.onQuestionUpdated.listen((data) {
        if (data['roomId'].toString() == widget.room.id) {
          final question = _parseQuestionFromSocket(data);
          setState(() {
            final idx = _questions.indexWhere((q) => q.id == question.id);
            if (idx != -1) {
              _questions[idx] = question;
            }
          });
        }
      }),
    );

    _socketSubscriptions.add(
      socketService.onQuestionDeleted.listen((data) {
        final qId = data['id'].toString();
        setState(() {
          _questions.removeWhere((q) => q.id == qId);
        });
      }),
    );
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await _socialService.getQuestions(
        widget.room.id,
        _currentUserId ?? "1",
      );
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildQuestionCard(Question question) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => QuestionDetailScreen(
                community: widget.community,
                room: widget.room,
                question: question,
              ),
            ),
          ).then((_) => _loadQuestions());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                question.title,
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                question.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color:
                      (theme.textTheme.bodyMedium?.color ??
                              theme.colorScheme.onSurface)
                          .withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ProfileImage(
                    imageUrl: question.authorAvatar,
                    radius: 12,
                    name: question.authorName,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    question.authorName,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${question.upvotes}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.comment_outlined,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${question.commentsCount}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var sub in _socketSubscriptions) {
      sub.cancel();
    }
    final roomIdInt = int.tryParse(widget.room.id);
    if (roomIdInt != null) {
      CommunitiesSocketService().leaveRoom(roomIdInt);
    }
    super.dispose();
  }

  Question _parseQuestionFromSocket(Map<String, dynamic> data) {
    final map = Map<String, dynamic>.from(data);
    final userIdVal = int.tryParse(_currentUserId ?? '');
    final userIdStr = _currentUserId;
    map['userUpvoted'] =
        map['upvotedUsers'] is List &&
        ((map['upvotedUsers'] as List).contains(userIdVal) ||
            (map['upvotedUsers'] as List).contains(userIdStr));
    map['userDownvoted'] =
        map['downvotedUsers'] is List &&
        ((map['downvotedUsers'] as List).contains(userIdVal) ||
            (map['downvotedUsers'] as List).contains(userIdStr));
    return Question.fromMap(map);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '# ${widget.room.name}',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.community.name,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _questions.isEmpty
          ? Center(
              child: Text(
                'No posts in this room yet.',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _questions.length,
              itemBuilder: (context, index) =>
                  _buildQuestionCard(_questions[index]),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (_currentUserId == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User details not loaded. Please try again.'),
              ),
            );
            return;
          }
          final result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => CreatePostScreen(
                roomId: widget.room.id,
                authorId: _currentUserId!,
                authorName: _currentUsername,
                authorAvatar: _currentUserAvatar,
              ),
            ),
          );
          if (result == true) {
            _loadQuestions();
          }
        },
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.edit, color: theme.colorScheme.onPrimary),
      ),
    );
  }
}
