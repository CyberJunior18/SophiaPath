import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:sophia_path/models/chat/chat_message.dart';
import 'package:sophia_path/models/chat/chat_contact.dart';

class ChatService {
  static ChatService? _instance;

  factory ChatService() => _instance ??= ChatService._();
  ChatService._();

  Future<SharedPreferences> get _prefs async =>
      await SharedPreferences.getInstance();

  // Contacts Management
  Future<void> saveContact(ChatContact contact) async {
    final prefs = await _prefs;
    final contactsJson = prefs.getString('chat_contacts') ?? '[]';
    final contacts = jsonDecode(contactsJson) as List;

    // Remove existing contact if exists
    contacts.removeWhere((c) => c['userId'] == contact.userId);

    contacts.add(contact.toMap());

    await prefs.setString('chat_contacts', jsonEncode(contacts));
  }

  Future<List<ChatContact>> getContacts() async {
    final prefs = await _prefs;
    final contactsJson = prefs.getString('chat_contacts') ?? '[]';
    final contacts = jsonDecode(contactsJson) as List;

    return contacts.map((c) => ChatContact.fromMap(c)).toList();
  }

  // Messages Management
  Future<void> saveMessage(String chatId, ChatMessage message) async {
    final prefs = await _prefs;
    final key = 'chat_messages_$chatId';
    final messagesJson = prefs.getString(key) ?? '[]';
    final messages = jsonDecode(messagesJson) as List;

    messages.add(message.toMap());

    await prefs.setString(key, jsonEncode(messages));

    // Update contact's last message
    // Find the contact for this chat
    final contact = await getContactByChatId(chatId);
    if (contact != null) {
      await saveContact(
        contact.copyWith(
          lastMessageTime: message.timestamp,
          lastMessage: message.message,
          unreadCount: message.senderId != await _getCurrentUserId()
              ? contact.unreadCount + 1
              : contact.unreadCount,
        ),
      );
    }
  }

  Future<List<ChatMessage>> getMessages(String chatId) async {
    final prefs = await _prefs;
    final key = 'chat_messages_$chatId';
    final messagesJson = prefs.getString(key) ?? '[]';
    final messages = jsonDecode(messagesJson) as List;

    return messages.map((m) => ChatMessage.fromMap(m)).toList();
  }

  // Helper methods
  Future<ChatContact?> getContactByUserId(String userId) async {
    final contacts = await getContacts();
    for (final contact in contacts) {
      if (contact.userId == userId) return contact;
    }
    return null;
  }

  Future<String> _getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_user_id') ?? _getCurrentUserFromPrefs();
  }

  String _getCurrentUserFromPrefs() {
    // Or get from your UserPreferencesService
    return 'current_user'; // Temporary
  }

  Future<void> markMessagesAsRead(String chatId) async {
    final messages = await getMessages(chatId);
    final updatedMessages = messages
        .map((msg) => msg.copyWith(isRead: true))
        .toList();

    final prefs = await _prefs;
    final key = 'chat_messages_$chatId';
    await prefs.setString(
      key,
      jsonEncode(updatedMessages.map((m) => m.toMap()).toList()),
    );

    // Also update contact unread count to 0
    final contact = await getContactByChatId(chatId);
    if (contact != null) {
      await saveContact(contact.copyWith(unreadCount: 0));
    }
  }

  Future<void> clearChatHistory(String chatId) async {
    final prefs = await _prefs;
    await prefs.remove('chat_messages_$chatId');
  }

  // Get contact by chat ID
  Future<ChatContact?> getContactByChatId(String chatId) async {
    final contacts = await getContacts();
    for (final contact in contacts) {
      if (contact.chatId == chatId) {
        return contact;
      }
    }
    return null;
  }

  // Create new chat
  Future<String> createChat(String otherUserId) async {
    final chatId = 'chat_${await _getCurrentUserId()}_$otherUserId';

    final contact = ChatContact(
      userId: otherUserId,
      chatId: chatId,
      lastMessageTime: DateTime.now(),
      lastMessage: 'Chat started',
      unreadCount: 0,
    );

    await saveContact(contact);
    return chatId;
  }

  // Delete contact
  Future<void> deleteContact(String userId) async {
    final prefs = await _prefs;
    final contactsJson = prefs.getString('chat_contacts') ?? '[]';
    final contacts = jsonDecode(contactsJson) as List;

    contacts.removeWhere((c) => c['userId'] == userId);

    await prefs.setString('chat_contacts', jsonEncode(contacts));
  }

  // Get unread count
  Future<int> getTotalUnreadCount() async {
    final contacts = await getContacts();
    int total = 0;
    for (final contact in contacts) {
      total += contact.unreadCount;
    }
    return total;
  }

  // Mark contact as read
  Future<void> markContactAsRead(String chatId) async {
    final contact = await getContactByChatId(chatId);
    if (contact != null) {
      await saveContact(contact.copyWith(unreadCount: 0));
    }
  }

  Future<void> setTypingStatus(
    String chatId,
    bool isTyping,
    String userId,
  ) async {
    final prefs = await _prefs;
    await prefs.setString('typing_$chatId', isTyping ? userId : '');
  }

  Future<String?> getTypingStatus(String chatId) async {
    final prefs = await _prefs;
    return prefs.getString('typing_$chatId');
  }

  Future<void> addMessageReaction(
    String chatId,
    String messageId,
    String emoji,
    String userId,
  ) async {
    final messages = await getMessages(chatId);
    final messageIndex = messages.indexWhere((msg) => msg.id == messageId);

    if (messageIndex != -1) {
      final message = messages[messageIndex];
      final updatedReactions = Map<String, String>.from(message.reactions);
      updatedReactions[userId] = emoji;

      final updatedMessage = message.copyWith(reactions: updatedReactions);
      messages[messageIndex] = updatedMessage;

      final prefs = await _prefs;
      final key = 'chat_messages_$chatId';
      await prefs.setString(
        key,
        jsonEncode(messages.map((m) => m.toMap()).toList()),
      );
    }
  }
}
