import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/chat/chat_service.dart';
import '../../services/user_preferences_services.dart';
import 'chat_screen.dart';

class ChatsListScreen extends StatefulWidget {
  const ChatsListScreen({super.key});

  @override
  State<ChatsListScreen> createState() => _ChatsListScreenState();
}

class _ChatsListScreenState extends State<ChatsListScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  final UserPreferencesService _userService = UserPreferencesService.instance;
  final ChatService _chatService = ChatService();

  String? _currentUsername;
  List<Chat> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _userService.getUser();
    if (user?.username != null) {
      setState(() {
        _currentUsername = user!.username;
      });
      _loadChats();
    }
  }

  Future<void> _loadChats() async {
    if (_currentUsername == null) return;
    await _chatService.loadChats(_currentUsername!);
    setState(() {
      _chats = _chatService.chats;
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    final usersQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: query + '\uf8ff')
        .get();

    final results = usersQuery.docs
        .where((doc) => doc['username'] != _currentUsername) // exclude yourself
        .map((doc) {
      final data = doc.data();
      return {
        'username': data['username'] ?? '',
        'fullName': data['fullName'] ?? '',
        'profilePicture': data['profilePicture'] ?? '',
      };
    }).toList();

    setState(() {
      _searchResults = List<Map<String, dynamic>>.from(results);
      _isSearching = false;
    });
  }

  Future<void> _startChat(String otherUsername) async {
    if (_currentUsername == null) return;

    final chatId = await _chatService.createChat(
      senderUsername: _currentUsername!,
      receiverUsername: otherUsername,
    );

    // Navigate to ChatScreen
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          currentUser: _currentUsername!,
          chatUser: otherUsername,
          chatId: chatId,
        ),
      ),
    );

    // Clear search
    _searchController.clear();
    setState(() {
      _searchResults = [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Chats (${_currentUsername ?? 'Loading...'})'),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _searchUsers,
            ),
          ),

          if (_isSearching)
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_searchResults.isNotEmpty)
            // Show search results
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  return ListTile(
                    title: Text(user['username']),
                    subtitle: Text(user['fullName'] ?? ''),
                    leading: CircleAvatar(
                      backgroundImage: user['profilePicture'] != null &&
                              user['profilePicture'].isNotEmpty
                          ? NetworkImage(user['profilePicture'])
                          : null,
                      child: user['profilePicture'] == null ||
                              user['profilePicture'].isEmpty
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    onTap: () => _startChat(user['username']),
                  );
                },
              ),
            )
          else
            // Show existing chats
            Expanded(
              child: _currentUsername == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadChats,
                      child: _chats.isEmpty
                          ? const Center(
                              child: Text(
                                'No chats yet\nSearch users to start a conversation',
                                textAlign: TextAlign.center,
                              ),
                            )
                          : ListView.builder(
                              itemCount: _chats.length,
                              itemBuilder: (context, index) {
                                final chat = _chats[index];
                                return ListTile(
                                  title: Text(chat.otherUsername),
                                  subtitle: Text(
                                    chat.lastMessage.isNotEmpty
                                        ? chat.lastMessage
                                        : 'Start a conversation',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          currentUser: _currentUsername!,
                                          chatUser: chat.otherUsername,
                                          chatId: chat.chatId,
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
            ),
        ],
      ),
    );
  }
}