import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  final http.Client client;
  ApiService(this.client);

  Future<String> sendText(String text) async {
    final url = Uri.parse("https://your-backend-url.com/api/text");

    final response = await client.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"message": text}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body)["reply"];
    } else {
      throw Exception("Failed to get response");
    }
  }
  Future<String> sendImages(List<File> images) async {
    final url = Uri.parse("https://your-backend-url.com/api/images");

    // Create a multipart request
    final request = http.MultipartRequest('POST', url)
      ..headers["Content-Type"] = "multipart/form-data";

    // Add each image to the request
    for (var image in images) {
      var imageStream = http.ByteStream(image.openRead());
      var imageLength = await image.length();
      var multipartFile = http.MultipartFile('images', imageStream, imageLength,
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