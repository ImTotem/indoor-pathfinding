package com.example.indoor_pathfinding.bridge

import android.content.Context
import com.example.indoor_pathfinding.sensor.BaroCollector
import com.example.indoor_pathfinding.sensor.ImuCollector
import com.indoor_pathfinding.rust_core.startLocalizationSession
import com.indoor_pathfinding.rust_core.startMappingSession
import com.indoor_pathfinding.rust_core.stopSession
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID

class SessionBridge(
    private val context: Context,
    private val cameraBridge: CameraBridge,
) : MethodChannel.MethodCallHandler {

    var imuCollector: ImuCollector? = null
        private set
    var baroCollector: BaroCollector? = null
        private set

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startMapping" -> {
                val mapId = call.argument<String>("mapId")
                if (mapId == null) {
                    result.error("INVALID_ARG", "mapId is required", null)
                    return
                }
                startMapping(mapId, result)
            }
            "startLocalization" -> {
                val mapId = call.argument<String>("mapId")
                if (mapId == null) {
                    result.error("INVALID_ARG", "mapId is required", null)
                    return
                }
                startLocalization(mapId, result)
            }
            "stopSession" -> stopCurrentSession(result)
            else -> result.notImplemented()
        }
    }

    private fun startMapping(mapId: String, result: MethodChannel.Result) {
        try {
            val sessionId = UUID.randomUUID().toString()
            startMappingSession(sessionId, mapId)
            cameraBridge.startCapture()
            imuCollector = ImuCollector(context).also { it.start() }
            baroCollector = BaroCollector(context).also { it.start() }
            result.success(sessionId)
        } catch (e: Exception) {
            result.error("SESSION_ERROR", e.message, null)
        }
    }

    private fun startLocalization(mapId: String, result: MethodChannel.Result) {
        try {
            val sessionId = UUID.randomUUID().toString()
            startLocalizationSession(sessionId, mapId)
            cameraBridge.startCapture()
            baroCollector = BaroCollector(context).also { it.start() }
            result.success(sessionId)
        } catch (e: Exception) {
            result.error("SESSION_ERROR", e.message, null)
        }
    }

    private fun stopCurrentSession(result: MethodChannel.Result) {
        try {
            cameraBridge.stopCapture()
            imuCollector?.stop()
            baroCollector?.stop()
            imuCollector = null
            baroCollector = null
            stopSession()
            result.success(null)
        } catch (e: Exception) {
            result.error("SESSION_ERROR", e.message, null)
        }
    }
}
