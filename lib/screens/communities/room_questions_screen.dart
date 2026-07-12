import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/social/community.dart';
import '../../models/social/question.dart';
import '../../services/social_service.dart';
import 'question_detail_screen.dart';
import '../../widgets/profileImage.dart';

class RoomQuestionsScreen extends StatefulWidget {
  final Community community;
  final Room room;
  const RoomQuestionsScreen({super.key, required this.community, required this.room});

  @override
  State<RoomQuestionsScreen> createState() => _RoomQuestionsScreenState();
}

class _RoomQuestionsScreenState extends State<RoomQuestionsScreen> {
  final SocialService _socialService = SocialService();
  List<Question> _questions = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final questions = await _socialService.getQuestions(widget.room.id, "1");
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
              builder: (context) => QuestionDetailScreen(community: widget.community, room: widget.room, question: question),
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
                  color: (theme.textTheme.bodyMedium?.color ?? theme.colorScheme.onSurface).withValues(alpha: 0.8),
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
                  Icon(Icons.thumb_up_alt_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${question.upvotes}', style: GoogleFonts.poppins(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(width: 16),
                  Icon(Icons.comment_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text('${question.commentsCount}', style: GoogleFonts.poppins(fontSize: 12, color: theme.colorScheme.onSurfaceVariant)),
                ],
              )
            ],
          ),
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarColor,
        foregroundColor: theme.colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '# ${widget.room.name}',
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              widget.community.name,
              style: GoogleFonts.poppins(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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
                  itemBuilder: (context, index) => _buildQuestionCard(_questions[index]),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Future: Ask a question
        },
        backgroundColor: theme.colorScheme.primary,
        child: Icon(Icons.edit, color: theme.colorScheme.onPrimary),
      ),
    );
  }
}
