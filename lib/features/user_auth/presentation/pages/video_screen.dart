import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class VideoScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  VideoScreen(this.cameras);

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late CameraController controller;

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
  }

  @override
  void dispose() {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [Positioned.fill(child: CameraPreview(controller))],
      ),
    );
  }
}
