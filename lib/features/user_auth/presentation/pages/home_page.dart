import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';


import 'chat_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}




// Your other imports...

class _HomePageState extends State<HomePage> {
  List<FlSpot> stressSpots = [];
  List<FlSpot> heartRateSpots = [];

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
        final stressLevel = data['stress'] ?? data['STRESS'];
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
      final heartRate = result[i]['heart_rate'] ?? result[i]['HEART_RATE'];
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

  Widget buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.show_chart, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildLineChartCard({
    required String title,
    required List<FlSpot> spots,
    required VoidCallback onRefresh,
    required List<Color> gradientColors,
  }) {
    return Neumorphic(
      style: NeumorphicStyle(
        depth: -6,
        intensity: 0.8,
        color: Theme.of(context).cardColor,
        boxShape: NeumorphicBoxShape.roundRect(BorderRadius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.headlineSmall?.color,
              ),
            ),
            const SizedBox(height: 16),

            // Your actual FL Chart goes here
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      gradient: LinearGradient(colors: gradientColors),
                      barWidth: 3,
                      dotData: FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: gradientColors
                              .map((color) => color.withOpacity(0.3))
                              .toList(),
                        ),
                      ),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),

            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRefresh,
              icon: Icon(Icons.refresh, color: Colors.white), // icon color explicitly white
              label: Text(
                'Refresh',
                style: TextStyle(color: Colors.white), // text color explicitly white
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,  // explicitly set text/icon color here
              ),
            ),

          ],
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
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(

                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            Colors.purple.shade700,
                            Colors.purpleAccent.shade100,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(chatId: randomString()),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat, color: Colors.white),

                        label: const Text('Go to Chat'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent, // Make button background transparent
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: Colors.white, // White text & icon on purple gradient
                          textStyle: const TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  )

                ),
                const SizedBox(height: 32),
                buildSectionTitle('Stress Chart'),
                buildLineChartCard(
                  title: 'Stress',
                  spots: stressSpots,
                  onRefresh: refreshData,
                  gradientColors: [Colors.blueAccent, Colors.cyan],
                ),
                const SizedBox(height: 32),
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
      ),
    );
  }
}



