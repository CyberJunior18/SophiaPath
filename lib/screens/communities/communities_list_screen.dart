import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/social/community.dart';
import '../../models/social/question.dart';
import '../../services/social_service.dart';
import '../../services/user_preferences_services.dart';
import '../../models/user/user.dart';
import '../../services/chat/chat_service.dart';
import '../../models/chat/chat_session_user.dart';
import 'community_detail_screen.dart';
import 'category_styles.dart';
import '../../services/local_social_storage.dart';
import 'question_detail_screen.dart';

class CommunitiesListScreen extends StatefulWidget {
  const CommunitiesListScreen({super.key});

  @override
  State<CommunitiesListScreen> createState() => _CommunitiesListScreenState();
}

class _CommunitiesListScreenState extends State<CommunitiesListScreen> with SingleTickerProviderStateMixin {
  final SocialService _socialService = SocialService();
  final UserPreferencesService _userService = UserPreferencesService.instance;

  User? _currentUser;
  ChatSessionUser? _chatSessionUser;
  List<Community> _communities = [];
  List<Question> _savedQuestions = [];
  bool _isLoading = true;
  late TabController _tabController;
  String _searchQuery = '';

  // Modals state
  bool _openCreate = false;
  String _name = '';
  String _description = '';
  String _icon = '⭐';
  String _category = 'Software Engineering';

  Community? _rulesCommunity;
  bool _rulesAccepted = false;
  bool _rulesDialogOpen = false;

  Community? _nsfwCommunityToJoin;
  bool _openAgeWarning = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await _userService.getUser();
      if (_currentUser != null) {
        String? userId = await _userService.getUserId();
        if (userId == null || userId.isEmpty) {
          try {
            _chatSessionUser = await ChatService().getCurrentUser();
            userId = _chatSessionUser!.userId.toString();
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('user_id', userId);
          } catch (_) {}
        } else {
          try {
            _chatSessionUser = await ChatService().getCurrentUser();
          } catch (_) {}
        }

        if (userId != null && userId.isNotEmpty) {
          final communities = await _socialService.getCommunities(userId);
          
          // Load saved posts from local storage
          final savedIds = await LocalSocialStorage.instance.getSavedPosts();
          final List<Question> savedQuestions = [];
          if (savedIds.isNotEmpty) {
            final futures = savedIds.map((id) => _socialService.getQuestionById(id, userId!));
            final results = await Future.wait(futures);
            for (final q in results) {
              if (q != null) {
                savedQuestions.add(q);
              }
            }
          }

          if (mounted) {
            setState(() {
              _communities = communities;
              _savedQuestions = savedQuestions;
            });
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleToggleJoin(Community community) async {
    if (_currentUser == null) return;
    final userId = _chatSessionUser?.userId.toString() ?? await _userService.getUserId() ?? '';
    if (userId.isEmpty) return;

    if (community.isJoined) {
      // Leave logic
      final success = await _socialService.toggleJoinCommunity(community.id, userId);
      if (success) _loadData();
    } else {
      // Check NSFW
      if (community.isNSFW) {
        setState(() {
          _nsfwCommunityToJoin = community;
          _openAgeWarning = true;
        });
        return;
      }
      // Check Rules
      if (community.rules.isNotEmpty) {
        setState(() {
          _rulesCommunity = community;
          _rulesAccepted = false;
          _rulesDialogOpen = true;
        });
        return;
      }
      
      // Join
      final success = await _socialService.toggleJoinCommunity(community.id, userId);
      if (success) _loadData();
    }
  }

  Future<void> _handleRulesJoinSubmit() async {
    if (_rulesCommunity == null || !_rulesAccepted || _currentUser == null) return;
    final userId = _chatSessionUser?.userId.toString() ?? await _userService.getUserId() ?? '';
    if (userId.isEmpty) return;

    try {
      await _socialService.toggleJoinCommunity(_rulesCommunity!.id, userId);
      setState(() {
        _rulesDialogOpen = false;
        _rulesCommunity = null;
        _rulesAccepted = false;
      });
      _loadData();
    } catch (e) {
      // handle error
    }
  }

  Future<void> _handleCreateSubmit() async {
    if (_name.trim().isEmpty) return;
    final userId = _chatSessionUser?.userId.toString() ?? await _userService.getUserId() ?? '';
    if (userId.isEmpty) return;

    try {
      final success = await _socialService.createCommunity(
        name: _name,
        description: _description,
        icon: _icon,
        category: _category,
        ownerId: userId,
        isPrivate: false,
        isNSFW: false,
        rules: [],
      );
      
      if (success) {
        setState(() {
          _name = '';
          _description = '';
          _icon = '⭐';
          _category = 'Software Engineering';
          _openCreate = false;
        });
        _loadData();
      }
    } catch (e) {
      // handle error
    }
  }

  Widget _buildCommunityCard(Community community) {
    final theme = Theme.of(context);
    final catStyle = categoryStyles[community.category] ?? categoryStyles['Software Engineering']!;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => CommunityDetailScreen(community: community)),
          ).then((_) => _loadData());
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner gradient (mock color based on web logic)
              Container(
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      catStyle.color.withOpacity(0.6),
                      catStyle.color.withOpacity(0.9)
                    ],
                  ),
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      bottom: -24,
                      left: 16,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: Center(
                          child: Text(community.icon, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, top: 32, bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      community.name,
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      community.description,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: theme.textTheme.bodyMedium!.color!.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: catStyle.bg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(catStyle.icon, style: const TextStyle(fontSize: 12)),
                              const SizedBox(width: 4),
                              Text(
                                community.category,
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: catStyle.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.dividerColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.dividerColor.withOpacity(0.2)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                community.isPrivate ? '🔒 Private' : '🌐 Public',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textTheme.bodySmall!.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (community.isNSFW)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '⚠️ ${community.nsfwAgeLimit ?? 18}+ NSFW',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Divider(color: theme.dividerColor.withOpacity(0.1)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.people, size: 18, color: theme.colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              '${community.membersCount} members',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _handleToggleJoin(community),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: community.isJoined ? theme.colorScheme.error.withOpacity(0.1) : theme.colorScheme.primary,
                            foregroundColor: community.isJoined ? theme.colorScheme.error : theme.colorScheme.onPrimary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: Icon(community.isJoined ? Icons.exit_to_app : Icons.login, size: 16),
                          label: Text(
                            community.isJoined ? 'Leave' : 'Join',
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSavedQuestionCard(Question question) {
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
              builder: (context) => QuestionDetailScreen(question: question),
            ),
          ).then((_) => _loadData());
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
                  color: theme.textTheme.bodyLarge!.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                question.content,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: theme.textTheme.bodyMedium!.color!.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: theme.colorScheme.secondaryContainer,
                    backgroundImage: question.authorAvatar.isNotEmpty ? NetworkImage(question.authorAvatar) : null,
                    child: question.authorAvatar.isEmpty
                        ? Text(
                            question.authorName.isNotEmpty ? question.authorName[0].toUpperCase() : 'U',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSecondaryContainer),
                          )
                        : null,
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

  void _showCreateDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Create Learning Community',
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: 'Community Name',
                      hintText: 'e.g. Software Architecture',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setModalState(() => _name = val),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'What is this community\'s learning focus?',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onChanged: (val) => setModalState(() => _description = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _category,
                    decoration: InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: communityCategories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins())))
                        .toList(),
                    onChanged: (val) => setModalState(() => _category = val!),
                  ),
                  const SizedBox(height: 16),
                  Text('Select Community Icon:', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: ['⭐', '🌟', '🏫', '📚', '🎯', '🔥'].map((emoji) {
                      return ChoiceChip(
                        label: Text(emoji, style: const TextStyle(fontSize: 20)),
                        selected: _icon == emoji,
                        onSelected: (selected) {
                          if (selected) setModalState(() => _icon = emoji);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _name.trim().isNotEmpty
                          ? () {
                              Navigator.pop(context);
                              _handleCreateSubmit();
                            }
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('Create Community', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    final filtered = _communities.where((c) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return c.name.toLowerCase().contains(q) || c.description.toLowerCase().contains(q);
    }).toList();

    final myCommunities = filtered.where((c) => c.isJoined).toList();
    final discoverCommunities = filtered.where((c) => !c.isJoined && !c.isPrivate).toList();
    final privateCommunities = filtered.where((c) => c.isPrivate).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: Text(
          'Communities',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 24),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(110),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search communities...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showCreateDialog,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 4,
                        shadowColor: theme.colorScheme.primary.withOpacity(0.5),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Create', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                unselectedLabelStyle: GoogleFonts.poppins(),
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(text: 'My Communities'),
                  Tab(text: 'Discover'),
                  Tab(text: 'Saved Posts'),
                  Tab(text: 'Private (Test)'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  myCommunities.isEmpty
                      ? Center(child: Text("You haven't joined any communities yet.", style: GoogleFonts.poppins(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: myCommunities.length,
                          itemBuilder: (ctx, i) => _buildCommunityCard(myCommunities[i]),
                        ),
                  discoverCommunities.isEmpty
                      ? Center(child: Text("No communities to discover.", style: GoogleFonts.poppins(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: discoverCommunities.length,
                          itemBuilder: (ctx, i) => _buildCommunityCard(discoverCommunities[i]),
                        ),
                  _savedQuestions.isEmpty
                      ? Center(child: Text("You haven't saved any posts yet.", style: GoogleFonts.poppins(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: _savedQuestions.length,
                          itemBuilder: (ctx, i) => _buildSavedQuestionCard(_savedQuestions[i]),
                        ),
                  privateCommunities.isEmpty
                      ? Center(child: Text("No private communities found.", style: GoogleFonts.poppins(color: Colors.grey)))
                      : ListView.builder(
                          itemCount: privateCommunities.length,
                          itemBuilder: (ctx, i) => _buildCommunityCard(privateCommunities[i]),
                        ),
                ],
              ),
          
          // Modals logic rendered as overlays
          if (_rulesDialogOpen && _rulesCommunity != null)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('📄 Community Rules', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        Text('Please read and agree to follow the rules of ${_rulesCommunity!.name} before joining.', style: GoogleFonts.poppins()),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(8),
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _rulesCommunity!.rules.asMap().entries.map((e) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text('${e.key + 1}. ${e.value}', style: GoogleFonts.poppins(fontSize: 14)),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Checkbox(
                              value: _rulesAccepted,
                              onChanged: (val) {
                                setState(() => _rulesAccepted = val ?? false);
                              },
                            ),
                            const Text('I agree to follow these rules'),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _rulesDialogOpen = false;
                                  _rulesCommunity = null;
                                  _rulesAccepted = false;
                                });
                              },
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: _rulesAccepted ? _handleRulesJoinSubmit : null,
                              child: const Text('Agree & Join'),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_openAgeWarning && _nsfwCommunityToJoin != null)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(24),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('⚠️ 18+ NSFW Content Check', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)),
                        const SizedBox(height: 16),
                        Text('This community contains adult content. Please confirm you are at least 18 years old to join.', style: GoogleFonts.poppins(), textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _openAgeWarning = false;
                                  _nsfwCommunityToJoin = null;
                                });
                              },
                              child: const Text('Go Back'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                              onPressed: () async {
                                final comm = _nsfwCommunityToJoin!;
                                setState(() {
                                  _openAgeWarning = false;
                                  _nsfwCommunityToJoin = null;
                                });
                                if (comm.rules.isNotEmpty) {
                                  setState(() {
                                    _rulesCommunity = comm;
                                    _rulesAccepted = false;
                                    _rulesDialogOpen = true;
                                  });
                                } else {
                                  final userId = _chatSessionUser?.userId.toString() ?? await _userService.getUserId() ?? '';
                                  if (userId.isNotEmpty) {
                                    await _socialService.toggleJoinCommunity(comm.id, userId);
                                    _loadData();
                                  }
                                }
                              },
                              child: const Text('I am 18+'),
                            )
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
