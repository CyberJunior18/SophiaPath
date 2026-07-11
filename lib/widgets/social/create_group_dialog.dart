import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/social_service.dart';
import '../../services/chat/chat_service.dart';
import '../../models/chat/chat_session_user.dart';
import '../../models/user/user.dart';

class CreateGroupDialog extends StatefulWidget {
  final User currentUser;
  final ChatSessionUser chatSessionUser;
  final SocialService socialService;

  const CreateGroupDialog({
    super.key,
    required this.currentUser,
    required this.chatSessionUser,
    required this.socialService,
  });

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ChatService _chatService = ChatService();
  
  bool _isLoadingUsers = true;
  bool _isCreating = false;
  List<Map<String, dynamic>> _allUsers = [];
  final Set<String> _selectedMemberIds = {};

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    try {
      final users = await _chatService.getAllUsers();
      if (mounted) {
        setState(() {
          _allUsers = users.where((u) => u['username'] != widget.currentUser.username).toList();
          _isLoadingUsers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingUsers = false);
      }
    }
  }

  Future<void> _handleCreateGroup() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isCreating = true);

    final newGroup = await widget.socialService.createGroup(
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      memberIds: _selectedMemberIds.toList(),
      creatorId: widget.chatSessionUser.userId.toString(),
      creatorName: widget.chatSessionUser.displayName,
    );

    if (mounted) {
      setState(() => _isCreating = false);
      Navigator.pop(context, newGroup != null);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Create Group', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context, false),
                )
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Group Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Text('Select Members', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _isLoadingUsers
                ? const Center(child: CircularProgressIndicator())
                : Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _allUsers.isEmpty
                          ? const Center(child: Text('No users found'))
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _allUsers.length,
                              itemBuilder: (context, index) {
                                final user = _allUsers[index];
                                final userId = user['id']?.toString() ?? user['username'];
                                final name = user['fullname'] ?? user['username'] ?? 'Unknown';
                                final isSelected = _selectedMemberIds.contains(userId);

                                return CheckboxListTile(
                                  value: isSelected,
                                  title: Text(name, style: GoogleFonts.poppins()),
                                  onChanged: (bool? selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedMemberIds.add(userId);
                                      } else {
                                        _selectedMemberIds.remove(userId);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                    ),
                  ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isCreating || _nameController.text.trim().isEmpty ? null : _handleCreateGroup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isCreating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Create', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
