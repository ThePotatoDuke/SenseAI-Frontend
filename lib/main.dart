import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:camera/camera.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit_config.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

// Import Firebase Auth
import 'package:senseai/features/app/splash_screen/splash_screen.dart';
import 'package:senseai/features/user_auth/presentation/pages/chat_page.dart';
import 'package:senseai/features/user_auth/presentation/pages/home_page.dart';
import 'package:senseai/features/user_auth/presentation/pages/login_page.dart';
import 'package:senseai/features/user_auth/presentation/pages/main_screen.dart';
import 'package:senseai/features/user_auth/presentation/pages/sign_up_page.dart';
import 'package:senseai/features/user_auth/presentation/pages/video_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'features/user_auth/firebase_auth_implementation/auth_checker.dart'; // import dotenv

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
        theme: ThemeData.light(),
        darkTheme: ThemeData.dark(),
        themeMode: ThemeMode.system,
        // follows device dark/light mode
        title: 'SenseAI',
        debugShowCheckedModeBanner: false,
        home: AnimatedSplashScreen(
          duration: 1000,
          splash: 'assets/senseai_logo.png',
          nextScreen: MainScreen(),
          splashTransition: SplashTransition.fadeTransition,
          pageTransitionType: PageTransitionType.fade,
          // ✅ Safe choice
          backgroundColor: Colors.white,
          splashIconSize: 250,
        ));
  }
}
