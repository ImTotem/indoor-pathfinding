package com.example.indoor_pathfinding.bridge

import android.os.Handler
import android.os.Looper
import com.indoor_pathfinding.rust_core.EngineStatus
import com.indoor_pathfinding.rust_core.PoseResult
import com.indoor_pathfinding.rust_core.SessionState
import com.indoor_pathfinding.rust_core.getStatus
import io.flutter.plugin.common.EventChannel

class ResultBridge(
    private val sessionBridge: SessionBridge,
) : EventChannel.StreamHandler {
    private val handler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var polling = false

    private val pollRunnable = object : Runnable {
        override fun run() {
            if (!polling) return
            try {
                val status = getStatus()
                eventSink?.success(statusToMap(status))
            } catch (e: Exception) {
                eventSink?.error("POLL_ERROR", e.message, null)
            }
            handler.postDelayed(this, 100)
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
        polling = true
        handler.post(pollRunnable)
    }

    override fun onCancel(arguments: Any?) {
        polling = false
        handler.removeCallbacks(pollRunnable)
        eventSink = null
    }

    private fun statusToMap(status: EngineStatus): Map<String, Any?> {
        val stateStr = when (status.state) {
            SessionState.IDLE -> "idle"
            SessionState.MAPPING -> "mapping"
            SessionState.LOCALIZING -> "localizing"
            SessionState.ERROR -> "error"
        }

        val poseMap = status.pose?.let { pose: PoseResult ->
            mapOf(
                "x" to pose.x, "y" to pose.y, "z" to pose.z,
                "qx" to pose.qx, "qy" to pose.qy, "qz" to pose.qz, "qw" to pose.qw,
            )
        }

        val imu = sessionBridge.imuCollector
        val baro = sessionBridge.baroCollector

        val accel = imu?.displayAccel
        val gyro = imu?.displayGyro

        return mapOf(
            "state" to stateStr,
            "pose" to poseMap,
            "frameCount" to status.frameCount.toLong(),
            "totalPushed" to status.totalPushed.toLong(),
            "queueFull" to status.queueFull,
            "errorMessage" to status.errorMessage,
            "accel" to accel?.map { it.toDouble() },
            "gyro" to gyro?.map { it.toDouble() },
            "pressure" to baro?.displayPressure?.toDouble(),
        )
    }
}
