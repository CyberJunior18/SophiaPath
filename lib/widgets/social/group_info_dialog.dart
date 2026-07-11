import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/social/group.dart';
import '../../services/social_service.dart';
import '../../services/chat/chat_service.dart';
import '../../models/chat/chat_session_user.dart';

class GroupInfoDialog extends StatefulWidget {
  final Group group;
  final ChatSessionUser chatSessionUser;
  final SocialService socialService;
  final VoidCallback onGroupUpdated;

  const GroupInfoDialog({
    super.key,
    required this.group,
    required this.chatSessionUser,
    required this.socialService,
    required this.onGroupUpdated,
  });

  @override
  State<GroupInfoDialog> createState() => _GroupInfoDialogState();
}

class _GroupInfoDialogState extends State<GroupInfoDialog> {
  late Group _group;
  final ChatService _chatService = ChatService();

  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _nameController = TextEditingController(text: _group.name);
    _descController = TextEditingController(text: _group.description);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isAdmin => _group.adminIds.contains(widget.chatSessionUser.userId.toString());

  Future<void> _handleRemoveMember(String memberId) async {
    final updated = await widget.socialService.removeGroupMember(_group.id, memberId);
    if (updated != null) {
      setState(() => _group = updated);
      widget.onGroupUpdated();
    }
  }

  Future<void> _handleToggleAdmin(String memberId) async {
    final isTargetAdmin = _group.adminIds.contains(memberId);
    Group? updated;
    if (isTargetAdmin) {
      updated = await widget.socialService.removeGroupAdmin(_group.id, memberId);
    } else {
      updated = await widget.socialService.makeGroupAdmin(_group.id, memberId);
    }
    if (updated != null) {
      setState(() => _group = updated!);
      widget.onGroupUpdated();
    }
  }

  Future<void> _saveGroupDetails() async {
    final updates = {
      'name': _nameController.text.trim(),
      'description': _descController.text.trim(),
    };
    final response = await widget.socialService.updateGroupDetails(
      _group.id,
      widget.chatSessionUser.userId.toString(),
      updates,
    );
    if (response != null && mounted) {
      setState(() {
        _group = Group.fromMap(response['group'] ?? response);
        _isEditing = false;
      });
      widget.onGroupUpdated();
    }
  }

  Future<void> _showAddMembersDialog() async {
    final users = await _chatService.getAllUsers();
    if (!mounted) return;

    // Filter out existing members
    final existingIds = _group.members.map((m) => m['id']?.toString()).toSet();
    final addableUsers = users.where((u) => !existingIds.contains(u['username']?.toString() ?? u['id']?.toString())).toList();

    if (addableUsers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All platform users are already members of this group.')),
      );
      return;
    }

    final selectedUserIds = <String>{};

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Add Members', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: addableUsers.length,
                  itemBuilder: (context, index) {
                    final u = addableUsers[index];
                    final username = u['username']?.toString() ?? u['id']?.toString() ?? '';
                    final fullName = u['fullName'] ?? u['fullname'] ?? u['name'] ?? username;
                    final isChecked = selectedUserIds.contains(username);

                    return CheckboxListTile(
                      title: Text(fullName, style: GoogleFonts.poppins()),
                      subtitle: Text(username, style: GoogleFonts.poppins(fontSize: 12)),
                      value: isChecked,
                      onChanged: (val) {
                        setDialogState(() {
                          if (val == true) {
                            selectedUserIds.add(username);
                          } else {
                            selectedUserIds.remove(username);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: selectedUserIds.isEmpty
                      ? null
                      : () async {
                          final response = await widget.socialService.addGroupMembers(
                            _group.id,
                            selectedUserIds.toList(),
                          );
                          if (response != null && mounted) {
                            setState(() {
                              _group = Group.fromMap(response['group'] ?? response);
                            });
                            widget.onGroupUpdated();
                            Navigator.pop(context);
                          }
                        },
                  child: Text('Add', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _copyInviteLink() {
    // Generate a simple group invite token/link
    final inviteLink = 'sophia-invite-group-${_group.id}';
    Clipboard.setData(ClipboardData(text: inviteLink));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group invite link copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 550),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Group Info', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 36,
                        backgroundImage: _group.avatar.isNotEmpty
                            ? NetworkImage(_group.avatar)
                            : null,
                        child: _group.avatar.isEmpty
                            ? const Icon(Icons.group, size: 36)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_isEditing) ...[
                      Center(
                        child: Text(_group.name, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      if (_group.description.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            _group.description,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
                          ),
                        ),
                      ],
                      if (_isAdmin) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: () => setState(() => _isEditing = true),
                            icon: const Icon(Icons.edit, size: 16),
                            label: Text('Edit Group Details', style: GoogleFonts.poppins(fontSize: 12)),
                          ),
                        ),
                      ]
                    ] else ...[
                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Group Name',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          labelStyle: GoogleFonts.poppins(fontSize: 13),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => setState(() => _isEditing = false),
                            child: Text('Cancel', style: GoogleFonts.poppins(fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _saveGroupDetails,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text('Save', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Quick Action Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _copyInviteLink,
                          icon: const Icon(Icons.link, size: 16),
                          label: Text('Invite Link', style: GoogleFonts.poppins(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        if (_isAdmin)
                          ElevatedButton.icon(
                            onPressed: _showAddMembersDialog,
                            icon: const Icon(Icons.add, size: 16),
                            label: Text('Add Members', style: GoogleFonts.poppins(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Members (${_group.members.length})', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 6),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _group.members.length,
                      itemBuilder: (context, index) {
                          final member = _group.members[index];
                          final isMemberAdmin = _group.adminIds.contains(member['id']?.toString());

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundImage: member['avatar'] != null && member['avatar'].toString().isNotEmpty
                                  ? NetworkImage(member['avatar'])
                                  : null,
                              child: member['avatar'] == null || member['avatar'].toString().isEmpty
                                  ? const Icon(Icons.person, size: 16)
                                  : null,
                            ),
                            title: Text(member['fullName'] ?? member['username'] ?? member['name'] ?? 'Unknown', style: GoogleFonts.poppins(fontSize: 13)),
                            subtitle: isMemberAdmin ? Text('Admin', style: GoogleFonts.poppins(color: Colors.blue, fontSize: 11)) : null,
                            trailing: _isAdmin && member['id']?.toString() != widget.chatSessionUser.userId.toString()
                                ? PopupMenuButton<String>(
                                    onSelected: (val) {
                                      if (val == 'admin') _handleToggleAdmin(member['id'].toString());
                                      if (val == 'remove') _handleRemoveMember(member['id'].toString());
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem(
                                        value: 'admin',
                                        child: Text(isMemberAdmin ? 'Remove Admin' : 'Make Admin', style: GoogleFonts.poppins(fontSize: 13)),
                                      ),
                                      PopupMenuItem(
                                        value: 'remove',
                                        child: Text('Remove from Group', style: GoogleFonts.poppins(fontSize: 13, color: Colors.red)),
                                      ),
                                    ],
                                  )
                                : null,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
