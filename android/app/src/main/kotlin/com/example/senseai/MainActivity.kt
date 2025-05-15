package com.example.senseai

import android.content.*
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var gadgetbridgeReceiver: BroadcastReceiver

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        gadgetbridgeReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "nodomain.freeyourgadget.gadgetbridge.BLE.GATT_CHARACTERISTIC_NOTIFICATION") {
                    val uuid = intent.getStringExtra("characteristic") ?: return
                    val value = intent.getByteArrayExtra("value") ?: return
                    val intValue = value[1].toInt() and 0xFF // adjust based on your device's byte format

                    MethodChannel(flutterEngine!!.dartExecutor.binaryMessenger, "gadgetbridge_channel")
                        .invokeMethod("onGattNotification", mapOf("uuid" to uuid, "value" to intValue))
                }
            }
        }

        val filter = IntentFilter("nodomain.freeyourgadget.gadgetbridge.BLE.GATT_CHARACTERISTIC_NOTIFICATION")
        registerReceiver(gadgetbridgeReceiver, filter)
    }

    override fun onDestroy() {
        super.onDestroy()
        unregisterReceiver(gadgetbridgeReceiver)
    }
}
