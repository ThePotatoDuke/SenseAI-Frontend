import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:path/path.dart' as p;

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

  Future<void> sendFileMessageLocalOnly({
    required String filePath,
    required String chatId,
    required String fileType, // "video" or "audio"
  }) async {
    final uid = _auth.currentUser!.uid;

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
      'type': fileType, // "video" or "audio"
      'content': filePath, // local file path
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('chats')
        .doc(chatId)
        .update({
      'lastMessage': fileType == 'video' ? '📹 Video message' : '🎵 Audio message',
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
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final type = data['type'];
        final sender = data['sender'];
        final createdAt = (data['timestamp'] as Timestamp?)?.toDate();

        if (type == 'text') {
          return chat_core.TextMessage(
            authorId: sender,
            createdAt: createdAt ?? DateTime.now(),
            id: doc.id,
            text: data['content'] ?? '',
          );
        } else if (type == 'video' || type == 'audio') {
          // Set MIME type accordingly
          final mimeType = type == 'video' ? 'video/mp4' : 'audio/wav';

          return chat_core.FileMessage(
            authorId: sender,
            createdAt: createdAt ?? DateTime.now(),
            id: doc.id,
            name: p.basename(data['content'] ?? ''),
            size: 0, // Optional: add size if you can get it
            source: data['content'] ?? '',
            mimeType: mimeType,
          );
        } else {
          return chat_core.TextMessage(
            authorId: sender,
            createdAt: createdAt ?? DateTime.now(),
            id: doc.id,
            text: '[Unsupported message type]',
          );
        }
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
