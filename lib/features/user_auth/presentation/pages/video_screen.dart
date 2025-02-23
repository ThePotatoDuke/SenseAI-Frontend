import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class VideoScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  VideoScreen(this.cameras);

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late CameraController controller;
  late String videoPath;
  late bool isRecording;

  @override
  void initState() {
    super.initState();
    controller = CameraController(widget.cameras[0], ResolutionPreset.max);
    controller.initialize().then((value) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
    isRecording = false;
  }

  // Start recording
  void startRecording() async {
    if (!controller.value.isInitialized || isRecording) {
      return;
    }

    // Get the app's directory for saving the video
    final Directory appDirectory = await getApplicationDocumentsDirectory();
    final String videoDirectory = '${appDirectory.path}/Movies/SenseAI/';
    await Directory(videoDirectory).create(recursive: true);
    videoPath =
        '$videoDirectory/video_${DateTime.now().millisecondsSinceEpoch}.mp4';

    // Start recording
    await controller.startVideoRecording();
    setState(() {
      isRecording = true;
    });
  }

  // Stop recording and pop the screen, returning the video path
  void stopRecording() async {
    if (!isRecording) return;

    await controller.stopVideoRecording().then((file) {
      setState(() {
        isRecording = false;
      });

      // Handle the recorded video (for example, return the path)
      if (file != null) {
        videoPath = file.path;
        print("Video saved to $videoPath");

        // Pop the screen and return the video path to the previous screen
        Navigator.pop(context, videoPath);
      }
    });
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Video Recording'),
      ),
      body: Stack(
        children: [
          Positioned.fill(child: CameraPreview(controller)),
          if (controller.value.isInitialized)
            Positioned(
              bottom: 30,
              left: 30,
              child: IconButton(
                icon: Icon(
                  isRecording ? Icons.stop : Icons.videocam,
                  size: 40,
                  color: Colors.red,
                ),
                onPressed: isRecording ? stopRecording : startRecording,
              ),
            ),
        ],
      ),
    );
  }
}
