import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../user_auth/presentation/pages/login_page.dart';
import '../../user_auth/presentation/pages/main_screen.dart';

class SplashScreen extends StatefulWidget {
  final Widget? child;
  const SplashScreen({super.key, this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    // Future.delayed(Duration(seconds: 2), () {
    //   Navigator.pushAndRemoveUntil(
    //       context,
    //       MaterialPageRoute(builder: (context) => widget.child!),
    //       (route) => false);
    // });
    super.initState();
    _checkAuthentication();
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/senseai_logo.jpg', // make sure this path is correct and asset added in pubspec.yaml
              width: 150,          // adjust size as you want
              height: 150,
              fit: BoxFit.contain,
            ),
            SizedBox(height: 24),

            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  void _checkAuthentication() async {
    await Future.delayed(Duration(seconds: 2));

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Navigate to MainScreen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => MainScreen()),
      );
    } else {
      // Navigate to LoginPage
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
      );
    }
  }

}
