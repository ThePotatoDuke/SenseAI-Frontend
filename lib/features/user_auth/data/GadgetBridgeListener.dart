import 'package:flutter/services.dart';

class GadgetbridgeListener {
  static const MethodChannel _channel = MethodChannel('gadgetbridge_channel');

  static void startListening(void Function(String uuid, int value) onData) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onGattNotification') {
        final args = Map<String, dynamic>.from(call.arguments);
        final uuid = args['uuid'] as String;
        final value = args['value'] as int;
        onData(uuid, value);
      }
    });
  }
}
