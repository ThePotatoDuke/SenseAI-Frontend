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
  Future<String> extractAudio(String videoPath) async {
    final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
    final String audioDirectory = '${appDocumentsDir.path}/audio/';
    final Directory audioDir = Directory(audioDirectory);

    // Create the directory if it doesn't exist
    if (!await audioDir.exists()) {
      await audioDir.create(recursive: true);
    }

    // Define the path for the extracted audio file
    final String audioPath = '${audioDirectory}audio_${DateTime.now().millisecondsSinceEpoch}.wav';

    // FFmpeg command to extract audio from video
    final String command = '-y -i "$videoPath" -vn -acodec pcm_s16le -ar 44100 -ac 2 "$audioPath"';

    // Execute the command to extract audio
    final FFmpegSession session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    // Check if the operation was successful
    if (ReturnCode.isSuccess(returnCode)) {
      print("Audio extracted successfully: $audioPath");
      return audioPath; // Return the path of the extracted audio
    } else {
      print("Failed to extract audio. RC: $returnCode");
      return ''; // Return an empty string if extraction failed
    }
  }
  Future<File> resizeImageWithFFmpegKit(File inputFile) async {
    final outputPath = '${inputFile.path}-resized.jpg';
    final outputFile = File(outputPath);

    if (await outputFile.exists()) {
      await outputFile.delete();
    }

    await FFmpegKit.execute('-i "${inputFile.path}" -vf scale=224:224 "$outputPath"');
    return outputFile;
  }

  Future<List<File>> processVideo(String videoPath) async {
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

        // Resize extracted frames
        List<File> resizedFrames = await Future.wait(
          framePaths.map((path) async {
            return await resizeImageWithFFmpegKit(File(path));
          }),
        );

        return resizedFrames;
      } else {
        throw Exception("No frames were extracted.");
      }
    } catch (e) {
      print("Error processing video: $e");
      rethrow;
    }
  }

}
