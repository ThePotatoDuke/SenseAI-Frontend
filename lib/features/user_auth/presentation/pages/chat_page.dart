import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';



import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:senseai/features/user_auth/presentation/pages/video_screen.dart';
import 'package:senseai/features/utils/video_processor.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

import '../../../utils/audio_processor.dart';
import '../../data/api_service.dart';
import '../../data/chat_service.dart';


String randomString() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(255));
  return base64UrlEncode(values);
}

class ChatPage extends StatefulWidget {
  final String chatId;

  ChatPage({Key? key, required this.chatId}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final List<types.Message> _messages = [];
  final _chatController = chat_core.InMemoryChatController();
  final _bot = const types.User(
    id: 'bot-1234', // Unique bot ID
    firstName: 'SenseAI Bot', // Bot name
  );

  final apiService = ApiService(http.Client());
  late VideoProcessor _processor;
  final ChatService _chatService = ChatService();

  late final types.User _user;

  final List<chat_core.User> users = [
    chat_core.User(id: 'user1'),
    chat_core.User(id: 'bot'),
  ];
  @override
  void initState() {
    super.initState();
    _user = types.User(id: 'user1');
    _initializeUser();

  }

  final AudioRecorder audioRecorder = AudioRecorder();
  CameraController? controller;
  List<CameraDescription>? cameras;
  bool isRecordingAudio = false; // For audio recording
  bool isRecordingVideo = false; // For video recording

  bool isPlaying = false;
  String? recordingPath;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }
  // 3. Resolve user function (fetch from Firestore)
  Future<chat_core.User?> resolveUser(chat_core.UserID id) async {
    try {
      return users.firstWhere((user) => user.id == id);
    } catch (_) {
      return null;
    }
  }


  Future<void> _initializeUser() async {
    final firebaseUser = fb_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _user = types.User(
        id: firebaseUser.uid,
      );
    } else {
      _user = types.User(id: 'fallback-user');
    }
  }


  List<chat_core.Message> convertTypesToCore(List<types.Message> messages) {
    return messages.map((msg) {
      if (msg is types.TextMessage) {
        return chat_core.TextMessage(
          id: msg.id,
          authorId: msg.author.id,
          createdAt: msg.createdAt != null ? DateTime.fromMillisecondsSinceEpoch(msg.createdAt!) : null,
          text: msg.text,
        );

      }
      // Add conversions for other message types (FileMessage, ImageMessage, etc.)
      // For now, fallback:
      return chat_core.TextMessage(
        id: msg.id,
        authorId: msg.author.id,
        createdAt: msg.createdAt != null ? DateTime.fromMillisecondsSinceEpoch(msg.createdAt!) : null,
        text: "[Unsupported message type]",
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(
        appBar: AppBar(
          title: const Text("Chat"),
          actions: [
            _recordingButton(),
            _videoRecordingButton(),
          ],
        ),
        body: StreamBuilder<List<types.Message>>(
          stream: _chatService.getMessages(widget.chatId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final firestoreMessages = snapshot.data ?? [];
            final mergedMessages = _mergeMessages(firestoreMessages, _messages);

// Only update if there's a change
            if (!listEquals(_messages, mergedMessages)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _messages
                    ..clear()
                    ..addAll(mergedMessages);

                  _chatController.setMessages(convertTypesToCore(_messages)); // Update the chat controller with new messages
                });
              });
            }



            return Column(
                children: [
            Expanded(
            child: Chat(
            chatController: _chatController,
                currentUserId: 'user1',
                onMessageSend: (text) {
                  _chatController.insertMessage(
                    chat_core.TextMessage(
                      // Better to use UUID or similar for the ID - IDs must be unique.
                      id: '${Random().nextInt(1000) + 1}',
                      authorId: 'user1',
                      createdAt: DateTime.now().toUtc(),
                      text: text,
                    ),
                  );
                }, resolveUser: resolveUser,
            ),)]
            ,
            );
          },
        ),
      );

  List<types.Message> _mergeMessages(
      List<types.Message> firestoreMessages,
      List<types.Message> localMessages,
      ) {
    final Map<String, types.Message> merged = {
      for (final msg in firestoreMessages) msg.id: msg,
    };

    for (final localMsg in localMessages) {
      merged[localMsg.id] = localMsg;
    }

    return merged.values.toList()
      ..sort((a, b) => (b.createdAt ?? 0).compareTo(a.createdAt ?? 0));
  }


  _recordingButton() {
    return IconButton(
      onPressed: () async {
        if (isRecordingAudio) {
          String? filePath = await audioRecorder.stop();
          if (filePath != null) {
            setState(() {
              isRecordingAudio = false;
              recordingPath = filePath;
            });
            addMessageFromPath(recordingPath!);
            var transcript = await transcribeAudio(recordingPath!);
            if (transcript.isNotEmpty) {
              _addMessage(
                types.TextMessage(
                  author: _user,
                  id: DateTime.now().toIso8601String(),
                  text: transcript,
                  createdAt: DateTime
                      .now()
                      .millisecondsSinceEpoch,
                ),
              );
            }
            _postBotThinking();
            apiService
                .sendMultipartRequest(
                text: transcript, audioPath: recordingPath)
                .then((responseBody) {
              try {
                final decoded = jsonDecode(responseBody);
                final llamaResponse =
                    decoded['llamaResponse'] ?? 'No response received';
                _updateLastMessage(llamaResponse);
              } catch (e) {
                _updateLastMessage("Error: Failed to parse response");
              }
            }).catchError((error) {
              _updateLastMessage("Error: Failed to get response: $error");
            });
          }
        } else {
          if (await audioRecorder.hasPermission()) {
            final Directory appDocumentsDir =
            await getApplicationDocumentsDirectory();
            final String audioDirectory =
                '${appDocumentsDir.path}/Audio/SenseAI/';
            await Directory(audioDirectory).create(recursive: true);
            final String filePath = p.join(audioDirectory,
                'audio_${DateTime
                    .now()
                    .millisecondsSinceEpoch}.wav');
            await audioRecorder.start(const RecordConfig(), path: filePath);
            setState(() {
              isRecordingAudio = true;
              recordingPath = null;
            });
          }
        }
      },
      icon: Icon(isRecordingAudio ? Icons.stop : Icons.mic),
    );
  }

  Widget _videoRecordingButton() {
    return IconButton(
      onPressed: () async {
        // Call the function to navigate and get the video
        await handleVideoProcessingAndSending(context);
      },
      icon: Icon(Icons.camera),
    );
  }

  Future<String?> navigateAndGetVideo(BuildContext context) async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      print('No cameras available');
      return null;
    }

    return await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoScreen(cameras)),
    );
  }

  Future<void> deleteLocalFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> handleVideoProcessingAndSending(BuildContext context) async {
    final videoPath = await navigateAndGetVideo(context);
    if (videoPath != null) {
      addMessageFromPath(videoPath);
      await _chatService.sendVideoMessage(videoPath, widget.chatId);
      final newPath = '${(await getApplicationDocumentsDirectory())
          .path}/$widget.chatId/${p.basename(videoPath)}';
      await File(videoPath).copy(newPath); // or move
      try {
        // Step 1: Process the video
        final processedData = await _processor.processVideo(videoPath);

        // Step 2: If audio exists, get transcript
        if (processedData.transcript.isNotEmpty) {
          _addMessage(
            types.TextMessage(
              author: _user,
              id: DateTime.now().toIso8601String(),
              text: processedData.transcript,
              createdAt: DateTime
                  .now()
                  .millisecondsSinceEpoch,
            ),
          );
        }
        _postBotThinking();

        // Step 3: Send processed data to server
        apiService
            .sendMultipartRequest(
            text: processedData.transcript,
            audioPath: processedData.audioPath,
            imageFiles: processedData.resizedFrames)
            .then((responseBody) {
          try {
            final decoded = jsonDecode(responseBody);
            final llamaResponse =
                decoded['llamaResponse'] ?? 'No response received';
            _updateLastMessage(llamaResponse);
          } catch (e) {
            _updateLastMessage("Error: Failed to parse response");
          }
        }).catchError((error) {
          _updateLastMessage("Error: Failed to get response: $error");
        });
      } catch (e) {
        print("Error handling video processing or sending: $e");
      }
    }
  }


  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  // FirebaseAuth.instance.signOut();
  //               Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage()));
  //               showToast(message: "Successfully signed out");

  void addMessageFromPath(String filePath) {
    // Check if the video path is not empty (or any other condition you want)
    if (filePath.isNotEmpty) {
      final message = types.FileMessage(
        author: _user,
        createdAt: DateTime
            .now()
            .millisecondsSinceEpoch,
        id: randomString(),
        name: 'Video Recorded',
        size: 0,
        // You can set size if needed
        uri: filePath, // Use the video path directly
      );

      _addMessage(
          message); // Assuming _addMessage adds the message to your chat system
    }
  }

  void _handleMessageTap(BuildContext context, types.Message message) async {
    if (message is types.FileMessage) {
      var localPath = message.uri;

      // Open the file using the `open_file` plugin
      await OpenFile.open(localPath);
    }
  }

  void _postBotThinking() {
    final botMessage = types.TextMessage(
      author: _bot,
      // Bot as author
      createdAt: DateTime
          .now()
          .millisecondsSinceEpoch,
      id: randomString(),
      text: "Thinking...",
      // Placeholder text
    );
    _addMessage(botMessage);
  }

  void _handleSendPressed(types.PartialText message) async {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime
          .now()
          .millisecondsSinceEpoch,
      id: randomString(),
      text: message.text,
    );

    _addMessage(textMessage);

    final chatService = ChatService();
    final chatRef = FirebaseFirestore.instance
        .collection('users')
        .doc(fb_auth.FirebaseAuth.instance.currentUser!.uid)
        .collection('chats')
        .doc(widget.chatId);

    // 👇 Ensure chat session exists
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) {
      await chatService.createChatSession(widget.chatId);
    }

    // ✅ Save message
    await chatService.sendMessage(
      chatId: widget.chatId,
      message: textMessage,
    );

    _postBotThinking();

    apiService
        .sendMultipartRequest(text: message.text)
        .then((responseBody) async {
      try {
        final decoded = jsonDecode(responseBody);
        final llamaResponse =
            decoded['llamaResponse'] ?? 'No response received';

        final botMessage = types.TextMessage(
          author: _bot,
          createdAt: DateTime
              .now()
              .millisecondsSinceEpoch,
          id: randomString(),
          text: llamaResponse,
        );

        _updateLastMessage(llamaResponse);
        _addMessage(botMessage);

        // ✅ Save bot response
        await chatService.sendMessage(
          chatId: widget.chatId,
          message: botMessage,
        );
      } catch (e) {
        _updateLastMessage("Error: Failed to parse response");
      }
    }).catchError((error) {
      _updateLastMessage("Error: Failed to get response: $error");
    });
  }

  void _updateLastMessage(String newText) {
    final index = 0; // Get last message index

    if (index >= 0 && _messages[index] is types.TextMessage) {
      final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
        text: newText, // Update with actual response
      );
      setState(() {
        _messages[index] = updatedMessage;
      });
    }
  }
}

class SimpleFileMessageWidget extends StatelessWidget {
  final types.FileMessage message;

  const SimpleFileMessageWidget(this.message, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file, size: 32),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              message.name ?? 'File',
              style: TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

Widget customMessageBuilder(types.CustomMessage customMessage, {
  required int messageWidth,
}) {
  final message = customMessage as types.Message;
  if (message is types.FileMessage) {
    return Container(
      padding: EdgeInsets.all(20),
      color: Colors.blue,
      child: Text('Video or file here!'),
    );
  }
  return SizedBox.shrink();
}

