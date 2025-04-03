import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:open_file/open_file.dart';
import 'package:path/path.dart' as p;

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:senseai/features/user_auth/presentation/pages/video_screen.dart';

import '../../data/api_service.dart';

String randomString() {
  final random = Random.secure();
  final values = List<int>.generate(16, (i) => random.nextInt(255));
  return base64UrlEncode(values);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

List<CameraDescription>? _cameras;

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final List<types.Message> _messages = [];
  final _user = const types.User(id: '82091008-a484-4a89-ae75-a22bf8d6f3ac');
  final _bot = const types.User(
    id: 'bot-1234', // Unique bot ID
    firstName: 'SenseAI Bot', // Bot name
  );

  final apiService = ApiService(http.Client());

  final AudioRecorder audioRecorder = AudioRecorder();
  CameraController? controller;
  List<CameraDescription>? cameras;
  bool isRecordingAudio = false; // For audio recording
  bool isRecordingVideo = false; // For video recording

  int _selectedCameraIndex = 0;
  bool _isInitialized = false;

  bool isPlaying = false;
  String? recordingPath;
  final AudioPlayer audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    // Dispose audioPlayer to avoid memory leaks
    audioPlayer.dispose();
    WidgetsBinding.instance.removeObserver(this);
    controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    // Fetch the available cameras
    final cameras = await availableCameras();
    setState(() {
      _cameras = cameras;
      controller = CameraController(
        _cameras![0], // You can change this index for front/back camera
        ResolutionPreset.high,
      );
    });

    // Initialize the controller
    await controller!.initialize();
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  // void didChangeAppLifecycleState(AppLifecycleState state) {
  //   if (controller == null || !(controller?.value.isInitialized ?? false)) {
  //     return;
  //   }

  //   if (state == AppLifecycleState.inactive) {
  //     controller?.dispose();
  //   } else if (state == AppLifecycleState.resumed) {
  //     _initializeCamera();
  //   }
  // }

  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;

  double _currentScale = 1.0;
  double _baseScale = 1.0;
  int _pointers = 0;

  void _handleScaleStart(ScaleStartDetails details) {
    _baseScale = _currentScale;
  }

  Future<void> _handleScaleUpdate(ScaleUpdateDetails details) async {
    // When there are not exactly two fingers on screen don't scale
    if (controller == null || _pointers != 2) {
      return;
    }

    _currentScale = (_baseScale * details.scale)
        .clamp(_minAvailableZoom, _maxAvailableZoom);

    await controller!.setZoomLevel(_currentScale);
  }

  void onViewFinderTap(TapDownDetails details, BoxConstraints constraints) {
    if (controller == null) {
      return;
    }

    final CameraController cameraController = controller!;

    final Offset offset = Offset(
      details.localPosition.dx / constraints.maxWidth,
      details.localPosition.dy / constraints.maxHeight,
    );
    cameraController.setExposurePoint(offset);
    cameraController.setFocusPoint(offset);
  }

  Future<String?> extractAudio(String videoPath) async {
    // Get the app's documents directory
    final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    final String audioPath =
        '${appDocumentsDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // Execute the command
    final String command = '-i $videoPath -q:a 0 -vn $audioPath';
    final FFmpegSession session = await FFmpegKit.execute(command);

    // Await the return code of the execution
    final returnCode = await session.getReturnCode();
    // Check the return code of the execution
    if (ReturnCode.isSuccess(returnCode)) {
      print("Audio extracted successfully: $audioPath");
      return audioPath;
    } else {
      print("Failed to extract audio. RC: $returnCode");
      return null;
    }
  }

  Future<List<String>> extractFrames(String videoPath) async {
    // Get the app's documents directory
    final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    final String framesDirectory = '${appDocumentsDir.path}/frames/';
    await Directory(framesDirectory).create(recursive: true);

    // FFmpeg command to extract frames
    final String framePathTemplate = '$framesDirectory/frame_%03d.png';
    final String command = '-i "$videoPath" -vf fps=1 "$framePathTemplate"';

    // Execute the command
    final FFmpegSession session = await FFmpegKit.execute(command);

    // ✅ Await the return code
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print("Frames extracted successfully in: $framesDirectory");

      // List all the frame files in the frames directory
      final List<FileSystemEntity> files =
          Directory(framesDirectory).listSync();
      final message = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        height: 100,
        id: randomString(),
        name: "result.name",
        size: 100,
        uri:
            "/data/user/0/com.example.senseai/app_flutter/frames/frame_001.png",
        width: 100,
      );

      _addMessage(message);
      return files.map((file) => file.path).toList();
    } else {
      print("Failed to extract frames. RC: $returnCode");
      return [];
    }
  }

  Future<File> resizeImageWithFFmpegKit(File image) async {
    final tempDir = await getTemporaryDirectory();
    String outputPath =
        '${tempDir.path}/${image.uri.pathSegments.last}-resized.jpg';

    // Resize to 224x224 and compress
    String resizeCommand =
        '-i "${image.path}" -vf "scale=224:224" -q:v 5 "$outputPath"';

    await FFmpegKit.executeAsync(resizeCommand);

    return File(outputPath);
  }

  void processVideo(String videoPath) async {
    // Get the app's documents directory
    final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    final String framesDirectory = '${appDocumentsDir.path}/frames/';
    final String resizedFramesDirectory =
        '${appDocumentsDir.path}/resized_frames/';

    // Delete all previous frames and resized frames
    await _deletePreviousFrames(framesDirectory);
    await _deletePreviousFrames(resizedFramesDirectory);

    // Extract audio
    final String? audioPath = await extractAudio(videoPath);
    if (audioPath != null) {
      print("Audio saved at: $audioPath");
    }

    // Extract frames
    final List<String> framePaths = await extractFrames(videoPath);
    if (framePaths.isNotEmpty) {
      print("Frames saved at: $framePaths");

      // Resize extracted frames
      List<File> resizedFrames = [];
      for (var path in framePaths) {
        File resized = await resizeImageWithFFmpegKit(File(path));
        resizedFrames.add(resized);
      }

      apiService.sendImages(resizedFrames).then((responseText) {
        _updateLastMessage(responseText);
      }).catchError((error) {
        _updateLastMessage("Error: Failed to get response.");
      });
    }
  }

  Future<void> _deletePreviousFrames(String directoryPath) async {
    final directory = Directory(directoryPath);

    // Check if the directory exists
    if (await directory.exists()) {
      // List all files in the directory and delete them
      try {
        final files = directory.listSync();
        for (var file in files) {
          if (file is File) {
            await file.delete();
            print("Deleted file: ${file.path}");
          }
        }
      } catch (e) {
        print("Failed to delete previous frames: $e");
      }
    }
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
                onAttachmentPressed: _handleAttachmentPressed,
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
        await navigateAndGetVideo(context);
      },
      icon: Icon(Icons.camera),
    );
  }

  Future<void> navigateAndGetVideo(BuildContext context) async {
    // Fetch the list of available cameras
    final cameras = await availableCameras();

    // Ensure cameras are available before navigating
    if (cameras.isEmpty) {
      print('No cameras available');
      return;
    }

    // Navigate to the VideoScreen and get the video path when done
    final videoPath = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => VideoScreen(cameras)),
    );

    // Add the message directly without file selection
    if (videoPath != null) {
      addMessageFromPath(videoPath); // Call the method to add the message
      processVideo(videoPath);
    }
  }

  void _addMessage(types.Message message) {
    setState(() {
      _messages.insert(0, message);
    });
  }

  void _handleAttachmentPressed() {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => SafeArea(
        child: SizedBox(
          height: 144,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImageSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Photo'),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _handleFileSelection();
                },
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('File'),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // FirebaseAuth.instance.signOut();
  //               Navigator.pushNamed(context, "/login");
  //               showToast(message: "Successfully signed out");

  void _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result != null && result.files.single.path != null) {
      final message = types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: randomString(),
        name: result.files.single.name,
        size: result.files.single.size,
        uri: result.files.single.path!,
      );

      _addMessage(message);
    }
  }

  void addMessageFromPath(String filePath) {
    // Check if the video path is not empty (or any other condition you want)
    if (filePath.isNotEmpty) {
      final message = types.FileMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        id: randomString(),
        name: 'Video Recorded',
        size: 0, // You can set size if needed
        uri: filePath, // Use the video path directly
      );

      _addMessage(
          message); // Assuming _addMessage adds the message to your chat system
    }
  }

  void _handleImageSelection() async {
    final result = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );

    if (result != null) {
      final bytes = await result.readAsBytes();
      final image = await decodeImageFromList(bytes);

      final message = types.ImageMessage(
        author: _user,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        height: image.height.toDouble(),
        id: randomString(),
        name: result.name,
        size: bytes.length,
        uri: result.path,
        width: image.width.toDouble(),
      );

      _addMessage(message);
    }
  }

  void _handleMessageTap(BuildContext context, types.Message message) async {
    //This includes files hosted online
    if (message is types.FileMessage) {
      var localPath = message.uri;

      // If the file is hosted online (HTTP/HTTPS), download it
      if (message.uri.startsWith('http')) {
        try {
          // Find the index of the message in the list
          final index =
              _messages.indexWhere((element) => element.id == message.id);

          // Update the message to show a loading indicator
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: true,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });

          // Download the file
          final client = http.Client();
          final request = await client.get(Uri.parse(message.uri));
          final bytes = request.bodyBytes;

          // Get the application documents directory
          final documentsDir = (await getApplicationDocumentsDirectory()).path;
          localPath = '$documentsDir/${message.name}';

          // Save the file if it doesn't already exist
          if (!File(localPath).existsSync()) {
            final file = File(localPath);
            await file.writeAsBytes(bytes);
          }
        } finally {
          // Find the index of the message again (in case the list changed)
          final index =
              _messages.indexWhere((element) => element.id == message.id);

          // Update the message to remove the loading indicator
          final updatedMessage =
              (_messages[index] as types.FileMessage).copyWith(
            isLoading: null,
          );

          setState(() {
            _messages[index] = updatedMessage;
          });
        }
      }

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

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: _user,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: message.text,
    );

    _addMessage(textMessage);

    final botMessage = types.TextMessage(
      author: _bot, // Bot as author
      createdAt: DateTime.now().millisecondsSinceEpoch,
      id: randomString(),
      text: "Thinking...", // Placeholder text
      metadata: {"isLoading": true}, // Set loading state
    );

    _addMessage(botMessage);

    final client = http.Client(); // Or http.BrowserClient() for web

    apiService.sendText(message.text).then((responseText) {
      _updateLastMessage(responseText);
    }).catchError((error) {
      _updateLastMessage("Error: Failed to get response.");
    });
  }

  void _updateLastMessage(String newText) {
    final index = _messages.length - 1; // Get last message index

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
