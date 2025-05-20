import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:senseai/features/user_auth/presentation/pages/login_page.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({Key? key}) : super(key: key);

  void _signOut(BuildContext context) async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
    Fluttertoast.showToast(msg: "Successfully signed out");
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Use theme colors dynamically
    final primaryColor = theme.colorScheme.primary;
    final primaryLightColor = theme.colorScheme.primaryContainer;
    final primaryDarkColor = theme.colorScheme.primaryContainer;

    // Text color depending on brightness
    final textColor = theme.textTheme.bodyLarge?.color ?? (isDark ? Colors.white : Colors.black87);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings",style: TextStyle(color: NeumorphicColors.darkDefaultTextColor),),
        centerTitle: true,
        backgroundColor: theme.appBarTheme.backgroundColor ?? primaryColor,
        elevation: 2,
      ),
      body: Stack(
        children: [
          WaveWidget(
            config: CustomConfig(
              gradients: [
                [
                  primaryColor.withAlpha((0.6 * 255).round()),
                  primaryLightColor.withAlpha((0.3 * 255).round()),
                ],
                [
                  primaryColor.withAlpha((0.3 * 255).round()),
                  primaryLightColor.withAlpha((0.1 * 255).round()),
                ],
                [
                  primaryDarkColor.withAlpha((0.4 * 255).round()),
                  primaryColor.withAlpha((0.15 * 255).round()),
                ],
              ],
              durations: const [35000, 16000],
              heightPercentages: const [0.40, 0.43],
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
                  color: isDark
                      ? theme.colorScheme.secondary
                      : Colors.deepPurple.shade400,
                ),
                const SizedBox(height: 24),
                Text(
                  "Manage your account and preferences",
                  style: TextStyle(
                    fontSize: 18,
                    color: textColor,
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
                    icon: Icon(
                      Icons.logout,
                      size: 24,
                      color: theme.colorScheme.onPrimary,
                    ),
                    label: Text(
                      "Sign Out",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent, // You can customize for dark theme here too
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
