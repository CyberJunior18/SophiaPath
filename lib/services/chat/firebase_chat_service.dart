// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:sophia_path/models/chat/chat_message.dart';

// class FirebaseChatService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   // Get current user ID
//   String get currentUserId => _auth.currentUser?.uid ?? '';

//   // Get chat room reference
//   CollectionReference get chatRoomsCollection =>
//       _firestore.collection('chatRooms');

//   // Get messages subcollection for a chat room
//   CollectionReference getMessagesCollection(String chatRoomId) {
//     return chatRoomsCollection.doc(chatRoomId).collection('messages');
//   }

//   // Create or get existing chat room between two users
//   Future<String> getOrCreateChatRoom(String otherUserId) async {
//     final currentUserId = this.currentUserId;

//     if (currentUserId.isEmpty || otherUserId.isEmpty) {
//       throw Exception('User IDs cannot be empty');
//     }

//     // Create sorted room ID (alphabetical to ensure uniqueness)
//     final participants = [currentUserId, otherUserId]..sort();
//     final chatRoomId = participants.join('_');

//     // Check if room exists
//     final roomDoc = await chatRoomsCollection.doc(chatRoomId).get();

//     if (!roomDoc.exists) {
//       // Create new chat room
//       await chatRoomsCollection.doc(chatRoomId).set({
//         'participants': participants,
//         'createdAt': FieldValue.serverTimestamp(),
//         'lastMessage': '',
//         'lastMessageTime': null,
//         'typingStatus': {currentUserId: false, otherUserId: false},
//         'unreadCounts': {currentUserId: 0, otherUserId: 0},
//       });
//     }

//     return chatRoomId;
//   }

//   // Send a message
//   Future<void> sendMessage({
//     required String chatRoomId,
//     required String message,
//     required String receiverId,
//   }) async {
//     final currentUserId = this.currentUserId;
//     final messageId = DateTime.now().millisecondsSinceEpoch.toString();

//     // Create message document
//     final chatMessage = ChatMessage(
//       id: messageId,
//       senderId: currentUserId,
//       senderName: 'You', // This should come from user profile
//       message: message,
//       timestamp: DateTime.now(),
//       isRead: false,
//     );

//     // Add to messages subcollection
//     await getMessagesCollection(chatRoomId).doc(messageId).set(
//       chatMessage.toFirestore(),
//     );

//     // Update chat room with last message
//     await chatRoomsCollection.doc(chatRoomId).update({
//       'lastMessage': message,
//       'lastMessageTime': FieldValue.serverTimestamp(),
//       'lastMessageSenderId': currentUserId,
//       // Increment unread count for receiver
//       'unreadCounts.$receiverId': FieldValue.increment(1),
//     });
//   }

//   // Stream of messages for a chat room
//   Stream<List<ChatMessage>> getMessagesStream(String chatRoomId) {
//     return getMessagesCollection(chatRoomId)
//         .orderBy('timestamp', descending: true)
//         .snapshots()
//         .map((snapshot) {
//       return snapshot.docs.map((doc) {
//         final data = doc.data() as Map<String, dynamic>;
//         return ChatMessage.fromFirestore(data);
//       }).toList();
//     });
//   }

//   // Stream of chat rooms for current user
//   Stream<List<Map<String, dynamic>>> getChatRoomsStream() {
//     return chatRoomsCollection
//         .where('participants', arrayContains: currentUserId)
//         .orderBy('lastMessageTime', descending: true)
//         .snapshots()
//         .map((snapshot) {
//       return snapshot.docs.map((doc) {
//         final data = doc.data()! as Map<String, dynamic>;
//         final participants = List<String>.from(data['participants'] ?? []);
//         final otherUserId = participants.firstWhere(
//           (id) => id != currentUserId,
//           orElse: () => '',
//         );

//         return {
//           'chatRoomId': doc.id,
//           'otherUserId': otherUserId,
//           'lastMessage': data['lastMessage'] ?? '',
//           'lastMessageTime': (data['lastMessageTime'] as Timestamp?)?.toDate(),
//           'lastMessageSenderId': data['lastMessageSenderId'],
//           'unreadCount': (data['unreadCounts'] as Map<String, dynamic>?)?[currentUserId] ?? 0,
//         };
//       }).toList();
//     });
//   }

//   // Mark messages as read
//   Future<void> markMessagesAsRead(String chatRoomId) async {
//     final batch = _firestore.batch();

//     // Mark all unread messages from others as read
//     final messages = await getMessagesCollection(chatRoomId)
//         .where('senderId', isNotEqualTo: currentUserId)
//         .where('isRead', isEqualTo: false)
//         .get();

//     for (final doc in messages.docs) {
//       batch.update(doc.reference, {'isRead': true});
//     }

//     // Reset unread count for current user
//     batch.update(chatRoomsCollection.doc(chatRoomId), {
//       'unreadCounts.$currentUserId': 0,
//     });

//     await batch.commit();
//   }

//   // Update typing status
//   Future<void> updateTypingStatus(
//     String chatRoomId,
//     bool isTyping,
//   ) async {
//     await chatRoomsCollection.doc(chatRoomId).update({
//       'typingStatus.$currentUserId': isTyping,
//     });
//   }

//   // Get typing status stream
//   Stream<bool> getTypingStatusStream(String chatRoomId, String otherUserId) {
//     return chatRoomsCollection.doc(chatRoomId)
//         .snapshots()
//         .map((doc) {
//           final data = doc.data() as Map<String, dynamic>?;
//           final typingStatus = data?['typingStatus'] as Map<String, dynamic>?;
//           return (typingStatus?[otherUserId] as bool?) ?? false;
//         });
//   }

//   // Delete message
//   Future<void> deleteMessage(String chatRoomId, String messageId) async {
//     await getMessagesCollection(chatRoomId).doc(messageId).delete();
//   }

//   // Add reaction to message
//   Future<void> addReaction(
//     String chatRoomId,
//     String messageId,
//     String emoji,
//   ) async {
//     await getMessagesCollection(chatRoomId).doc(messageId).update({
//       'reactions.$currentUserId': emoji,
//     });
//   }

//   // Get user data by ID
//   Future<Map<String, dynamic>?> getUserData(String userId) async {
//     try {
//       final doc = await _firestore.collection('users').doc(userId).get();
//       return doc.data();
//     } catch (e) {
//       return null;
//     }
//   }
// }
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/chat/chat_contact.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Map of users (email , id)
  Stream<List<Map<String, dynamic>>> getUsersStream() {
    return _firestore.collection("Users").snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final user = doc.data();
        return user;
      }).toList();
    });
  }

  // ✅ NEW: Helper method to get current user's name from Firestore
  Future<String> _getCurrentUserName() async {
    try {
      final String currentUserID = _auth.currentUser!.uid;
      DocumentSnapshot userDoc = await _firestore
          .collection("Users")
          .doc(currentUserID)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        // Try different field names that might contain the name
        return data['fullName'] ??
            data['FullName'] ??
            data['username'] ??
            data['Username'] ??
            data['name'] ??
            'User';
      }
      return 'User';
    } catch (e) {
      print('Error getting user name: $e');
      return 'User';
    }
  }

  // ✅ FIXED: Now gets actual username instead of hardcoded "tester"
  Future<void> sendMessage(String receiverID, String message) async {
    try {
      // Get current users info
      final String currentUserID = _auth.currentUser!.uid;
      final String currentUserEmail = _auth.currentUser!.email!;
      final String currentUserName =
          await _getCurrentUserName(); // ✅ Get actual name
      final Timestamp timestamp = Timestamp.now();

      // Create message with real senderName

      // Create chat room ID
      List<String> ids = [currentUserID, receiverID];
      ids.sort();
      String chatRoomID = ids.join('_');

      // Add new message to db
      await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .collection("messages")
          .add({
            'senderID': currentUserID,
            'senderName': currentUserName,
            'receiverID': receiverID,
            'message': message,
            'timestamp': timestamp,
            'read': false,
          });
      final chatRoomDoc = await _firestore
          .collection("chat_rooms")
          .doc(chatRoomID)
          .get();
      int currentUnread = 0;

      if (chatRoomDoc.exists) {
        final data = chatRoomDoc.data();
        currentUnread = data?['unreadCount'] ?? 0;
      }

      // Update chat room metadata
      await _firestore.collection("chat_rooms").doc(chatRoomID).set({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'lastSenderId': currentUserID,
        'participants': [currentUserID, receiverID],
        'unreadCount': currentUnread + 1, // Increment total unread
        'lastMessageSender': currentUserName,
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String chatRoomId, String userId) async {
    try {
      // Reset unread count for this chat room
      await _firestore.collection("chat_rooms").doc(chatRoomId).update({
        'unreadCount': 0,
      });

      // Mark individual messages as read
      final messages = await _firestore
          .collection("chat_rooms")
          .doc(chatRoomId)
          .collection("messages")
          .where('read', isEqualTo: false)
          .where('receiverID', isEqualTo: userId)
          .get();

      for (var doc in messages.docs) {
        await doc.reference.update({'read': true});
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  Stream<List<ChatContact>> getChatContacts() {
    final String currentUserId = _auth.currentUser!.uid;

    return _firestore
        .collection("chat_rooms")
        .where('participants', arrayContains: currentUserId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
          List<ChatContact> contacts = [];

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final participants = List<String>.from(data['participants'] ?? []);
            final otherParticipantId = participants.firstWhere(
              (id) => id != currentUserId,
              orElse: () => '',
            );

            if (otherParticipantId.isEmpty) continue;

            // Get other user's info for display name
            final userDoc = await _firestore
                .collection('Users')
                .doc(otherParticipantId)
                .get();
            final userData = userDoc.data() ?? {};

            contacts.add(
              ChatContact(
                userId: otherParticipantId,
                chatId: doc.id,
                lastMessageTime: (data['lastMessageTime'] as Timestamp)
                    .toDate(),
                lastMessage: data['lastMessage'] ?? '',
                unreadCount: data['unreadCount'] ?? 0,
              ),
            );
          }

          return contacts;
        });
  }

  // Get unread count stream for a specific user
  Stream<int> getUnreadCount(String userId) {
    final String currentUserId = _auth.currentUser!.uid;

    return _firestore
        .collection("chat_rooms")
        .where('participants', arrayContains: currentUserId)
        .snapshots()
        .map((snapshot) {
          int totalUnread = 0;
          for (var doc in snapshot.docs) {
            final data = doc.data();
            totalUnread += (data['unreadCount'] as int);
          }
          return totalUnread;
        });
  }

  Stream<QuerySnapshot> getMessages(String userID, otherUserID) {
    List<String> ids = [userID, otherUserID];
    ids.sort();
    String chatRoomID = ids.join('_');
    return _firestore
        .collection("chat_rooms")
        .doc(chatRoomID)
        .collection("messages")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }
}
