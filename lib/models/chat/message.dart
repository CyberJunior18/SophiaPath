import 'package:flutter_im_list/models/message_model.dart';

class ChatMessageModel extends MessageModel {
  ChatMessageModel({
    required super.id,
    required super.content,
    required super.ownerType,
    required super.createdAt,
    required super.avatar,
    required super.ownerName,
  });
}