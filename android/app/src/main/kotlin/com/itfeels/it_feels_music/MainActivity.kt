package com.itfeels.it_feels_music

import android.app.ActivityManager
import android.content.Context
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.itfeels.it_feels_music/device_info"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "isLowRamDevice") {
                val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                result.success(activityManager.isLowRamDevice)
            } else {
                result.notImplemented()
            }
        }
    }
}
