import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class ChatService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;

  /// Create a new chat session with optional metadata
  Future<void> createChatSession(String chatId) async {
    final uid = _auth.currentUser!.uid;
    final chatDoc = _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId);

    await chatDoc.set({
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': 'Chat started',
    });
  }

  /// Save a message under a specific session
  Future<void> sendMessage({
    required String chatId,
    required types.TextMessage message,
  }) async {
    final uid = _auth.currentUser!.uid;
    final messageRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id); // You control this ID using `randomString()`

    await messageRef.set({
      'sender': message.author.id,
      'type': 'text',
      'content': message.text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update chat preview
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .update({
      'lastMessage': message.text,
    });
  }

  /// Load past messages for a chat session
  Stream<List<types.TextMessage>> getMessages(String chatId) {
    final uid = _auth.currentUser!.uid;

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return types.TextMessage(
          author: types.User(id: doc['sender']),
          createdAt:
          (doc['timestamp'] as Timestamp?)?.millisecondsSinceEpoch,
          id: doc.id,
          text: doc['content'],
        );
      }).toList();
    });
  }

  /// Load list of existing chat sessions
  Stream<List<Map<String, dynamic>>> getChatSessions() {
    final uid = _auth.currentUser!.uid;

    return _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
      return {
        'chatId': doc.id,
        'lastMessage': doc['lastMessage'],
        'createdAt': doc['createdAt'],
      };
    }).toList());
  }
}
