import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../screens/authentication/authService.dart';

class CommunitiesSocketService {
  static final CommunitiesSocketService _instance = CommunitiesSocketService._internal();
  factory CommunitiesSocketService() => _instance;
  CommunitiesSocketService._internal();

  io.Socket? _socket;

  // StreamControllers
  final _questionCreatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _questionVotedController = StreamController<Map<String, dynamic>>.broadcast();
  final _questionUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _questionDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _commentAddedController = StreamController<Map<String, dynamic>>.broadcast();
  final _replyAddedController = StreamController<Map<String, dynamic>>.broadcast();
  final _commentVotedController = StreamController<Map<String, dynamic>>.broadcast();
  final _pollVotedController = StreamController<Map<String, dynamic>>.broadcast();
  final _commentUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _commentDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _replyUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _replyDeletedController = StreamController<Map<String, dynamic>>.broadcast();

  // Stream Getters
  Stream<Map<String, dynamic>> get onQuestionCreated => _questionCreatedController.stream;
  Stream<Map<String, dynamic>> get onQuestionVoted => _questionVotedController.stream;
  Stream<Map<String, dynamic>> get onQuestionUpdated => _questionUpdatedController.stream;
  Stream<Map<String, dynamic>> get onQuestionDeleted => _questionDeletedController.stream;
  Stream<Map<String, dynamic>> get onCommentAdded => _commentAddedController.stream;
  Stream<Map<String, dynamic>> get onReplyAdded => _replyAddedController.stream;
  Stream<Map<String, dynamic>> get onCommentVoted => _commentVotedController.stream;
  Stream<Map<String, dynamic>> get onPollVoted => _pollVotedController.stream;
  Stream<Map<String, dynamic>> get onCommentUpdated => _commentUpdatedController.stream;
  Stream<Map<String, dynamic>> get onCommentDeleted => _commentDeletedController.stream;
  Stream<Map<String, dynamic>> get onReplyUpdated => _replyUpdatedController.stream;
  Stream<Map<String, dynamic>> get onReplyDeleted => _replyDeletedController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect(int userId) {
    if (_socket != null && _socket!.connected) return;

    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setQuery({'userId': userId.toString()})
        .build();
    options['forceNew'] = true;

    _socket = io.io(AuthService.baseUrl, options);

    _socket!.onConnect((_) {
      debugPrint('Communities socket connected');
    });

    _socket!.onDisconnect((_) {
      debugPrint('Communities socket disconnected');
    });

    _socket!.onConnectError((err) {
      debugPrint('Communities socket connect error: $err');
    });

    // Register event listeners
    _socket!.on('question_created', (data) => _safeAdd(_questionCreatedController, data));
    _socket!.on('question_voted', (data) => _safeAdd(_questionVotedController, data));
    _socket!.on('question_updated', (data) => _safeAdd(_questionUpdatedController, data));
    _socket!.on('question_deleted', (data) => _safeAdd(_questionDeletedController, data));
    _socket!.on('comment_added', (data) => _safeAdd(_commentAddedController, data));
    _socket!.on('reply_added', (data) => _safeAdd(_replyAddedController, data));
    _socket!.on('comment_voted', (data) => _safeAdd(_commentVotedController, data));
    _socket!.on('poll_voted', (data) => _safeAdd(_pollVotedController, data));
    _socket!.on('comment_updated', (data) => _safeAdd(_commentUpdatedController, data));
    _socket!.on('comment_deleted', (data) => _safeAdd(_commentDeletedController, data));
    _socket!.on('reply_updated', (data) => _safeAdd(_replyUpdatedController, data));
    _socket!.on('reply_deleted', (data) => _safeAdd(_replyDeletedController, data));

    _socket!.connect();
  }

  void _safeAdd(StreamController<Map<String, dynamic>> controller, dynamic data) {
    try {
      if (data is Map) {
        controller.add(Map<String, dynamic>.from(data));
      }
    } catch (e) {
      debugPrint('Error parsing socket event data: $e');
    }
  }

  void joinQuestionRoom(int questionId) {
    if (_socket?.connected == true) {
      _socket!.emit('joinQuestion', {'questionId': questionId});
    }
  }

  void leaveQuestionRoom(int questionId) {
    if (_socket?.connected == true) {
      _socket!.emit('leaveQuestion', {'questionId': questionId});
    }
  }

  void joinRoom(int roomId) {
    if (_socket?.connected == true) {
      _socket!.emit('joinRoom', {'roomId': roomId});
    }
  }

  void leaveRoom(int roomId) {
    if (_socket?.connected == true) {
      _socket!.emit('leaveRoom', {'roomId': roomId});
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
