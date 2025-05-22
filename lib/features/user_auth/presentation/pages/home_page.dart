import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_neumorphic_plus/flutter_neumorphic.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sqflite/sqflite.dart';

import '../../../utils/globals.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

// Your other imports...

class _HomePageState extends State<HomePage> {
  List<FlSpot> stressSpots = [];
  List<FlSpot> heartRateSpots = [];

  Future<void> _sendIntent(String action,
      {Map<String, dynamic>? extras}) async {
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
    bool granted = await requestStoragePermission();
    if (!granted) {
      // Handle permission denial gracefully, e.g. show a message or return early
      print('Storage permission denied. Cannot refresh data.');
      return;
    }

    // Permission granted, continue with refresh
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


  Future<bool> requestStoragePermission() async {
    // For Android 11+ (API 30+), you might want MANAGE_EXTERNAL_STORAGE:
    if (await Permission.manageExternalStorage.isGranted) {
      return true;
    }

    // Request permission
    final status = await Permission.manageExternalStorage.request();

    if (status.isGranted) {
      return true;
    } else {
      // permission denied (or permanently denied)
      return false;
    }
  }

  Future<void> fetchStressData() async {
    final path = '/storage/emulated/0/Download/Gadgetbridge.db';
    final file = File(path);
    if (!await file.exists()) throw Exception('Database not found at $path');

    final nowMillis = DateTime.now().millisecondsSinceEpoch;
    final tenMinutesAgoMillis = nowMillis - (10 * 60 * 1000);

    final db = await openDatabase(path);
    final result = await db.rawQuery('''
    SELECT *
FROM (
  SELECT 
    timestamp, 
    datetime(timestamp / 1000, 'unixepoch') AS readable_time, 
    stress 
  FROM HUAMI_STRESS_SAMPLE 
  ORDER BY timestamp DESC 
  LIMIT 8
) AS recent
ORDER BY timestamp ASC;

  ''');
    print('Query result: $result');
    await db.close();

    stressSpots.clear();

    for (var i = 0; i < result.length; i++) {
      final stressRaw = result[i]['stress'] ?? result[i]['STRESS'];
      if (stressRaw != null) {
        final int? stress =
            stressRaw is int ? stressRaw : int.tryParse(stressRaw.toString());
        if (stress != null) {
          stressSpots.add(FlSpot(i.toDouble(), stress.toDouble()));
        }
      }
    }

    if (result.isNotEmpty) {
      final row = result[result.length - 1];
      final recentTimestampRaw = row['timestamp'] ?? row['TIMESTAMP'];
      final int? recentTimestamp = recentTimestampRaw is int
          ? recentTimestampRaw
          : int.tryParse(recentTimestampRaw.toString());

      if (recentTimestamp != null && recentTimestamp > tenMinutesAgoMillis) {
        recentStressSpots.clear();

        for (var data in result) {
          final tsRaw = data['timestamp'] ?? data['TIMESTAMP'];

          final int? ts = tsRaw is int ? tsRaw : int.tryParse(tsRaw.toString());

          if (ts != null && ts > tenMinutesAgoMillis) {
            final stressRaw = data['stress'] ?? data['STRESS'];
            final int? stress = stressRaw is int
                ? stressRaw
                : int.tryParse(stressRaw.toString());

            if (stress != null) {
              final xValue = (ts - tenMinutesAgoMillis) / 1000;
              recentStressSpots.add(FlSpot(xValue, stress.toDouble()));
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> fetchHeartRateData() async {
    final path = '/storage/emulated/0/Download/Gadgetbridge.db';
    final file = File(path);
    if (!await file.exists()) throw Exception('Database not found at $path');

    final nowSecs = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final tenMinutesAgoSecs = nowSecs - (10 * 60);

    final db = await openDatabase(path);
    final result = await db.rawQuery('''
      -- get the 8 most recent rows
SELECT *
FROM (
  SELECT
    timestamp,
    datetime(datetime(timestamp, 'unixepoch')
) AS readable_time,
    heart_rate
  FROM MI_BAND_ACTIVITY_SAMPLE
  WHERE heart_rate NOT IN (0,255)
  ORDER BY timestamp DESC
  LIMIT 8
) AS recent
-- now sort them ascending for plotting
ORDER BY timestamp ASC;

    ''');
    await db.close();

    heartRateSpots.clear();

    for (var i = 0; i < result.length; i++) {
      final heart_rateRaw = result[i]['heart_rate'] ?? result[i]['HEART_RATE'];
      if (heart_rateRaw != null) {
        final int? heart_rate = heart_rateRaw is int
            ? heart_rateRaw
            : int.tryParse(heart_rateRaw.toString());
        if (heart_rate != null) {
          heartRateSpots.add(FlSpot(i.toDouble(), heart_rate.toDouble()));
        }
      }
    }

    if (result.isNotEmpty) {
      final row = result[result.length - 1]; // newest sample
      final recentTimestampRaw = row['timestamp'] ?? row['TIMESTAMP'];
      final int? recentTimestamp = recentTimestampRaw is int
          ? recentTimestampRaw
          : int.tryParse(recentTimestampRaw.toString());

      if (recentTimestamp != null && recentTimestamp > tenMinutesAgoSecs) {
        recentHeartRateSpots.clear();

        for (var data in result) {
          final tsRaw = data['timestamp'] ?? data['TIMESTAMP'];
          final int? ts = tsRaw is int ? tsRaw : int.tryParse(tsRaw.toString());

          if (ts != null && ts > tenMinutesAgoSecs) {
            final heart_rateRaw = data['heart_rate'] ?? data['HEART_RATE'];
            final int? heart_rate = heart_rateRaw is int
                ? heart_rateRaw
                : int.tryParse(heart_rateRaw.toString());

            if (heart_rate != null) {
              final xValue = (ts - tenMinutesAgoSecs).toDouble();
              recentHeartRateSpots.add(FlSpot(xValue, heart_rate.toDouble()));
            }
          }
        }
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    fetchStressData();
    fetchHeartRateData();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await refreshData();
    });
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
              child: spots.isEmpty
                  ? Center(
                      child: Text(
                        'No data available',
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 16,
                        ),
                      ),
                    )
                  : LineChart(
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
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 5,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                final yValues =
                                    spots.map((s) => s.y.round()).toSet();
                                const tolerance = 0.01;
                                final isSpotValue = yValues
                                    .any((y) => (y - value).abs() < tolerance);
                                if (!isSpotValue)
                                  return const SizedBox.shrink();
                                return Text(
                                  value.toStringAsFixed(0),
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.color,
                                    fontSize: 12,
                                  ),
                                  textAlign: TextAlign.center,
                                );
                              },
                            ),
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
              icon: Icon(Icons.refresh, color: Colors.white),
              // icon color explicitly white
              label: Text(
                'Refresh',
                style: TextStyle(
                    color: Colors.white), // text color explicitly white
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor:
                    Colors.white, // explicitly set text/icon color here
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(height: 12),
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
