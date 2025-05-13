import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:senseai/features/user_auth/presentation/pages/video_screen.dart';
import 'package:senseai/features/utils/video_processor.dart';

import '../../../utils/audio_processor.dart';
import '../../data/api_service.dart';

String randomString() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(255));
  return base64UrlEncode(values);
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

List<CameraDescription>? _cameras;

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  final List<types.Message> _messages = [];
  final _user = const types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ac');
  final _bot = const types.User(
    id: 'bot-1234', // Unique bot ID
    firstName: 'SenseAI Bot', // Bot name
  );

  final apiService = ApiService(http.Client());
  late VideoProcessor _processor;

  @override
  void initState() {
    super.initState();
    _processor = VideoProcessor(apiService);
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text("Chat"),
          actions: [
            _recordingButton(),
            _videoRecordingButton(),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Chat(
                messages: _messages,
                onMessageTap: _handleMessageTap,
                onPreviewDataFetched: _handlePreviewDataFetched,
                onSendPressed: _handleSendPressed,
                user: _user,
              ),
            ),
          ],
        ),
      );

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
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                ),
              );
            }
            _postBotThinking();

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


  Future<void> handleVideoProcessingAndSending(BuildContext context) async {
    final videoPath = await navigateAndGetVideo(context);
    if (videoPath != null) {
      addMessageFromPath(videoPath);

      try {
        print("THE PATH IS " + videoPath);

        // Step 1: Process the video
        final processedData = await _processor.processVideo(videoPath);

        // Step 2: If audio exists, get transcript
        if (processedData.transcript.isNotEmpty) {
          _addMessage(
            types.TextMessage(
              author: _user,
              id: DateTime.now().toIso8601String(),
              text: processedData.transcript,
              createdAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        }
        _postBotThinking();


        // Step 3: Send processed data to server
        apiService.sendMultipartRequest(text: processedData.transcript).then((responseBody) {
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
  //               Navigator.pushNamed(context, "/login");
  //               showToast(message: "Successfully signed out");

  void addMessageFromPath(String filePath) {
    // Check if the video path is not empty (or any other condition you want)
    if (filePath.isNotEmpty) {
      final message = types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
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

  void _handlePreviewDataFetched(
    types.TextMessage message,
    types.PreviewData previewData,
  ) {
    final index = _messages.indexWhere((element) => element.id == message.id);
    final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
      previewData: previewData,
    );

    setState(() {
      _messages[index] = updatedMessage;
    });
  }
  void _postBotThinking(){
    final botMessage = types.TextMessage(
      author: _bot,
      // Bot as author
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: "Thinking...",
      // Placeholder text
    );
    _addMessage(botMessage);

  }

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: message.text,
    );

    _addMessage(textMessage);

    _postBotThinking();

    final client = http.Client(); // Or http.BrowserClient() for web

    apiService.sendMultipartRequest(text: message.text).then((responseBody) {
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

  void _updateLastMessage(String newText) {
    final index = 0; // Get last message index

    if (index >= 0 && _messages[index] is types.TextMessage) {
      final updatedMessage = (_messages[index] as types.TextMessage).copyWith(
        text: newText, // Update with actual response
        metadata: {"isLoading": false}, // Remove loading state
      );
      setState(() {
        _messages[index] = updatedMessage;
      });
    }
  }
}
