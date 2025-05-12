import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

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


  Future<String> sendMultipartRequest(String text) async {
    // 1. Use the correct URL (same one that worked in curl)
    final uri = Uri.parse("https://a576-176-41-194-195.ngrok-free.app/analyze/full");

    // 2. Create the multipart request
    var request = http.MultipartRequest('POST', uri);

    // 3. Add text field
    request.fields['text'] = text;

    // 4. Add minimal placeholder image (1x1 pixel PNG)
    final imageBytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00,
      0x0C, 0x49, 0x44, 0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
      0x00, 0x05, 0xFE, 0x02, 0xFE, 0xDC, 0xCC, 0x59, 0x00, 0x00, 0x00, 0x00,
      0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);
    request.files.add(http.MultipartFile.fromBytes(
      'image',
      imageBytes,
      filename: 'placeholder.png',
    ));

    // 5. Add minimal placeholder audio (silent WAV)
    final audioBytes = Uint8List.fromList([
      0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x41, 0x56, 0x45,
      0x66, 0x6D, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
      0x44, 0xAC, 0x00, 0x00, 0x88, 0x58, 0x01, 0x00, 0x02, 0x00, 0x10, 0x00,
      0x64, 0x61, 0x74, 0x61, 0x00, 0x00, 0x00, 0x00
    ]);
    request.files.add(http.MultipartFile.fromBytes(
      'audio',
      audioBytes,
      filename: 'placeholder.wav',
    ));

    try {
      // 6. Add required headers (especially for ngrok)
      request.headers.addAll({
        'Content-Type': 'multipart/form-data',
        'Accept': 'application/json',
      });

      // 7. Send the request
      var response = await http.Response.fromStream(await request.send());

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['reply']; // Adjust based on your actual response structure
      } else {
        throw Exception('Server error: ${response.statusCode} - ${response.body}');
      }
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
