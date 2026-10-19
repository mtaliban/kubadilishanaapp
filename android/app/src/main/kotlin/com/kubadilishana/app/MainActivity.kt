package com.kubadilishana.app

import android.content.Intent
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // ── BATTERY OPTIMIZATION (Doze/App-standby whitelist) ──────────────────
    // Sababu: simu nyingi (Hasa MIUI/Oppo/Samsung "Put unused apps to sleep")
    // zinazima background apps — FCM push HAIKIFIKI wakati app inyimafunguliwa
    // (kasoro halisi: badge kwenye DB, arifa hapana — mpaka ufungue app).
    // App inaomba system dialog ya "Ruhusu kufanya kazi bila optimization" —
    // mara mbili tu, na user akitaka ewake kwenye whitelist kwenye Mipangilio.
    private val batteryChannel = "kubadilishana/battery"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, batteryChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(!pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            // @Suppress: Android inadefault-dialog ya mfumo wenyewe —
                            // hii ndiyo njia rasmi ya App-standby exemption.
                            @Suppress("BatteryLife")
                            val intent = Intent(
                                Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                Uri.parse("package:$packageName"),
                            )
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
