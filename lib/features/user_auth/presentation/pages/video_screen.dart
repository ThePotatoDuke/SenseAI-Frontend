import 'dart:async'; // for Timer
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
  Timer? _recordingTimer;  // For auto-stop timer
  Timer? _countdownTimer;  // For UI countdown
  int _secondsRemaining = 9;  // Countdown start from 9

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

    await controller.startVideoRecording();
    setState(() {
      isRecording = true;
      _secondsRemaining = 9; // Reset countdown
    });

    // Auto stop recording after 9 seconds
    _recordingTimer?.cancel();
    _recordingTimer = Timer(Duration(seconds: 9), () {
      if (isRecording) {
        stopRecording();
      }
    });

    // Start countdown timer for UI update every second
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (_secondsRemaining == 0) {
        timer.cancel();
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  // Stop recording
  void stopRecording() async {
    if (!isRecording) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    _countdownTimer?.cancel();
    _countdownTimer = null;

    await controller.stopVideoRecording().then((file) {
      setState(() {
        isRecording = false;
      });

      videoPath = file.path;
      print("Video saved to $videoPath");

      Navigator.pop(context, videoPath);
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _countdownTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: Stack(
            children: [
              SizedBox.expand(child: CameraPreview(controller)),
              if (isRecording)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 80),
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
                        Text(
                          "Recording... ($_secondsRemaining s)",
                          style: const TextStyle(color: Colors.white, fontSize: 16),
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
