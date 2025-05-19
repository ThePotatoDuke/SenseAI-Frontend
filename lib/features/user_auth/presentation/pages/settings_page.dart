import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:senseai/features/user_auth/presentation/pages/login_page.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart'; // Adjust import path if needed

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  void _signOut(BuildContext context) async {
    await GoogleSignIn().signOut(); // this clears the cached account
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
    Fluttertoast.showToast(msg: "Successfully signed out");
  }



  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color primaryLightColor =
        Theme.of(context).primaryColorLight; // or a lighter variant
    final Color primaryDarkColor =
        Theme.of(context).primaryColorDark; // or a darker variant
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
        backgroundColor: Colors.deepPurple,
        elevation: 2,
      ),
      body: Stack(
        children: [
          WaveWidget(
            config: CustomConfig(
              gradients: [
                [
                  primaryColor.withAlpha((0.6 * 255).round()),
                  // 0.6 opacity
                  primaryLightColor.withAlpha((0.3 * 255).round()),
                  // 0.3 opacity
                ],
                [
                  primaryColor.withAlpha((0.3 * 255).round()),
                  // 0.3 opacity
                  primaryLightColor.withAlpha((0.1 * 255).round()),
                  // 0.1 opacity
                ],
                [
                  primaryDarkColor.withAlpha((0.4 * 255).round()),
                  // 0.4 opacity
                  primaryColor.withAlpha((0.15 * 255).round()),
                  // 0.15 opacity
                ],
              ],
              durations: [35000, 16000],
              heightPercentages: [0.40, 0.43],
              blur: const MaskFilter.blur(BlurStyle.solid, 10),
              gradientBegin: Alignment.bottomLeft,
              gradientEnd: Alignment.topRight,
            ),
            waveAmplitude: 20,
            size: const Size(double.infinity, double.infinity),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.settings,
                  size: 100,
                  color: Colors.deepPurple.shade400,
                ),
                const SizedBox(height: 24),
                const Text(
                  "Manage your account and preferences",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () => _signOut(context),
                    icon: const Icon(Icons.logout, size: 24,color:Colors.white ,),
                    label: const Text(
                      "Sign Out",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,  // <-- add this
                      ),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
