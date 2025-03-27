import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:senseai/features/user_auth/data/api_service.dart';
import 'package:test/test.dart';

import 'package:senseai/features/user_auth/presentation/pages/home_page.dart';

// Create a MockClient class
class MockHTTPClient extends Mock implements http.Client {}
class MockFile extends Mock implements File {}
class FakeBaseRequest extends Fake implements http.BaseRequest {}
class FakeMultipartRequest extends Fake implements http.MultipartRequest {}// i also tried it with this

void main() {
  setUpAll(() {
    registerFallbackValue(FakeBaseRequest()); // Register fallback for BaseRequest
  });

  late ApiService apiService;
  late MockHTTPClient mockHTTPClient;

  setUp(() {
    mockHTTPClient = MockHTTPClient();
    apiService = ApiService(mockHTTPClient);
  });

  group('sendText', () {
    test('returns a reply if the text sending http call completes successfully', () async {
      // Mock the client to return a successful response
      when(() => mockHTTPClient.post(
        Uri.parse('https://your-backend-url.com/api/text'),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer(
            (_) async => http.Response('{"reply": "This is a response"}', 200),
      );

      // Call the sendText function with the mocked client
      final result = await apiService.sendText('Hello');

      // Verify the result
      expect(result, 'This is a response');
    });

    test('throws an exception if the http call completes with an error when sending text', () async {
      // Mock the client to return an error response
      when(() => mockHTTPClient.post(
        Uri.parse('https://your-backend-url.com/api/text'),
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      )).thenAnswer(
            (_) async => http.Response('Not Found', 500),
      );

      // Expect that sendText throws an exception due to the error response
      expect(() => apiService.sendText('Hello'), throwsException);

      // Verify that the post request was made
      verify(() => mockHTTPClient.post(
        Uri.parse('https://your-backend-url.com/api/text'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'message': 'Hello'}),
      )).called(1);
    });
  });
  group("send image list", () {
    test("returns a reply if images are successfully sent", () async {
      // Mocking a successful response
      final responseStream = Stream.value(utf8.encode('{"reply": "This is a response"}'));
      final mockResponse = http.StreamedResponse(responseStream, 200);

      // Mock the send() method
      when(() => mockHTTPClient.send(any())).thenAnswer((_) async => mockResponse);

      // Mock files
      final mockFile1 = MockFile();
      final mockFile2 = MockFile();

      // Mock file behaviors
      when(() => mockFile1.openRead()).thenAnswer((_) => Stream.value([]));  // Use thenAnswer for Stream
      when(() => mockFile2.openRead()).thenAnswer((_) => Stream.value([]));  // Use thenAnswer for Stream
      when(() => mockFile1.length()).thenAnswer((_) async => 100);   // Fake size
      when(() => mockFile2.length()).thenAnswer((_) async => 200);   // Fake size
      when(() => mockFile1.path).thenReturn("test1.png");
      when(() => mockFile2.path).thenReturn("test2.png");

      // Call sendImages
      final result = await apiService.sendImages([mockFile1, mockFile2]);

      // Verify the result
      expect(result, 'This is a response');

      // Verify that send was called
      verify(() => mockHTTPClient.send(any())).called(1);
    });

    test("throws an exception if the server returns an error", () async {
      // Mocking an error response
      final errorStream = Stream.value(utf8.encode('{"error": "Internal Server Error"}'));
      final mockErrorResponse = http.StreamedResponse(errorStream, 500);

      // Mock the send() method to return the error response
      when(() => mockHTTPClient.send(any())).thenAnswer((_) async => mockErrorResponse);

      // Mock files
      final mockFile1 = MockFile();
      final mockFile2 = MockFile();

      // Mock file behaviors
      when(() => mockFile1.openRead()).thenAnswer((_) => Stream.value([]));  // Use thenAnswer for Stream
      when(() => mockFile2.openRead()).thenAnswer((_) => Stream.value([]));  // Use thenAnswer for Stream
      when(() => mockFile1.length()).thenAnswer((_) async => 100);   // Fake size
      when(() => mockFile2.length()).thenAnswer((_) async => 200);   // Fake size
      when(() => mockFile1.path).thenReturn("test1.png");
      when(() => mockFile2.path).thenReturn("test2.png");

      // Call sendImages and expect an exception
      try {
        await apiService.sendImages([mockFile1, mockFile2]);
        fail('Exception was not thrown'); // If no exception is thrown, fail the test
      } catch (e) {
        // Verify that the exception is thrown
        expect(e, isA<Exception>());
      }

      // Verify that send was called (it should be called even if the exception occurs)
      verify(() => mockHTTPClient.send(any())).called(1);
    });

  });
}

