import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../../models/chat/chat_message.dart';
import '../../models/chat/chat_session_user.dart';
import '../../screens/authentication/authService.dart';

class ChatService {
  ChatService({AuthService? authService})
    : _authService = authService ?? AuthService();

  final AuthService _authService;
  io.Socket? _socket;

  final StreamController<ChatMessage> _incomingMessagesController =
      StreamController<ChatMessage>.broadcast();
  final StreamController<String> _errorsController =
      StreamController<String>.broadcast();
  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  Stream<ChatMessage> get incomingMessages =>
      _incomingMessagesController.stream;
  Stream<String> get errors => _errorsController.stream;
  Stream<bool> get connectionChanges => _connectionController.stream;
  bool get isConnected => _socket?.connected == true;

  Future<ChatSessionUser> getCurrentUser() async {
    final profileResult = await _authService.getProfile();
    if (profileResult['success'] != true) {
      throw Exception(
        profileResult['message']?.toString() ?? 'Failed to load chat profile',
      );
    }

    final data = profileResult['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Chat profile payload is invalid');
    }

    return ChatSessionUser.fromMap(data);
  }

  Future<List<ChatMessage>> getConversationHistory(
    int userId1,
    int userId2,
  ) async {
    final url = Uri.parse(
      '${AuthService.baseUrl}/api/chat/conversation/$userId1/$userId2',
    );

    final response = await http.get(
      url,
      headers: const {'Content-Type': 'application/json'},
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString()
          : null;
      throw Exception(message ?? 'Failed to load conversation history');
    }

    final dynamic rawMessages = decoded is List
        ? decoded
        : decoded is Map<String, dynamic>
        ? (decoded['messages'] ?? decoded['data'] ?? decoded['items'])
        : null;

    if (rawMessages is! List) {
      return <ChatMessage>[];
    }

    return rawMessages
        .whereType<Map>()
        .map((item) => ChatMessage.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<int> getUnreadCount(int userId) async {
    final url = Uri.parse(
      '${AuthService.baseUrl}/api/chat/user/$userId/unread-count',
    );

    final response = await http.get(
      url,
      headers: const {'Content-Type': 'application/json'},
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200) {
      final message = decoded is Map<String, dynamic>
          ? decoded['message']?.toString()
          : null;
      throw Exception(message ?? 'Failed to load unread count');
    }

    if (decoded is Map<String, dynamic>) {
      final unreadCount = decoded['unreadCount'];
      if (unreadCount is int) return unreadCount;
      if (unreadCount is num) return unreadCount.toInt();
      if (unreadCount is String) return int.tryParse(unreadCount) ?? 0;
    }

    return 0;
  }

  Future<void> markConversationAsRead(int userId1, int userId2) async {
    final url = Uri.parse(
      '${AuthService.baseUrl}/api/chat/conversation/$userId1/$userId2/mark-read',
    );

    await http.post(url, headers: const {'Content-Type': 'application/json'});
  }

  Future<ChatMessage> sendMessage({
    required int senderId,
    required int recipientId,
    required String username,
    required String message,
    String? avatar,
  }) async {
    if (_socket?.connected == true) {
      final payload = <String, dynamic>{
        'recipientId': recipientId,
        'message': message,
        'username': username,
      };
      if (avatar != null) {
        payload['avatar'] = avatar;
      }

      _socket!.emit('sendMessage', payload);

      return ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}',
        senderId: senderId,
        senderUsername: username,
        recipientId: recipientId,
        message: message.trim(),
        timestamp: DateTime.now(),
        avatar: avatar,
        read: false,
      );
    }

    final url = Uri.parse('${AuthService.baseUrl}/api/chat/send-message');
    final payload = <String, dynamic>{
      'senderId': senderId,
      'recipientId': recipientId,
      'message': message,
      'username': username,
    };
    if (avatar != null) {
      payload['avatar'] = avatar;
    }

    final response = await http.post(
      url,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    final decoded = _decodeBody(response.body);
    if (response.statusCode != 200 && response.statusCode != 201) {
      final errorMessage = decoded is Map<String, dynamic>
          ? decoded['message']?.toString()
          : null;
      throw Exception(errorMessage ?? 'Failed to send chat message');
    }

    final dynamic rawMessage = decoded is Map<String, dynamic>
        ? (decoded['message'] ?? decoded['data'] ?? decoded)
        : decoded;

    if (rawMessage is Map) {
      return ChatMessage.fromMap(Map<String, dynamic>.from(rawMessage));
    }

    return ChatMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderUsername: username,
      recipientId: recipientId,
      message: message.trim(),
      timestamp: DateTime.now(),
      avatar: avatar,
      read: false,
    );
  }

  void connect(int userId) {
    disconnect();

    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setQuery({'userId': userId.toString()})
        .build();
    options['forceNew'] = true;

    _socket = io.io(AuthService.baseUrl, options);

    _socket!.onConnect((_) {
      _connectionController.add(true);
    });

    _socket!.onDisconnect((_) {
      _connectionController.add(false);
    });

    _socket!.onConnectError((error) {
      _errorsController.add('Socket connection failed: $error');
      _connectionController.add(false);
    });

    _socket!.on('newMessage', (data) => _emitIncomingMessage(data));
    _socket!.on('messageSent', (data) => _emitIncomingMessage(data));
    _socket!.on('messageError', (data) {
      final message = _readMessage(data) ?? 'Unable to send message';
      _errorsController.add(message);
    });
    _socket!.on('conversationStarted', (data) {
      debugPrint('Conversation started: $data');
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _incomingMessagesController.close();
    _errorsController.close();
    _connectionController.close();
  }

  void _emitIncomingMessage(dynamic data) {
    try {
      final message = _messageFromDynamic(data);
      if (message != null) {
        _incomingMessagesController.add(message);
      }
    } catch (error) {
      _errorsController.add('Failed to decode chat message: $error');
    }
  }

  ChatMessage? _messageFromDynamic(dynamic data) {
    if (data is Map<String, dynamic>) {
      return ChatMessage.fromMap(data);
    }

    if (data is Map) {
      return ChatMessage.fromMap(Map<String, dynamic>.from(data));
    }

    return null;
  }

  String? _readMessage(dynamic data) {
    if (data is String) return data;
    if (data is Map) {
      final message = data['error'] ?? data['message'];
      return message?.toString();
    }
    return null;
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

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    try {
      final token = await AuthStorage.getToken();
      final response = await http.get(
        Uri.parse('${AuthService.baseUrl}/users'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return List<Map<String, dynamic>>.from(
            data.map((u) => Map<String, dynamic>.from(u as Map)),
          );
        }
      }
      return [];
    } catch (error) {
      _errorsController.add('Failed to fetch users: $error');
      return [];
    }
  }
}
