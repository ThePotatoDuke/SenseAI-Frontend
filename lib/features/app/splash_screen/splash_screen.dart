import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "SenseAI",
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }

  void _checkAuthentication() async {
    // Delay for a short period to simulate splash screen
    await Future.delayed(Duration(seconds: 2));

    // Check if a user is logged in
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // Navigate to HomePage if user is logged in
      Navigator.pushReplacementNamed(context, '/main');
    } else {
      // Navigate to LoginPage if user is not logged in
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
}
