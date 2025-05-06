import 'dart:io';

import 'dart:async';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:path_provider/path_provider.dart';


import '../user_auth/data/api_service.dart';


class VideoProcessor {
  final ApiService apiService;

  VideoProcessor(this.apiService);

  Future<String?> extractAudio(String videoPath) async {
    final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    final String audioPath = '${appDocumentsDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

    final String command = '-i $videoPath -q:a 0 -vn $audioPath';
    final FFmpegSession session = await FFmpegKit.execute(command);

    final returnCode = await session.getReturnCode();
    if (ReturnCode.isSuccess(returnCode)) {
      print("Audio extracted successfully: $audioPath");
      return audioPath;
    } else {
      print("Failed to extract audio. RC: $returnCode");
      return null;
    }
  }

  Future<List<String>> extractFrames(String videoPath) async {
    final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    final String framesDirectory = '${appDocumentsDir.path}/frames/';
    final Directory framesDir = Directory(framesDirectory);

    if (await framesDir.exists()) {
      await framesDir.delete(recursive: true);
    }
    await framesDir.create(recursive: true);

    final String framePathTemplate = '$framesDirectory/frame_%03d.png';
    final String command = '-y -i "$videoPath" -vf fps=1 "$framePathTemplate"';

    final FFmpegSession session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (ReturnCode.isSuccess(returnCode)) {
      print("Frames extracted successfully in: $framesDirectory");

      final List<FileSystemEntity> files = framesDir.listSync();
      final framePaths = files
          .where((file) => file is File && file.path.endsWith('.png'))
          .map((file) => file.path)
          .toList();

      return framePaths;
    } else {
      print("Failed to extract frames. RC: $returnCode");
      return [];
    }
  }

  Future<File> resizeImageWithFFmpegKit(File inputFile) async {
    final outputPath = '${inputFile.path}-resized.jpg';
    final outputFile = File(outputPath);

    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    await FFmpegKit.execute('-i "${inputFile.path}" -vf scale=640:480 "$outputPath"');
    return outputFile;
  }

  Future<void> processVideo(String videoPath) async {
    try {
      final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
      final String framesDirectory = '${appDocumentsDir.path}/frames/';
      final String resizedFramesDirectory = '${appDocumentsDir.path}/resized_frames/';

      // Extract audio
      final String? audioPath = await extractAudio(videoPath);
      if (audioPath != null) {
        print("Audio saved at: $audioPath");
      }

      // Extract frames
      final List<String> framePaths = await extractFrames(videoPath);

      if (framePaths.isNotEmpty) {
        print("Frames saved at: $framePaths");

        // Resize extracted frames - wait for ALL to complete
        List<File> resizedFrames = await Future.wait(
          framePaths.map((path) async {
            return await resizeImageWithFFmpegKit(File(path));
          }),
        );

        // Now send all resized frames
        try {
          final responseText = await apiService.sendImages(resizedFrames);
          print("Server response: $responseText");
        } catch (error) {
          print("Error sending resized frames: $error");
        }
      }
    } catch (e) {
      print("Error processing video: $e");
    }
  }
}
