package com.example.indoor_pathfinding

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.example.indoor_pathfinding/orientation")
            .setMethodCallHandler { call, result ->
                if (call.method == "getRotation") {
                    @Suppress("DEPRECATION")
                    val rotation = windowManager.defaultDisplay.rotation
                    result.success(rotation)
                } else {
                    result.notImplemented()
                }
            }
    }
}
