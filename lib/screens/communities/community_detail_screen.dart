import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/social/community.dart';
import '../../services/social_service.dart';
import '../../services/user_preferences_services.dart';
import '../../models/user/user.dart';
import '../../models/user/user_role.dart';
import 'room_questions_screen.dart';

class CommunityDetailScreen extends StatefulWidget {
  final Community community;
  const CommunityDetailScreen({super.key, required this.community});

  @override
  State<CommunityDetailScreen> createState() => _CommunityDetailScreenState();
}

class _CommunityDetailScreenState extends State<CommunityDetailScreen> {
  final SocialService _socialService = SocialService();
  final UserPreferencesService _userService = UserPreferencesService.instance;
  User? _currentUser;
  String? _currentUserId;
  List<Room> _rooms = [];
  bool _isLoadingRooms = true;
  late Community _community;

  @override
  void initState() {
    super.initState();
    _community = widget.community;
    _initData();
  }

  Future<void> _initData() async {
    _currentUser = await _userService.getUser();
    _currentUserId = await _userService.getUserId();
    _loadRooms();
  }

  Future<void> _loadRooms() async {
    setState(() => _isLoadingRooms = true);
    try {
      final rooms = await _socialService.getCommunityRooms(_community.id);
      if (mounted) {
        setState(() {
          _rooms = rooms;
          _isLoadingRooms = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingRooms = false);
    }
  }

  Future<void> _toggleJoin() async {
    if (_currentUserId == null) return;
    final success = await _socialService.toggleJoinCommunity(_community.id, _currentUserId!);
    if (success && mounted) {
      final updated = await _socialService.getCommunityById(_community.id, _currentUserId!);
      if (updated != null) {
        setState(() {
          _community = updated;
        });
      }
    }
  }

  bool get _isOwnerOrMod {
    if (_currentUserId == null) return false;
    final uid = _currentUserId!;
    final isGlobalAdminOrMod = _currentUser != null &&
        (_currentUser!.role == UserRole.admin || _currentUser!.role == UserRole.moderator);
    return _community.ownerId == uid ||
        _community.moderatorIds.contains(uid) ||
        isGlobalAdminOrMod;
  }

  bool get _isOwnerOrGlobalAdmin {
    if (_currentUserId == null) return false;
    final uid = _currentUserId!;
    final isGlobalAdmin = _currentUser != null && _currentUser!.role == UserRole.admin;
    return _community.ownerId == uid || isGlobalAdmin;
  }

  Future<void> _showCreateRoomDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Create New Room', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Room Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                if (name.isNotEmpty) {
                  final newRoom = await _socialService.createRoom(_community.id, name, desc);
                  if (newRoom != null && mounted) {
                    _loadRooms();
                    Navigator.pop(context);
                  }
                }
              },
              child: Text('Create', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showEditCommunityDialog() async {
    final nameController = TextEditingController(text: _community.name);
    final descController = TextEditingController(text: _community.description);
    final iconController = TextEditingController(text: _community.icon);
    final rulesController = TextEditingController(text: _community.rules.join('\n'));
    bool isPrivate = _community.isPrivate;
    bool isNSFW = _community.isNSFW;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Community', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descController,
                        decoration: InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: iconController,
                        decoration: InputDecoration(
                          labelText: 'Icon Emoji (e.g. ⭐)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: rulesController,
                        decoration: InputDecoration(
                          labelText: 'Rules (One per line)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        title: Text('Private Community', style: GoogleFonts.poppins(fontSize: 14)),
                        value: isPrivate,
                        onChanged: (val) => setDialogState(() => isPrivate = val),
                      ),
                      SwitchListTile(
                        title: Text('NSFW Content', style: GoogleFonts.poppins(fontSize: 14)),
                        value: isNSFW,
                        onChanged: (val) => setDialogState(() => isNSFW = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (_isOwnerOrGlobalAdmin)
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Delete Community', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                          content: Text('Are you sure you want to permanently delete this community? This action cannot be undone.', style: GoogleFonts.poppins()),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text('Cancel', style: GoogleFonts.poppins()),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                              onPressed: () => Navigator.pop(context, true),
                              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && mounted) {
                        final success = await _socialService.deleteCommunity(_community.id, _currentUserId!);
                        if (success && mounted) {
                          Navigator.pop(context); // Close edit dialog
                          Navigator.pop(context); // Go back to list
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Community deleted successfully')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to delete community')),
                          );
                        }
                      }
                    },
                    child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: GoogleFonts.poppins()),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final rules = rulesController.text
                        .split('\n')
                        .map((r) => r.trim())
                        .where((r) => r.isNotEmpty)
                        .toList();

                    final response = await _socialService.updateCommunity(
                      communityId: _community.id,
                      name: nameController.text.trim(),
                      description: descController.text.trim(),
                      icon: iconController.text.trim(),
                      isPrivate: isPrivate,
                      isNSFW: isNSFW,
                      rules: rules,
                    );

                    if (response != null && mounted) {
                      final updated = await _socialService.getCommunityById(_community.id, _currentUserId!);
                      if (updated != null && mounted) {
                        setState(() {
                          _community = updated;
                        });
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: Text('Save', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildRoomItem(Room room) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(Icons.tag, color: theme.colorScheme.primary),
      title: Text(
        room.name,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: theme.textTheme.bodyLarge!.color,
        ),
      ),
      subtitle: Text(
        room.description,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.poppins(
          fontSize: 12,
          color: theme.textTheme.bodySmall!.color,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RoomQuestionsScreen(community: _community, room: room),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      floatingActionButton: _isOwnerOrMod
          ? FloatingActionButton.extended(
              onPressed: _showCreateRoomDialog,
              icon: const Icon(Icons.add_home_work_outlined),
              label: Text('Create Room', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            )
          : null,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: theme.colorScheme.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primaryContainer,
                      theme.colorScheme.primary.withOpacity(0.5)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ]
                      ),
                      child: Center(
                        child: Text(_community.icon, style: const TextStyle(fontSize: 40)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _community.name,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_community.membersCount} members',
                      style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.9)),
                    )
                  ],
                ),
              ),
            ),
            actions: [
              if (_isOwnerOrMod)
                IconButton(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onPressed: _showEditCommunityDialog,
                  tooltip: 'Community Settings',
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ElevatedButton.icon(
                  onPressed: _toggleJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _community.isJoined ? Colors.white.withOpacity(0.2) : theme.colorScheme.primary,
                    foregroundColor: _community.isJoined ? Colors.white : theme.colorScheme.onPrimary,
                    elevation: 0,
                  ),
                  icon: Icon(_community.isJoined ? Icons.exit_to_app : Icons.login, size: 18),
                  label: Text(_community.isJoined ? 'Leave' : 'Join', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('About', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(_community.description, style: GoogleFonts.poppins(fontSize: 14)),
                  const SizedBox(height: 24),
                  if (_community.rules.isNotEmpty) ...[
                    Text('Rules', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _community.rules.asMap().entries.map((e) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text('${e.key + 1}. ${e.value}', style: GoogleFonts.poppins(fontSize: 14)),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  Text('Rooms', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (_isLoadingRooms)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_rooms.isEmpty)
            SliverFillRemaining(
              child: Center(child: Text('No rooms available.', style: GoogleFonts.poppins(color: Colors.grey)))
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: _buildRoomItem(_rooms[index]),
                  );
                },
                childCount: _rooms.length,
              ),
            ),
        ],
      ),
    );
  }
}
