import 'dart:convert';
import 'package:http/http.dart' as http;
import '../screens/authentication/authService.dart';
import '../models/social/group.dart';
import '../models/social/group_message.dart';
import '../models/social/community.dart';
import '../models/social/question.dart';
import '../models/social/comment.dart';

class SocialService {
  Future<String?> _getToken() async {
    return await AuthStorage.getToken();
  }

  Future<Map<String, String>> _getHeaders() async {
    final token = await _getToken();
    final headers = {'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  dynamic _decodeBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return null;
    try {
      return jsonDecode(trimmed);
    } catch (_) {
      return trimmed;
    }
  }

  // --- GROUPS ---

  Future<List<Group>> getGroups(String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/user/$userId');
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode != 200) return [];
      
      final data = _decodeBody(response.body);
      if (data is List) {
        return data.map((g) => Group.fromMap(g)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Group?> getGroupById(String groupId, {String? userId}) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/$groupId${userId != null ? '?userId=$userId' : ''}');
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode != 200) return null;

      final data = _decodeBody(response.body);
      if (data is Map<String, dynamic>) {
        return Group.fromMap(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Group?> createGroup({
    required String name,
    required String description,
    required List<String> memberIds,
    required String creatorId,
    required String creatorName,
  }) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/create');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'memberIds': memberIds.map((id) => int.tryParse(id) ?? id).toList(),
          'creatorId': int.tryParse(creatorId) ?? creatorId,
          'creatorName': creatorName,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeBody(response.body);
        if (data is Map<String, dynamic>) {
          return Group.fromMap(data['group'] ?? data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<GroupMessage>> getGroupMessages(String groupId, {String? userId}) async {
    // the web app returns the full group with messages array in getGroupById
    final group = await getGroupById(groupId, userId: userId);
    if (group != null) {
      // This is a workaround since getGroupById returns messages usually in the map, but our Group model doesn't store them 
      // directly. Let's make another call or just parse the messages from the getGroupById response directly here.
      try {
        final url = Uri.parse('${AuthService.baseUrl}/api/groups/$groupId${userId != null ? '?userId=$userId' : ''}');
        final response = await http.get(url, headers: await _getHeaders());
        if (response.statusCode == 200) {
          final data = _decodeBody(response.body);
          if (data is Map<String, dynamic> && data['messages'] is List) {
            return (data['messages'] as List).map((m) => GroupMessage.fromMap(m)).toList();
          }
        }
      } catch (e) {
        // fallthrough
      }
    }
    return [];
  }

  Future<GroupMessage?> sendGroupMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    required String senderAvatar,
    required String text,
    String? replyToId,
    String? replyToMessage,
    String? replyToUsername,
    bool? forwarded,
    String? pollQuestion,
    List<String>? pollOptions,
  }) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/$groupId/send-message');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'senderId': int.tryParse(senderId) ?? senderId,
          'senderName': senderName,
          'senderAvatar': senderAvatar,
          'text': text,
          if (replyToId != null) 'replyToId': replyToId,
          if (replyToMessage != null) 'replyToMessage': replyToMessage,
          if (replyToUsername != null) 'replyToUsername': replyToUsername,
          if (forwarded != null) 'forwarded': forwarded,
          if (pollQuestion != null) 'pollQuestion': pollQuestion,
          if (pollOptions != null) 'pollOptions': pollOptions,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeBody(response.body);
        if (data is Map<String, dynamic> && data['message'] != null) {
          return GroupMessage.fromMap(data['message']);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> pinGroupMessage(String messageId, bool pinned) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/messages/$messageId/pin');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'pinned': pinned}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteGroupMessage(String messageId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/messages/$messageId');
      final response = await http.delete(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Group?> makeGroupAdmin(String groupId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/$groupId/admins/add');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'adminId': int.tryParse(userId) ?? userId}),
      );
      if (response.statusCode == 200) {
        final data = _decodeBody(response.body);
        if (data is Map<String, dynamic>) {
          return Group.fromMap(data['group'] ?? data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Group?> removeGroupAdmin(String groupId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/$groupId/admins/remove');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'adminId': int.tryParse(userId) ?? userId}),
      );
      if (response.statusCode == 200) {
        final data = _decodeBody(response.body);
        if (data is Map<String, dynamic>) {
          return Group.fromMap(data['group'] ?? data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Group?> removeGroupMember(String groupId, String memberId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/$groupId/members/$memberId');
      final response = await http.delete(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = _decodeBody(response.body);
        if (data is Map<String, dynamic>) {
          return Group.fromMap(data['group'] ?? data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- COMMUNITIES ---

  Future<List<Community>> getCommunities(String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities?userId=$userId');
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode != 200) return [];
      
      final data = _decodeBody(response.body);
      if (data is List) {
        return data.map((c) {
          final isJoined = c['members'] is List && (c['members'] as List).any((m) => m['id'].toString() == userId);
          final map = Map<String, dynamic>.from(c);
          map['isJoined'] = isJoined;
          return Community.fromMap(map);
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Community?> getCommunityById(String communityId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/$communityId');
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode != 200) return null;

      final data = _decodeBody(response.body);
      if (data is Map<String, dynamic>) {
        final isJoined = data['members'] is List && (data['members'] as List).any((m) => m['id'].toString() == userId);
        final map = Map<String, dynamic>.from(data);
        map['isJoined'] = isJoined;
        return Community.fromMap(map);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Room>> getCommunityRooms(String communityId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/$communityId');
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = _decodeBody(response.body);
        if (data is Map<String, dynamic> && data['rooms'] is List) {
           return (data['rooms'] as List).map((r) => Room.fromMap(r)).toList();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> toggleJoinCommunity(String communityId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/$communityId/join');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> createCommunity({
    required String name,
    required String description,
    required String icon,
    required String category,
    required String ownerId,
    bool isPrivate = false,
    bool isNSFW = false,
    List<String> rules = const [],
  }) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/create');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'icon': icon,
          'category': category,
          'ownerId': int.tryParse(ownerId) ?? ownerId,
          'isPrivate': isPrivate,
          'isNSFW': isNSFW,
          'rules': rules,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- QUESTIONS & COMMENTS ---

  Future<List<Question>> getQuestions(String roomId, String userId, {String sortBy = 'hot'}) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/rooms/$roomId/questions?sortBy=$sortBy&userId=$userId');
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode != 200) return [];
      
      final data = _decodeBody(response.body);
      if (data is List) {
        return data.map((q) {
          final map = Map<String, dynamic>.from(q);
          map['userUpvoted'] = map['upvotedUsers'] is List && (map['upvotedUsers'] as List).contains(int.tryParse(userId) ?? userId);
          map['userDownvoted'] = map['downvotedUsers'] is List && (map['downvotedUsers'] as List).contains(int.tryParse(userId) ?? userId);
          return Question.fromMap(map);
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Question?> getQuestionById(String questionId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/questions/$questionId');
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode != 200) return null;

      final data = _decodeBody(response.body);
      if (data is Map<String, dynamic>) {
        final map = Map<String, dynamic>.from(data);
        map['userUpvoted'] = map['upvotedUsers'] is List && (map['upvotedUsers'] as List).contains(int.tryParse(userId) ?? userId);
        map['userDownvoted'] = map['downvotedUsers'] is List && (map['downvotedUsers'] as List).contains(int.tryParse(userId) ?? userId);
        return Question.fromMap(map);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<List<Comment>> getComments(String questionId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/questions/$questionId/comments');
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode != 200) return [];

      final data = _decodeBody(response.body);
      if (data is List) {
        return data.map((c) {
          final map = Map<String, dynamic>.from(c);
          map['userUpvoted'] = map['upvotedUsers'] is List && (map['upvotedUsers'] as List).contains(int.tryParse(userId) ?? userId);
          map['userDownvoted'] = map['downvotedUsers'] is List && (map['downvotedUsers'] as List).contains(int.tryParse(userId) ?? userId);
          
          if (map['replies'] is List) {
             map['replies'] = (map['replies'] as List).map((r) {
                final rMap = Map<String, dynamic>.from(r);
                rMap['userUpvoted'] = rMap['upvotedUsers'] is List && (rMap['upvotedUsers'] as List).contains(int.tryParse(userId) ?? userId);
                rMap['userDownvoted'] = rMap['downvotedUsers'] is List && (rMap['downvotedUsers'] as List).contains(int.tryParse(userId) ?? userId);
                return rMap;
             }).toList();
          }

          return Comment.fromMap(map);
        }).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> createQuestion({
    required String roomId,
    required String title,
    required String content,
    required String authorId,
    required String authorName,
    required String authorAvatar,
    String? pollQuestion,
    List<String>? pollOptions,
  }) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/rooms/$roomId/questions/create');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'title': title,
          'content': content,
          'authorId': int.tryParse(authorId) ?? authorId,
          'authorName': authorName,
          'authorAvatar': authorAvatar,
          if (pollQuestion != null) 'pollQuestion': pollQuestion,
          if (pollOptions != null) 'pollOptions': pollOptions,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addComment({
    required String questionId,
    required String content,
    required String authorId,
    required String authorName,
    required String authorAvatar,
  }) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/questions/$questionId/comments/create');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'content': content,
          'authorId': int.tryParse(authorId) ?? authorId,
          'authorName': authorName,
          'authorAvatar': authorAvatar,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  Future<bool> addReply({
    required String questionId,
    required String commentId,
    required String content,
    required String authorId,
    required String authorName,
    required String authorAvatar,
    String? parentReplyId,
  }) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/comments/$commentId/replies/create');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'content': content,
          'authorId': int.tryParse(authorId) ?? authorId,
          'authorName': authorName,
          'authorAvatar': authorAvatar,
          'parentReplyId': parentReplyId != null ? int.tryParse(parentReplyId) : null,
        }),
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      return false;
    }
  }

  // --- GROUP ADVANCED ---

  Future<Map<String, dynamic>?> editGroupMessage(String messageId, String text, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/message/$messageId/edit');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'text': text, 'userId': int.tryParse(userId) ?? userId}),
      );
      if (response.statusCode == 200) {
        final data = _decodeBody(response.body);
        if (data is Map<String, dynamic>) return data;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> setGroupTypingStatus(String groupId, String userId, String username, bool typing) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/$groupId/typing');
      await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': int.tryParse(userId) ?? userId,
          'username': username,
          'typing': typing,
        }),
      );
    } catch (_) {
      // Silently fail for typing indicators
    }
  }

  Future<List<Map<String, dynamic>>> getGroupTypingStatus(String groupId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/$groupId/typing');
      final response = await http.get(url, headers: await _getHeaders());
      if (response.statusCode == 200) {
        final data = _decodeBody(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(
            data.map((e) => Map<String, dynamic>.from(e as Map)),
          );
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> addGroupMembers(String groupId, List<String> memberIds) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/$groupId/add-members');
      final token = await _getToken();
      // Extract userId from token
      String? userId;
      if (token != null) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
            final map = jsonDecode(payload);
            userId = map['sub']?.toString();
          }
        } catch (_) {}
      }
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'memberIds': memberIds.map((id) => int.tryParse(id) ?? id).toList(),
          'userId': userId != null ? int.tryParse(userId) : null,
        }),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateGroupDetails(String groupId, String userId, Map<String, dynamic> updates) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/$groupId/update');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': int.tryParse(userId) ?? userId,
          'updates': updates,
        }),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> joinGroupByLink(String token, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/join-by-link/$token');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> voteGroupPoll(String messageId, int optionIndex, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/groups/message/$messageId/vote-poll');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': int.tryParse(userId) ?? userId,
          'optionIndex': optionIndex,
        }),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // --- COMMUNITY ADVANCED ---

  Future<Room?> createRoom(String communityId, String name, String description) async {
    try {
      final token = await _getToken();
      String? creatorId;
      if (token != null) {
        try {
          final parts = token.split('.');
          if (parts.length == 3) {
            final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
            final map = jsonDecode(payload);
            creatorId = map['sub']?.toString();
          }
        } catch (_) {}
      }
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/$communityId/create-room');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'name': name,
          'description': description,
          'creatorId': creatorId != null ? int.tryParse(creatorId) : null,
        }),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = _decodeBody(response.body);
        if (data is Map<String, dynamic>) {
          return Room.fromMap(data['room'] ?? data);
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> upvoteQuestion(String questionId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/questions/$questionId/upvote');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> downvoteQuestion(String questionId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/questions/$questionId/downvote');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> upvoteComment(String commentId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/comments/$commentId/upvote');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> downvoteComment(String commentId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/comments/$commentId/downvote');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateQuestion(String questionId, String title, String content, {String? pollQuestion, List<String>? pollOptions}) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/questions/$questionId/update');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'title': title,
          'content': content,
          'pollQuestion': pollQuestion,
          'pollOptions': pollOptions,
        }),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteQuestion(String questionId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/questions/$questionId/delete');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> updateComment(String commentId, String content) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/comments/$commentId/update');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'content': content}),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteComment(String commentId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/comments/$commentId/delete');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> updateReply(String replyId, String content) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/replies/$replyId/update');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'content': content}),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteReply(String replyId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/replies/$replyId/delete');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> approveQuestion(String questionId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/questions/$questionId/approve');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> addModerator(String communityId, String moderatorId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/$communityId/add-moderator');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'moderatorId': int.tryParse(moderatorId) ?? moderatorId}),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> removeModerator(String communityId, String moderatorId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/$communityId/remove-moderator');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'moderatorId': int.tryParse(moderatorId) ?? moderatorId}),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> updateCommunity({
    required String communityId,
    String? name,
    String? description,
    String? icon,
    bool? isPrivate,
    bool? isNSFW,
    List<String>? rules,
    String? category,
    int? maxMembers,
    int? nsfwAgeLimit,
    String? ownerId,
  }) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/$communityId/update');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (icon != null) 'icon': icon,
          if (isPrivate != null) 'isPrivate': isPrivate,
          if (isNSFW != null) 'isNSFW': isNSFW,
          if (rules != null) 'rules': rules,
          if (category != null) 'category': category,
          if (maxMembers != null) 'maxMembers': maxMembers,
          if (nsfwAgeLimit != null) 'nsfwAgeLimit': nsfwAgeLimit,
          if (ownerId != null) 'ownerId': ownerId,
        }),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteCommunity(String communityId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/$communityId/delete');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> votePostPoll(String postId, int optionIndex, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/questions/$postId/vote-poll');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({
          'userId': int.tryParse(userId) ?? userId,
          'optionIndex': optionIndex,
        }),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> joinCommunityByInvite(String communityId, String userId) async {
    try {
      final url = Uri.parse('${AuthService.baseUrl}/api/communities/$communityId/join-invite');
      final response = await http.post(
        url,
        headers: await _getHeaders(),
        body: jsonEncode({'userId': int.tryParse(userId) ?? userId}),
      );
      if (response.statusCode == 200) {
        return _decodeBody(response.body) as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

