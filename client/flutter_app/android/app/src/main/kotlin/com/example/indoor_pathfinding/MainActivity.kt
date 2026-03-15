package com.example.indoor_pathfinding

import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.view.OrientationEventListener
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.example.indoor_pathfinding.bridge.CameraBridge
import com.example.indoor_pathfinding.bridge.ResultBridge
import com.example.indoor_pathfinding.bridge.SessionBridge
import com.indoor_pathfinding.rust_core.initEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val GATEWAY_ENDPOINT = "http://100.78.78.37:50051"
        private const val CAMERA_PERMISSION_CODE = 1001
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        requestCameraPermission()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        System.loadLibrary("rust_core")
        initEngine(GATEWAY_ENDPOINT)

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // 디바이스 물리 방향 (가속도 기반, 자동회전 설정 무관)
        EventChannel(messenger, "com.example.indoor_pathfinding/device_orientation")
            .setStreamHandler(object : EventChannel.StreamHandler {
                var listener: OrientationEventListener? = null
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    var cur = -1
                    listener = object : OrientationEventListener(this@MainActivity) {
                        override fun onOrientationChanged(deg: Int) {
                            if (deg == ORIENTATION_UNKNOWN) return
                            val bucket = when {
                                deg in 45..134 -> 90
                                deg in 135..224 -> 180
                                deg in 225..314 -> 270
                                else -> 0
                            }
                            if (bucket != cur) { cur = bucket; events?.success(bucket) }
                        }
                    }
                    listener?.enable()
                }
                override fun onCancel(arguments: Any?) {
                    listener?.disable(); listener = null
                }
            })

        // 카메라 프리뷰
        val cameraBridge = CameraBridge(this, this, flutterEngine.renderer)
        MethodChannel(messenger, "com.example.indoor_pathfinding/camera")
            .setMethodCallHandler(cameraBridge)

        // 세션 관리
        val sessionBridge = SessionBridge(this, cameraBridge)
        MethodChannel(messenger, "com.example.indoor_pathfinding/session")
            .setMethodCallHandler(sessionBridge)

        // 엔진 상태 (센서 데이터 포함)
        EventChannel(messenger, "com.example.indoor_pathfinding/engine_status")
            .setStreamHandler(ResultBridge(sessionBridge))
    }

    private fun requestCameraPermission() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), CAMERA_PERMISSION_CODE)
        }
    }
}
