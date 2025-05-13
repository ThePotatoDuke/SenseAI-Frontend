import 'dart:convert';
import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;

import '../../utils/globals.dart';

class ApiService {
  final http.Client client;

  ApiService(this.client);

  Future<String> sendText(String text) async {
    final url =
        Uri.parse("https://a576-176-41-194-195.ngrok-free.app/analyze/text");

    final response = await client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"text": text}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["reply"];
    } else {
      throw Exception("Failed to get response");
    }
  }

  Future<String> sendMultipartRequest({
    required String text,
    String? audioPath,
    List<File>? imageFiles,
  }) async {
    final uri =
        Uri.parse("https://5f6b-176-41-194-195.ngrok-free.app/analyze/full");
    var request = http.MultipartRequest('POST', uri);


    final stressLevels = stressSpots.map((spot) => spot.y.toInt()).toList();
    final stressJson = jsonEncode(stressLevels);
    request.fields['stress_array'] = stressJson;

    final heartRateLevels = heartRateSpots.map((spot) => spot.y.toInt()).toList();
    final heartRateJson = jsonEncode(heartRateLevels);
    request.fields['hr_array'] = heartRateJson;

    // 1. Add the text field (transcript)
    request.fields['text'] = text;

    // 2. Add the audio file if it exists
    if (audioPath != null && audioPath.isNotEmpty) {
      final audioFile = File(audioPath);
      if (await audioFile.exists()) {
        request.files.add(
          await http.MultipartFile.fromPath('audio_file', audioFile.path),
        );
      }
    }

    // 3. Add all resized frame images if any
    if (imageFiles != null && imageFiles.isNotEmpty) {
      for (final imageFile in imageFiles) {
        if (await imageFile.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath(
              'image[]',
              imageFile.path,
            ),
          );
        }
      }
    }

    // 4. Headers
    request.headers.addAll({
      'Accept': 'application/json',
    });

    // 5. Send the request
    try {
      final response = await http.Response.fromStream(await request.send());

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      return response.body; // Return the raw response body regardless of status
    } catch (e) {
      throw Exception('Request failed: $e');
    }

  }

  Future<String> sendImages(List<File> images) async {
    final url =
        Uri.parse("https://a576-176-41-194-195.ngrok-free.app/analyze/face");

    // Create a multipart request
    final request = http.MultipartRequest('POST', url)
      ..headers["Content-Type"] = "multipart/form-data";

    // Add each image to the request
    for (var image in images) {
      var imageStream = http.ByteStream(image.openRead());
      var imageLength = await image.length();
      var multipartFile = http.MultipartFile('image', imageStream, imageLength,
          filename: image.path.split('/').last);
      request.files.add(multipartFile);
    }

    // Use the client from the constructor to send the request
    final response = await client.send(request);

    // Check the response status
    if (response.statusCode == 200) {
      // Read the response body as a string
      final responseString = await response.stream.bytesToString();
      return jsonDecode(responseString)["reply"];
    } else {
      throw Exception("Failed to upload images");
    }
  }
}
