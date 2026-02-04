import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ChatService extends ChangeNotifier {
  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Chat> _chats = [];
  List<Chat> get chats => _chats;

  /// Load chats for the current user
  Future<void> loadChats(String currentUsername) async {
    final snapshot = await _firestore
        .collection('chats')
        .where('participants', arrayContains: currentUsername)
        .orderBy('lastUpdated', descending: true)
        .get();

    _chats = snapshot.docs.map((doc) {
      final data = doc.data();
      final participants = List<String>.from(data['participants'] ?? []);
      final otherUsername = participants.firstWhere(
        (u) => u != currentUsername,
        orElse: () => '',
      );
      return Chat(
        chatId: doc.id,
        otherUsername: otherUsername,
        lastMessage: data['lastMessage'] ?? '',
      );
    }).toList();

    notifyListeners();
  }

  /// Create a new chat (or return existing chat ID)
  Future<String> createChat({
    required String senderUsername,
    required String receiverUsername,
  }) async {
    // Check if chat already exists
    final query = await _firestore
        .collection('chats')
        .where('participants', arrayContainsAny: [senderUsername, receiverUsername])
        .get();

    for (var doc in query.docs) {
      final participants = List<String>.from(doc['participants'] ?? []);
      if (participants.contains(senderUsername) &&
          participants.contains(receiverUsername)) {
        return doc.id; // chat exists
      }
    }

    // Create new chat
    final docRef = await _firestore.collection('chats').add({
      'participants': [senderUsername, receiverUsername],
      'lastMessage': '',
      'lastUpdated': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Update local chats list
    _chats.insert(
      0,
      Chat(
        chatId: docRef.id,
        otherUsername: receiverUsername,
        lastMessage: '',
      ),
    );
    notifyListeners();

    return docRef.id;
  }

  /// Send a message in a chat
  Future<void> sendMessage({
    required String chatId,
    required String senderUsername,
    required String content,
  }) async {
    final messagesRef =
        _firestore.collection('chats').doc(chatId).collection('messages');

    await messagesRef.add({
      'sender': senderUsername,
      'content': content,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update last message in chat
    await _firestore.collection('chats').doc(chatId).update({
      'lastMessage': content,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Update local list
    final chatIndex = _chats.indexWhere((c) => c.chatId == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex].lastMessage = content;
      notifyListeners();
    }
  }

  /// Stream messages in a chat
  Stream<QuerySnapshot<Map<String, dynamic>>> getMessagesStream(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
}

class Chat {
  final String chatId;
  final String otherUsername;
  String lastMessage;

  Chat({
    required this.chatId,
    required this.otherUsername,
    required this.lastMessage,
  });
}