import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flyer_chat_file_message/flyer_chat_file_message.dart';
import 'package:flyer_chat_text_message/flyer_chat_text_message.dart';
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

  const ChatPage({Key? key, required this.chatId}) : super(key: key);

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final List<chat_core.User> users = [
    chat_core.User(id: 'user1'),
    chat_core.User(id: 'bot'),
  ];
  bool _isBotThinking = false;

  Future<chat_core.User?> resolveUser(chat_core.UserID id) async {
    if (_user.id == id) return _user;
    return chat_core.User(id: id); // fallback bot or unknown
  }

  List<chat_core.Message> _messages = [];

  final _chatController = InMemoryChatController();

  final _bot = const types.User(
    id: 'bot-1234', // Unique bot ID
    firstName: 'SenseAI Bot', // Bot name
  );

  final apiService = ApiService(http.Client());
  late VideoProcessor _processor;
  final ChatService _chatService = ChatService();

  late final chat_core.User _user;

  @override
  void initState() {
    super.initState();
    _processor = VideoProcessor(apiService);
    _user = chat_core.User(id: FirebaseAuth.instance.currentUser!.uid);
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

  @override
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text("Chat"),
          actions: [
            _recordingButton(),
            _videoRecordingButton(),
          ],
        ),
        body: StreamBuilder<List<chat_core.Message>>(
          stream: _chatService.getMessages(widget.chatId)
              as Stream<List<chat_core.Message>>?,
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

            if (!listEquals(_messages, mergedMessages)) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() {
                  _messages
                    ..clear()
                    ..addAll(mergedMessages);
                });

                _chatController
                    .setMessages(mergedMessages); // Also set to controller
              });
            }

            return Column(
              children: [
                Expanded(
                  child: Chat(
                    chatController: _chatController,
                    currentUserId: _user.id,
                    resolveUser: resolveUser,
                    onMessageSend: _isBotThinking ? null : _handleSendPressed,

                    builders: Builders(
                      fileMessageBuilder: (context, message, index) =>
                          FlyerChatFileMessage(message: message, index: index),
                      textMessageBuilder: (context, message, index) =>
                          FlyerChatTextMessage(
                            message: message,
                            index: index,
                            showStatus: true,
                          ),
                    ),
                    onMessageTap: _handleMessageTap,
                  )
                ),
              ],
            );
          },
        ),
      );

  List<chat_core.Message> _mergeMessages(
    List<chat_core.Message> firestoreMessages,
    List<chat_core.Message> localMessages,
  ) {
    final Map<String, chat_core.Message> merged = {
      for (final msg in firestoreMessages) msg.id: msg,
    };

    for (final localMsg in localMessages) {
      merged[localMsg.id] = localMsg;
    }

    return merged.values.toList();
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
            await _chatService.sendFileMessageLocalOnly(
              filePath: filePath,
              chatId: widget.chatId,
              fileType: 'audio',
            );
            var transcript = await transcribeAudio(recordingPath!);
            if (transcript.isNotEmpty) {
              _addMessage(
                chat_core.TextMessage(
                  authorId: _user.id,
                  id: DateTime.now().toIso8601String(),
                  text: transcript,
                  createdAt: DateTime.now().toUtc(),
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
                'audio_${DateTime.now().millisecondsSinceEpoch}.wav');
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
    await _chatService.sendFileMessageLocalOnly(
      filePath: videoPath!,
      chatId: widget.chatId,
      fileType: 'video',
    );
    if (videoPath != null) {

      final newDirPath =
          '${(await getApplicationDocumentsDirectory()).path}/$widget.chatId';

      final newFilePath = '$newDirPath/${p.basename(videoPath)}';

// Create directory if it doesn't exist
      final newDir = Directory(newDirPath);
      if (!await newDir.exists()) {
        await newDir.create(recursive: true);
      }

// Now copy the file
      await File(videoPath).copy(newFilePath);

      try {
        // Step 3: Process the video
        final processedData = await _processor.processVideo(videoPath);

        // Step 4: If transcript exists, add text message
        if (processedData.transcript.isNotEmpty) {
          _addMessage(
            chat_core.TextMessage(
              authorId: _user.id,
              id: DateTime.now().toIso8601String(),
              text: processedData.transcript,
              createdAt: DateTime.now().toUtc(),
            ),
          );
        }

        _postBotThinking();

        // Step 5: Send processed data to server (API call)
        final responseBody = await apiService.sendMultipartRequest(
          text: processedData.transcript,
          audioPath: processedData.audioPath,
          imageFiles: processedData.resizedFrames,
        );

        final decoded = jsonDecode(responseBody);
        final llamaResponse =
            decoded['llamaResponse'] ?? 'No response received';
        _updateLastMessage(llamaResponse);

        // Here you could send video message to backend if needed
        // await _chatService.sendVideoMessage(newPath, widget.chatId);
      } catch (e) {
        print("Error handling video processing or sending: $e");
      }
    }
  }

  void _addMessage(chat_core.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
    _chatController.insertMessage(message);
  }

  // FirebaseAuth.instance.signOut();
  //               Navigator.push(context, MaterialPageRoute(builder: (_) => LoginPage()));
  //               showToast(message: "Successfully signed out");

  void addMessageFromPath(String filePath) async {
    if (filePath.isNotEmpty) {
      final file = File(filePath);
      final size = await file.length();

      final message = chat_core.FileMessage(
        authorId: _user.id,
        createdAt: DateTime.now().toUtc(),
        id: randomString(),
        name: p.basename(filePath),
        size: size,
        source: filePath,
        mimeType: 'video/mp4',
      );

      _addMessage(message);
    }
  }


  void _handleMessageTap(
      chat_core.Message message, {
        int? index,
        TapUpDetails? details,
      }) async {
    if (message is chat_core.FileMessage) {
      final localPath = message.source;

      if (localPath.isNotEmpty) {
        await OpenFile.open(localPath);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File path is missing.')),
        );
      }
    }
  }






  void _postBotThinking() {
    setState(() {
      _isBotThinking = true;
    });

    final botMessage = chat_core.TextMessage(
      authorId: _bot.id,
      createdAt: DateTime.now().toUtc(),
      id: 'thinking-${DateTime.now().millisecondsSinceEpoch}',
      text: "🤔 Thinking...",
      metadata: {
        'sending': true,
      },
    );

    _addMessage(botMessage);
  }





  Future<void> _handleSendPressed(String text) async {
    final chatService = ChatService();

    // Create a new text message
    final textMessage = chat_core.TextMessage(
      authorId: _user.id,
      createdAt: DateTime.now().toUtc(),
      id: randomString(),
      text: text,
    );

    // Add the message locally immediately
    _addMessage(textMessage);

    // Reference to the chat document in Firestore
    final chatRef = FirebaseFirestore.instance
        .collection('users')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('chats')
        .doc(widget.chatId);

    // Ensure the chat session exists
    final chatDoc = await chatRef.get();
    if (!chatDoc.exists) {
      await chatService.createChatSession(widget.chatId);
    }

    // Save user message to Firestore (or your backend)
    await chatService.sendMessage(
      chatId: widget.chatId,
      message: textMessage,
    );

    // Show bot thinking/loading state if needed
    _postBotThinking();

    // Send the text to your API, process bot response
    try {
      final responseBody = await apiService.sendMultipartRequest(text: text);
      final decoded = jsonDecode(responseBody);
      final llamaResponse = decoded['llamaResponse'] ?? 'No response received';

      final botMessage = chat_core.TextMessage(
        authorId: _bot.id,
        createdAt: DateTime.now().toUtc(),
        id: randomString(),
        text: llamaResponse,
      );

      _updateLastMessage(
          llamaResponse); // update UI "thinking" message if you use one
      _addMessage(botMessage);
      setState(() {
        _isBotThinking = false;
      });


      // Save bot message to Firestore (or your backend)
      await chatService.sendMessage(
        chatId: widget.chatId,
        message: botMessage,
      );
    } catch (error) {
      _updateLastMessage("Error: Failed to get response: $error");
    }
  }

  void _updateLastMessage(String newText) {
    final index = 0; // Last message index (you might want to double-check this)

    if (index >= 0 && _messages[index] is chat_core.TextMessage) {
      final updatedMessage =
          (_messages[index] as chat_core.TextMessage).copyWith(
        text: newText,
        // Optionally update createdAt to now or keep the old one:
        // createdAt: DateTime.now().millisecondsSinceEpoch,
      );
      setState(() {
        _messages[index] = updatedMessage;
      });
    }
  }
}
