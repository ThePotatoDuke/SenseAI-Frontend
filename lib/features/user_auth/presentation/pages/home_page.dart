import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

import 'chat_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<String> stressData = [];

  // Function to request storage permission
  Future<void> requestStoragePermission() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      throw Exception("Storage permission not granted");
    }
  }

  // Function to get the stress data from the SQLite database
  Future<void> fetchStressData() async {
    if (await Permission.manageExternalStorage.isGranted) {
      final path = '/storage/emulated/0/Download/Gadgetbridge.db';

      final file = File(path);
      if (!await file.exists()) {
        throw Exception('Database file not found at $path');
      }

      final db = await openDatabase(path);

      final result = await db.rawQuery('''
      SELECT 
  timestamp,
  datetime(timestamp / 1000, 'unixepoch') AS readable_time,
  device_id,
  user_id,
  stress
FROM HUAMI_STRESS_SAMPLE
ORDER BY timestamp DESC
LIMIT 100;

    ''');

      await db.close();

      // Clear any previous data
      stressData.clear();

      // Add fetched data to the list
      for (var data in result) {
        final stressLevel = data['STRESS'];
        final readableTime = data['readable_time'];
        stressData.add("Stress Level: $stressLevel at $readableTime");
      }


      // Update the UI
      setState(() {});
    } else {
      // Request permission from the user
      await Permission.manageExternalStorage.request();
    }
  }

  @override
  void initState() {
    super.initState();
    fetchStressData(); // Fetch stress data when the page is loaded
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      key: const ValueKey('HomeScreen'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Welcome to Home!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ChatPage()),
              );
            },
            child: const Text('Go to Chat'),
          ),
          const SizedBox(height: 20),
          // Display the fetched stress data
          if (stressData.isNotEmpty)
            ...stressData.map((data) => Text(data)).toList()
          else if (stressData.isEmpty)
            Text("no data")
            ,

        ],
      ),
    );
  }
}
