import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

import '../../../utils/globals.dart';
import '../widgets/line_chart_widget.dart';
import 'chat_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {


  Future<void> _sendIntent(String action, {Map<String, dynamic>? extras}) async {
    final intent = AndroidIntent(
      action: action,
      package: 'nodomain.freeyourgadget.gadgetbridge',
      flags: <int>[Flag.FLAG_INCLUDE_STOPPED_PACKAGES],
      arguments: extras,
    );
    try {
      await intent.sendBroadcast();
    } catch (e) {
      debugPrint("Error sending intent: $e");
    }
  }

  Future<void> refreshData() async {
    await _sendIntent(
      'nodomain.freeyourgadget.gadgetbridge.command.ACTIVITY_SYNC',
      extras: {'dataTypesHex': '0x00000040'},
    );
    await Future.delayed(const Duration(seconds: 2));
    await _sendIntent(
      'nodomain.freeyourgadget.gadgetbridge.command.TRIGGER_EXPORT',
    );
    await Future.delayed(const Duration(seconds: 2));

    await fetchStressData();
    await fetchHeartRateData();
  }

  Future<void> fetchStressData() async {
    if (await Permission.manageExternalStorage.isGranted) {
      final path = '/storage/emulated/0/Download/Gadgetbridge.db';
      final file = File(path);
      if (!await file.exists()) throw Exception('Database not found at $path');

      final db = await openDatabase(path);
      final result = await db.rawQuery('''
        SELECT timestamp, datetime(timestamp / 1000, 'unixepoch') AS readable_time, stress 
        FROM HUAMI_STRESS_SAMPLE 
        ORDER BY timestamp ASC 
        LIMIT 8;
      ''');
      await db.close();

      stressSpots.clear();
      for (var i = 0; i < result.length; i++) {
        final data = result[i];
        final stressLevel = data['STRESS'];
        if (stressLevel != null) {
          stressSpots.add(FlSpot(i.toDouble(), (stressLevel as int).toDouble()));
        }
      }

      setState(() {});
    } else {
      await Permission.manageExternalStorage.request();
    }
  }

  Future<void> fetchHeartRateData() async {
    final path = '/storage/emulated/0/Download/Gadgetbridge.db';
    final file = File(path);
    if (!await file.exists()) throw Exception('Database not found at $path');

    final db = await openDatabase(path);
    final result = await db.rawQuery('''
      SELECT timestamp, datetime(timestamp / 1000, 'unixepoch') AS readable_time, heart_rate 
      FROM MI_BAND_ACTIVITY_SAMPLE 
      WHERE heart_rate <> 255 AND heart_rate <> 0 
      ORDER BY timestamp ASC 
      LIMIT 8;
    ''');
    await db.close();

    heartRateSpots.clear();
    for (var i = 0; i < result.length; i++) {
      final heartRate = result[i]['HEART_RATE'];
      if (heartRate != null) {
        heartRateSpots.add(FlSpot(i.toDouble(), (heartRate as int).toDouble()));
      }
    }

    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    fetchStressData();
    fetchHeartRateData();
  }

  Widget buildSectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onBackground,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardColor = Theme.of(context).cardColor;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                color: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: Center(
                    child: Text(
                      'Welcome User!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ChatPage()),
                    );
                  },
                  icon: const Icon(
                    Icons.chat,
                    color: Colors.white, // Set the color of the icon here
                  ),
                  label: const Text('Go to Chat'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                ),

              ),
              const SizedBox(height: 28),
              buildSectionTitle('Stress Chart'),
              buildLineChartCard(
                title: 'Stress',
                spots: stressSpots,
                onRefresh: refreshData,
                gradientColors: [Colors.blueAccent, Colors.cyan],
              ),
              const SizedBox(height: 28),
              buildSectionTitle('Heart Rate Chart'),
              buildLineChartCard(
                title: 'Heart Rate',
                spots: heartRateSpots,
                onRefresh: refreshData,
                gradientColors: [Colors.redAccent, Colors.orange],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
