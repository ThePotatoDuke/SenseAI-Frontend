import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// Import Firebase Auth
import 'package:senseai/features/app/splash_screen/splash_screen.dart';
import 'package:senseai/features/user_auth/presentation/pages/chat_page.dart';
import 'package:senseai/features/user_auth/presentation/pages/login_page.dart';
import 'package:senseai/features/user_auth/presentation/pages/main_screen.dart';
import 'package:senseai/features/user_auth/presentation/pages/sign_up_page.dart';
import 'package:senseai/features/user_auth/presentation/pages/video_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';  // import dotenv

List<CameraDescription> cameras = [];

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  cameras = await availableCameras();



  if (kIsWeb) {
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: "AIzaSyCsHDQtI9DItQgSqwy45_y2xG9tDGxuER8",
        appId: "1:540215271818:web:8b22d4aee01acdce862873",
        messagingSenderId: "540215271818",
        projectId: "flutter-firebase-9c136",
        // Your web Firebase config options
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  FFmpegKitConfig.enableLogCallback((log) {
    print(log.getMessage());
  });
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SenseAI',
      routes: {
        '/': (context) => SplashScreen(
              child: LoginPage(),
            ),
        '/login': (context) => LoginPage(),
        '/signUp': (context) => SignUpPage(),
        '/home': (context) => ChatPage(),
        '/camera': (context) => VideoScreen(cameras),
        '/main': (context) => MainScreen()
      },
    );
  }
}
