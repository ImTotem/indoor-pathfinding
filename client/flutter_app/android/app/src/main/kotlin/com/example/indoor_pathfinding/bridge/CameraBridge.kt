package com.example.indoor_pathfinding.bridge

import android.app.Activity
import android.content.Context
import android.content.pm.ActivityInfo
import androidx.lifecycle.LifecycleOwner
import com.example.indoor_pathfinding.sensor.CameraCapture
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

class CameraBridge(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
    private val textureRegistry: TextureRegistry,
) : MethodChannel.MethodCallHandler {

    private var capture: CameraCapture? = null
    private var entry: TextureRegistry.SurfaceTextureEntry? = null

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "startPreview" -> {
                capture?.stopAll()
                val e = textureRegistry.createSurfaceTexture()
                entry = e
                val c = CameraCapture(context, lifecycleOwner)
                capture = c
                c.startPreview(e)
                result.success(e.id())
            }
            "stopPreview" -> {
                capture?.stopAll()
                capture = null
                entry = null
                result.success(null)
            }
            "setFlip" -> {
                val flip = call.argument<Boolean>("flip") ?: false
                capture?.flipImage = flip
                result.success(null)
            }
            "setSensorLandscape" -> {
                (context as Activity).requestedOrientation =
                    ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                result.success(null)
            }
            "resetOrientation" -> {
                (context as Activity).requestedOrientation =
                    ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    fun startCapture() = capture?.startCapture()
    fun stopCapture() = capture?.stopCapture()
    fun setLeftHanded(left: Boolean) { capture?.flipImage = left }
}
