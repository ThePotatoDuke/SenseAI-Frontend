import 'package:camera/camera.dart';
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
// import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:senseai/features/user_auth/presentation/pages/video_screen.dart';

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

    // Listen for audio playback completion
    audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            isPlaying = false; // Reset isPlaying when playback completes
          });
        }
      }
    });
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

  Widget _recordingButton() {
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
              final String filePath =
                  p.join(appDocumentsDir.path, "recording.wav");
              await audioRecorder.start(const RecordConfig(), path: filePath);
              setState(() {
                isRecordingAudio = true;
                recordingPath = null;
              });
            }
          }
        },
        icon: Icon(isRecordingAudio ? (Icons.stop) : (Icons.mic)));
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
    if (message is types.FileMessage) {
      var localPath = message.uri;

      // If the file is hosted online (HTTP/HTTPS), download it
      if (message.uri.startsWith('http')) {
        try {
          // Find the index of the message in the list
          final index = _messages.indexWhere((element) => element.id == message.id);

          // Update the message to show a loading indicator
          final updatedMessage = (_messages[index] as types.FileMessage).copyWith(
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
          final index = _messages.indexWhere((element) => element.id == message.id);

          // Update the message to remove the loading indicator
          final updatedMessage = (_messages[index] as types.FileMessage).copyWith(
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
  }
}
