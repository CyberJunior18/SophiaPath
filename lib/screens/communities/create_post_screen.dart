import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/social_service.dart';

class CreatePostScreen extends StatefulWidget {
  final String roomId;
  final String authorId;
  final String authorName;
  final String authorAvatar;

  const CreatePostScreen({
    super.key,
    required this.roomId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final SocialService _socialService = SocialService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  bool _isPollEnabled = false;
  final TextEditingController _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(text: 'Option 1'),
    TextEditingController(text: 'Option 2'),
  ];

  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _pollQuestionController.dispose();
    for (final controller in _pollOptionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addPollOption() {
    if (_pollOptionControllers.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can add up to 10 options')),
      );
      return;
    }
    setState(() {
      _pollOptionControllers.add(
        TextEditingController(text: 'Option ${_pollOptionControllers.length + 1}'),
      );
    });
  }

  void _removePollOption(int index) {
    if (_pollOptionControllers.length <= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A poll must have at least 2 options')),
      );
      return;
    }
    setState(() {
      final controller = _pollOptionControllers.removeAt(index);
      controller.dispose();
    });
  }

  Future<void> _submitPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();

      String? pollQuestion;
      List<String>? pollOptions;

      if (_isPollEnabled) {
        pollQuestion = _pollQuestionController.text.trim();
        pollOptions = _pollOptionControllers
            .map((c) => c.text.trim())
            .where((opt) => opt.isNotEmpty)
            .toList();
      }

      final success = await _socialService.createQuestion(
        roomId: widget.roomId,
        title: title,
        content: content,
        authorId: widget.authorId,
        authorName: widget.authorName,
        authorAvatar: widget.authorAvatar,
        pollQuestion: pollQuestion,
        pollOptions: pollOptions,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        if (success) {
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to publish post. Ensure you are a member of this community.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: isDark ? theme.colorScheme.surfaceContainer : theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        title: Text(
          'Create Post',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: _isSubmitting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : ElevatedButton(
                    onPressed: _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      elevation: 0,
                    ),
                    child: Text(
                      'Post',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                    ),
                  ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title Field
                TextFormField(
                  controller: _titleController,
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.bodyLarge?.color,
                  ),
                  decoration: InputDecoration(
                    hintText: 'An interesting title...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const Divider(),
                const SizedBox(height: 12),
                
                // Content Field
                TextFormField(
                  controller: _contentController,
                  maxLines: 8,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts, details, or questions here...',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      color: Colors.grey.withOpacity(0.7),
                    ),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    enabledBorder: InputBorder.none,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter some content';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                
                // Poll Switch Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: theme.dividerColor.withOpacity(0.15),
                    ),
                  ),
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        Icons.poll_outlined,
                        color: _isPollEnabled ? theme.colorScheme.primary : Colors.grey,
                      ),
                      title: Text(
                        'Add a Poll',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        'Create dynamic choices for members to vote',
                        style: GoogleFonts.poppins(fontSize: 12),
                      ),
                      value: _isPollEnabled,
                      onChanged: (val) {
                        setState(() {
                          _isPollEnabled = val;
                        });
                      },
                    ),
                  ),
                ),
                
                if (_isPollEnabled) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Poll Question',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _pollQuestionController,
                    style: GoogleFonts.poppins(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'e.g. Which programming language is best for ML?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    validator: (val) {
                      if (_isPollEnabled && (val == null || val.trim().isEmpty)) {
                        return 'Please enter a poll question';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Poll Choices',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _addPollOption,
                        icon: const Icon(Icons.add, size: 16),
                        label: Text(
                          'Add Option',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pollOptionControllers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _pollOptionControllers[index],
                              style: GoogleFonts.poppins(fontSize: 14),
                              decoration: InputDecoration(
                                hintText: 'Option ${index + 1}',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              validator: (val) {
                                if (_isPollEnabled && (val == null || val.trim().isEmpty)) {
                                  return 'Option cannot be empty';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _removePollOption(index),
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Remove Option',
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
