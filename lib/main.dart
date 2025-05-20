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
    // Define your color palette
    const Color primaryLight = Color(0xFF4A90E2); // Blue for light mode
    const Color primaryDark = Color(0xFF0A74DA);  // Optional unused dark blue
    const Color secondaryLight = Color(0xFF50E3C2);
    const Color secondaryDark = Color(0xFF7E57C2); // Purple for dark mode


    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryLight,
        colorScheme: ColorScheme.light(
          primary: primaryLight,
          primaryContainer: Color.lerp(primaryLight, Colors.white, 0.4)!, // Lighter blue
          secondary: secondaryLight,
          secondaryContainer: Color.lerp(secondaryLight, Colors.white, 0.4)!,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryLight,
          foregroundColor: Colors.white,
        ),
      ),

      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: secondaryDark, // Use teal instead of blue
        colorScheme: ColorScheme.dark(
          primary: secondaryDark,
          primaryContainer: Color.lerp(secondaryDark, Colors.black, 0.4)!, // Darker teal
          secondary: secondaryDark,
          secondaryContainer: Color.lerp(secondaryDark, Colors.black, 0.4)!,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: secondaryDark,
          foregroundColor: Colors.white,
        ),
      ),

      themeMode: ThemeMode.system,
      title: 'SenseAI',
      debugShowCheckedModeBanner: false,
      home: AnimatedSplashScreen(
        duration: 1000,
        splash: 'assets/senseai_logo.png',
        nextScreen: MainScreen(),
        splashTransition: SplashTransition.fadeTransition,
        pageTransitionType: PageTransitionType.fade,
        backgroundColor: Colors.white,
        splashIconSize: 250,
      ),
    );
  }
}

