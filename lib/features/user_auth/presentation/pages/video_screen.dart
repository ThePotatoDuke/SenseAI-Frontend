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
    controller = CameraController(widget.cameras[1], ResolutionPreset.max);
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
      videoPath = file.path;
      print("Video saved to $videoPath");

      // Pop the screen and return the video path to the previous screen
      Navigator.pop(context, videoPath);
    });
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Camera preview at the top
        Expanded(
          child: Stack(
            children: [
              // Constrained Camera Preview with the same size as the screen
              SizedBox.expand(
                child: CameraPreview(controller),
              ),
              if (isRecording)
                Align(
                  alignment: Alignment.bottomCenter, // Align at the bottom
                  child: Padding(
                    padding: const EdgeInsets.only(
                        bottom: 80), // Adjust to fine-tune
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 500),
                          width: 12,
                          height: 12,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "Recording...",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        GestureDetector(
          onTap: isRecording ? stopRecording : startRecording,
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Icon(
                isRecording ? Icons.stop : Icons.videocam,
                color: Colors.white,
                size: 36,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
