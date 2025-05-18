import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;

import '../presentation/pages/chat_page.dart';

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
    required chat_core.TextMessage message,  // now core model only
  }) async {
    final uid = _auth.currentUser!.uid;
    final messageRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(message.id);

    await messageRef.set({
      'sender': message.authorId,
      'type': 'text',
      'content': message.text,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .update({
      'lastMessage': message.text,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
  }



  /// Load past messages for a chat session
  Stream<List<chat_core.Message>> getMessages(String chatId) {
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
        return chat_core.TextMessage(
          authorId: doc['sender'] as String,
          createdAt: (doc['timestamp'] as Timestamp?)?.toDate(),
          id: doc.id,
          text: doc['content'] as String,
        );
      }).toList();
    });
  }

  Future<void> sendVideoMessage(String videoPath, String chatId) async {
    final uid = _auth.currentUser!.uid;
    final videoFile = File(videoPath);

    final storageRef = FirebaseStorage.instance
        .ref()
        .child('videos')
        .child(uid)
        .child(chatId)
        .child('${randomString()}.mp4');

    await storageRef.putFile(videoFile);
    final downloadUrl = await storageRef.getDownloadURL();

    final messageId = randomString();
    final messageRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc(messageId);

    await messageRef.set({
      'sender': uid,
      'type': 'video',
      'content': downloadUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .update({
      'lastMessage': '📹 Video message',
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
