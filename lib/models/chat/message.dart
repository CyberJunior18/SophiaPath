import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_im_list/models/message_model.dart';

// class ChatMessageModel extends MessageModel {
//   ChatMessageModel({
//     required super.id,
//     required super.content,
//     required super.ownerType,
//     required super.createdAt,
//     required super.avatar,
//     required super.ownerName,
//   });
// }

class Message {
  final String senderID;
  final String senderEmail;
  final String receiverID;
  final String message;
  final Timestamp timestamp;
  Message({
    required this.senderID,
    required this.senderEmail,
    required this.receiverID,
    required this.message,
    required this.timestamp,
  });
  Map<String, dynamic> toMap() {
    return {
      'senderID': senderID,
      'senderEmail': senderEmail,
      'receiverID': receiverID,
      'message': message,
      'timestamp': timestamp,
    };
  }
}
