import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized local storage utility for social features.
/// Handles chat drafts, starred messages, saved posts, and other
/// local state that mirrors the web app's localStorage usage.
class LocalSocialStorage {
  static LocalSocialStorage? _instance;
  SharedPreferences? _prefs;

  LocalSocialStorage._();

  static LocalSocialStorage get instance {
    _instance ??= LocalSocialStorage._();
    return _instance!;
  }

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // --- CHAT DRAFTS ---

  /// Save a draft message for a specific conversation.
  /// Key format: draft_dm_{recipientId} or draft_group_{groupId}
  Future<void> saveDraft(String key, String text) async {
    final prefs = await _getPrefs();
    if (text.trim().isEmpty) {
      await prefs.remove('draft_$key');
    } else {
      await prefs.setString('draft_$key', text);
    }
  }

  Future<String?> getDraft(String key) async {
    final prefs = await _getPrefs();
    return prefs.getString('draft_$key');
  }

  Future<void> clearDraft(String key) async {
    final prefs = await _getPrefs();
    await prefs.remove('draft_$key');
  }

  // --- STARRED MESSAGES ---

  Future<List<String>> getStarredMessages(String conversationKey) async {
    final prefs = await _getPrefs();
    final raw = prefs.getString('starred_$conversationKey');
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  Future<void> toggleStarMessage(String conversationKey, String messageId) async {
    final starred = await getStarredMessages(conversationKey);
    if (starred.contains(messageId)) {
      starred.remove(messageId);
    } else {
      starred.add(messageId);
    }
    final prefs = await _getPrefs();
    await prefs.setString('starred_$conversationKey', jsonEncode(starred));
  }

  Future<bool> isMessageStarred(String conversationKey, String messageId) async {
    final starred = await getStarredMessages(conversationKey);
    return starred.contains(messageId);
  }

  // --- SAVED/BOOKMARKED POSTS ---

  Future<List<String>> getSavedPosts() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString('saved_posts_list');
    if (raw == null) return [];
    try {
      return List<String>.from(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  Future<bool> toggleSavePost(String postId) async {
    final saved = await getSavedPosts();
    final isSaved = saved.contains(postId);
    if (isSaved) {
      saved.remove(postId);
    } else {
      saved.add(postId);
    }
    final prefs = await _getPrefs();
    await prefs.setString('saved_posts_list', jsonEncode(saved));
    return !isSaved; // returns new saved state
  }

  Future<bool> isPostSaved(String postId) async {
    final saved = await getSavedPosts();
    return saved.contains(postId);
  }

  // --- LAST SEEN TIMESTAMPS ---

  Future<void> setLastSeen(String conversationKey, String timestamp) async {
    final prefs = await _getPrefs();
    await prefs.setString('last_seen_$conversationKey', timestamp);
  }

  Future<String?> getLastSeen(String conversationKey) async {
    final prefs = await _getPrefs();
    return prefs.getString('last_seen_$conversationKey');
  }
}
