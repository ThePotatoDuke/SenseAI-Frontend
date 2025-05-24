import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flutter_chat_core/flutter_chat_core.dart';
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

import '../../../utils/audio_processor.dart';
import '../../../utils/globals.dart';
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
  bool showRecentBubble = false;

  final List<chat_core.User> users = [
    chat_core.User(id: 'user1'),
    chat_core.User(id: 'bot'),
  ];
  bool _isBotThinking = false;

  Future<chat_core.User?> resolveUser(chat_core.UserID id) async {
    if (_user.id == id) return _user;
    return chat_core.User(id: id); // fallback bot or unknown
  }


  final _bot = const chat_core.User(
    id: 'bot-1234', // Unique bot ID
    name: 'SenseAI Bot', // Bot name
  );
  Future<void> _loadInitialMessages() async {
    final messages = await _chatService.getMessagesOnce(widget.chatId);
    _chatController.setMessages(messages);
  }

  final apiService = ApiService(http.Client());
  late VideoProcessor _processor;
  final ChatService _chatService = ChatService();

  late final chat_core.User _user;


  @override
  void initState() {
    super.initState();
    _processor = VideoProcessor(apiService);
    _user = chat_core.User(id: FirebaseAuth.instance.currentUser!.uid);
    _loadInitialMessages();

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
  Widget _buildRecentHeartRateBubble() {
    // Get the most recent stress spot (last item)
    final recentStress = recentStressSpots.isNotEmpty ? recentStressSpots.last : null;
    // Get the most recent heart rate spot (last item)
    final recentHR = recentHeartRateSpots.isNotEmpty ? recentHeartRateSpots.last : null;

    // Format helper for showing '-' if null or zero
    String formatValue(double? val) {
      if (val == null || val == 0) return '-';
      return val.toInt().toString();
    }

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      color: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: 250),
        child: Text(
          'Stress: ${formatValue(recentStress?.y)}, HR: ${formatValue(recentHR?.y)}',
          style: TextStyle(fontSize: 14, color: Colors.black87),
        ),
      ),
    );
  }
  final _chatController = InMemoryChatController();


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final primaryDarkColor = theme.colorScheme.primaryContainer;

    final brightness = MediaQuery.platformBrightnessOf(context);
    final chatTheme = brightness == Brightness.dark
        ? ChatTheme.dark().withDarkColors(
      primary: primaryDarkColor
    )
        : ChatTheme.light().withLightColors(
      primary: primaryColor, // Primary is red only when light theme is active
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat"),
        actions: [
          _recordingButton(),
          _videoRecordingButton(),
          IconButton(
            icon: Icon(
              (recentHeartRateSpots.isNotEmpty || recentStressSpots.isNotEmpty)
                  ? Icons.favorite
                  : Icons.favorite_border,
              color: (recentHeartRateSpots.isNotEmpty || recentStressSpots.isNotEmpty)
                  ? Colors.red
                  : Theme.of(context).colorScheme.onError,
            ),
            onPressed: () {
              if (mounted) {
                setState(() {
                  showRecentBubble = !showRecentBubble;
                });
              }
            },
            tooltip: 'Show recent heart rate',
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Chat(
              key: ValueKey(widget.chatId),
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
              theme: chatTheme,
            ),
          ),


          Stack(
            children: [
              // Your main content here (e.g., messages/chat view)

              if (showRecentBubble)
                Positioned(
                  top: 0,
                  right: 16,
                  child: Material(
                    type: MaterialType.transparency,
                    child: _buildRecentHeartRateBubble(),
                  ),
                ),
            ],
          )

        ],
      ),
    );
  }


  _recordingButton() {
    return IconButton(
      onPressed: () async {
        if (isRecordingAudio) {
          String? filePath = await audioRecorder.stop();
          if (filePath != null) {
            if (mounted) {
              setState(() {
                isRecordingAudio = false;
                recordingPath = filePath;
              });
            }

            final fileMessage = FileMessage(
              // Better to use UUID or similar for the ID - IDs must be unique
              id: '${Random().nextInt(1000) + 1}',
              authorId: _user.id,
              createdAt: DateTime.now().toUtc(),
              source: filePath,
              name: 'recorded_media',
              size: File(filePath).lengthSync()
            );
            _addMessage(fileMessage);

            await _chatService.sendFileMessageLocalOnly(
              filePath: filePath,
              chatId: widget.chatId,
              fileType: 'audio',
            );

            String transcript = '';
            try {
              transcript = await transcribeAudio(recordingPath!);
            } catch (e) {
              print('Transcription error: $e');

            }

            if (transcript.isNotEmpty) {
              _addMessage(
                chat_core.TextMessage(
                  authorId: _user.id,
                  id: DateTime.now().toIso8601String(),
                  text: transcript,
                  createdAt: DateTime.now().toUtc(),
                ),
              );

              _postBotThinking();


              apiService
                  .sendMultipartRequest(
                  text: transcript, audioPath: recordingPath)
                  .then((responseBody) async {
                try {
                  final decoded = jsonDecode(responseBody);
                  final llamaResponse =
                      decoded['llamaResponse'] ?? 'No response received';
                  _updateLastBotMessage(llamaResponse);
                  await _handleLlamaResponse(chatId: widget.chatId, responseBody: responseBody);
                } catch (e) {
                  _updateLastBotMessage("Error: Failed to parse response");
                }
              }).catchError((error) {
                _updateLastBotMessage("Error: Failed to get response: $error");
              });
            } else {
              _addMessage(
                chat_core.TextMessage(
                  authorId: _bot.id,
                  id: DateTime.now().toIso8601String(),
                  text: 'Sorry, I could not hear you. Can you try again? 🎧🤔',
                  createdAt: DateTime.now().toUtc(),
                ),
              );
            }
          }
        } else {
          if (await audioRecorder.hasPermission()) {
            final Directory appDocumentsDir =
            await getApplicationDocumentsDirectory();
            final String audioDirectory =
                '${appDocumentsDir.path}/Audio/SenseAI/';
            await Directory(audioDirectory).create(recursive: true);
            final String filePath = p.join(
              audioDirectory,
              'audio_${DateTime.now().millisecondsSinceEpoch}.wav',
            );
            await audioRecorder.start(
              const RecordConfig(
                encoder: AudioEncoder.wav,
                sampleRate: 44100,
                bitRate: 128000,
              ),
              path: filePath,
            );

            if (mounted) {
              setState(() {
                isRecordingAudio = true;
                recordingPath = null;
              });
            }
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

    if (videoPath == null) return;
    final fileMessage = FileMessage(
      // Better to use UUID or similar for the ID - IDs must be unique
        id: '${Random().nextInt(1000) + 1}',
        authorId: _user.id,
        createdAt: DateTime.now().toUtc(),
        source: videoPath,
        name: 'recorded_media',
        size: File(videoPath).lengthSync()
    );

    _addMessage(fileMessage);
    await _chatService.sendFileMessageLocalOnly(
      filePath: videoPath,
      chatId: widget.chatId,
      fileType: 'video',
    );

    final newDirPath =
        '${(await getApplicationDocumentsDirectory()).path}/${widget.chatId}';
    final newFilePath = '$newDirPath/${p.basename(videoPath)}';

    final newDir = Directory(newDirPath);
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
    }

    await File(videoPath).copy(newFilePath);

    try {
      final processedData = await _processor.processVideo(videoPath);

      if (processedData.transcript.isNotEmpty) {
        _addMessage(
          chat_core.TextMessage(
            authorId: _user.id,
            id: DateTime.now().toIso8601String(),
            text: processedData.transcript,
            createdAt: DateTime.now().toUtc(),
          ),
        );
        var transcript = chat_core.TextMessage(
          authorId: _user.id,
          id: DateTime.now().toIso8601String(),
          text: processedData.transcript,
          createdAt: DateTime.now().toUtc(),
        );
        _postBotThinking();
        _chatService.sendMessage(chatId: widget.chatId, message: transcript);


        final responseBody = await apiService.sendMultipartRequest(
          text: processedData.transcript,
          audioPath: processedData.audioPath,
          imageFiles: processedData.resizedFrames,
        );

        final decoded = jsonDecode(responseBody);
        final llamaResponse = decoded['llamaResponse'] ?? 'No response received';
        _updateLastBotMessage(llamaResponse);
        await _handleLlamaResponse(chatId: widget.chatId, responseBody: responseBody);
      } else {
        _addMessage(
          chat_core.TextMessage(
            authorId: _bot.id,
            id: DateTime.now().toIso8601String(),
            text: 'Sorry, I could not hear you. Can you try again? 🎧🤔',
            createdAt: DateTime.now().toUtc(),
          ),
        );
      }
    } catch (e) {
      print("Error handling video processing or sending: $e");

      _addMessage(
        chat_core.TextMessage(
          authorId: _bot.id,
          id: DateTime.now().toIso8601String(),
          text: 'Sorry, I could not hear you. Can you try again? 🎧🤔',
          createdAt: DateTime.now().toUtc(),
        ),
      );
    }
  }



  void _addMessage(chat_core.Message message) {
    _chatController.insertMessage(message);
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
      await _handleLlamaResponse(chatId: widget.chatId, responseBody: responseBody);



    } catch (error) {
      print("in catch");
      _updateLastBotMessage("Error: Failed to get response: $error");
    }
  }

  void _updateLastBotMessage(
      String newText, {
        String? chatId,
        dynamic voiceAnalysis,
        dynamic textAnalysis,
        dynamic videoAnalysis,
      }) {
    final messages = _chatController.messages;

    if (messages.isNotEmpty &&
        messages.last.authorId == _bot.id &&
        messages.last.id.startsWith('thinking-')) {
      final oldMessage = messages.last as chat_core.TextMessage;

      final newMessage = oldMessage.copyWith(
        text: newText,
        metadata: {
          ...?oldMessage.metadata,
          'sending': false,
        },
      );

      _chatController.updateMessage(oldMessage, newMessage);
      print('updating the message');

      if (chatId != null) {
        _chatService.sendMessage(
          chatId: chatId,
          message: newMessage,
          voiceAnalysis: voiceAnalysis,
          textAnalysis: textAnalysis,
          videoAnalysis: videoAnalysis,
        );
      }
    }
  }

  Future<void> _handleLlamaResponse({
    required String chatId,
    required String responseBody,
  }) async {
    try {
      final decoded = jsonDecode(responseBody);

      final llamaResponse = decoded['llamaResponse'] ?? 'No response received';
      final voiceAnalysis = decoded['voiceEmotion'];
      final textAnalysis = decoded['textEmotion'];
      final videoAnalysis = decoded['faceEmotion'];

      // Just update the existing "thinking..." message
      _updateLastBotMessage(llamaResponse,
          chatId: chatId,
          voiceAnalysis: voiceAnalysis,
          textAnalysis: textAnalysis,
          videoAnalysis: videoAnalysis);

    } catch (e) {
      print("Failed to process llama response: $e");
      _updateLastBotMessage("Error: Failed to process response.");
    }
  }
}
