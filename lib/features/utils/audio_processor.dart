import 'dart:convert';
import 'dart:io';

import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_session.dart';
import 'package:ffmpeg_kit_flutter/return_code.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
Future<String> convertToMono(String audioFilePath) async {
  final Directory appDocumentsDir = await getApplicationDocumentsDirectory();
  final String audioDirectory = '${appDocumentsDir.path}/audio/';

  // Create the directory if it doesn't exist
  final Directory audioDir = Directory(audioDirectory);
  if (!await audioDir.exists()) {
    await audioDir.create(recursive: true);
  }

  // Define the path for the mono audio file
  final String monoAudioPath = '${audioDirectory}audio_mono_${DateTime.now().millisecondsSinceEpoch}.wav';

  // FFmpeg command to convert to mono (single channel)
  final String command = '-y -i "$audioFilePath" -ac 1 "$monoAudioPath"';

  // Execute the command
  final FFmpegSession session = await FFmpegKit.execute(command);
  final returnCode = await session.getReturnCode();

  // Check if the conversion was successful
  if (ReturnCode.isSuccess(returnCode)) {
    print("Audio converted to mono successfully: $monoAudioPath");
    return monoAudioPath; // Return the path of the converted audio
  } else {
    print("Failed to convert audio to mono. RC: $returnCode");
    return ''; // Return an empty string if conversion failed
  }
}

Future<String> transcribeAudio(String audioFilePath) async {
  // Convert audio to mono
  String monoAudioPath = await convertToMono(audioFilePath);

  if (monoAudioPath.isEmpty) {
    return 'Failed to convert audio to mono';
  }

  final file = File(monoAudioPath);
  final audioBytes = await file.readAsBytes();
  final base64Audio = base64Encode(audioBytes);

  final response = await http.post(
    Uri.parse('https://speech.googleapis.com/v1/speech:recognize?key=${dotenv.env['GOOGLE_CLOUD_API_KEY']}'),
    headers: {
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'config': {
        'encoding': 'LINEAR16',
        'sampleRateHertz': 44100,
        'languageCode': 'en-US',
      },
      'audio': {
        'content': base64Audio,
      },
    }),
  );

  if (response.statusCode == 200) {
    final result = jsonDecode(response.body);
    return result['results'][0]['alternatives'][0]['transcript'];
  } else {
    print('Error: ${response.statusCode}');
    print('Response body: ${response.body}');
    return 'Failed to transcribe';
  }
}

