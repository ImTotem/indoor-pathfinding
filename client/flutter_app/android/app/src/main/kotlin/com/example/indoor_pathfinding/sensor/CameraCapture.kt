package com.example.indoor_pathfinding.sensor

import android.content.Context
import android.graphics.Bitmap
import android.hardware.camera2.CameraCharacteristics
import android.hardware.camera2.CameraManager
import android.util.Size
import android.view.Surface
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.indoor_pathfinding.rust_core.pushFrame
import io.flutter.view.TextureRegistry
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors

class CameraCapture(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var intrinsics: FloatArray? = null
    private var capturing = false
    private val analyzerExecutor = Executors.newSingleThreadExecutor()

    fun startPreview(entry: TextureRegistry.SurfaceTextureEntry) {
        this.textureEntry = entry
        val future = ProcessCameraProvider.getInstance(context)
        future.addListener({
            cameraProvider = future.get()
            extractIntrinsics(640, 480)
            bindCamera()
        }, ContextCompat.getMainExecutor(context))
    }

    fun startCapture() {
        capturing = true
        bindCamera()
    }

    fun stopCapture() {
        capturing = false
        bindCamera()
    }

    fun stopAll() {
        capturing = false
        cameraProvider?.unbindAll()
        textureEntry?.release()
        textureEntry = null
        cameraProvider = null
        analyzerExecutor.shutdown()
    }

    private fun bindCamera() {
        val provider = cameraProvider ?: return
        val entry = textureEntry ?: return
        provider.unbindAll()

        val preview = Preview.Builder().build()
        preview.surfaceProvider = Preview.SurfaceProvider { request ->
            val surfaceTexture = entry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(request.resolution.width, request.resolution.height)
            val surface = Surface(surfaceTexture)
            request.provideSurface(surface, ContextCompat.getMainExecutor(context)) {
                surface.release()
            }
        }

        val selector = CameraSelector.DEFAULT_BACK_CAMERA

        if (capturing) {
            val analysis = ImageAnalysis.Builder()
                .setTargetResolution(Size(640, 480))
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                .build()
            analysis.setAnalyzer(analyzerExecutor) { processFrame(it) }
            provider.bindToLifecycle(lifecycleOwner, selector, preview, analysis)
        } else {
            provider.bindToLifecycle(lifecycleOwner, selector, preview)
        }
    }

    private fun extractIntrinsics(w: Int, h: Int) {
        try {
            val cm = context.getSystemService(Context.CAMERA_SERVICE) as CameraManager
            val id = cm.cameraIdList.firstOrNull {
                cm.getCameraCharacteristics(it)
                    .get(CameraCharacteristics.LENS_FACING) == CameraCharacteristics.LENS_FACING_BACK
            } ?: return
            val chars = cm.getCameraCharacteristics(id)
            val cal = chars.get(CameraCharacteristics.LENS_INTRINSIC_CALIBRATION)
            if (cal != null && cal.size >= 4) {
                intrinsics = floatArrayOf(cal[0], cal[1], cal[2], cal[3])
                return
            }
            val fl = chars.get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)
            val ss = chars.get(CameraCharacteristics.SENSOR_INFO_PHYSICAL_SIZE)
            if (fl != null && fl.isNotEmpty() && ss != null) {
                intrinsics = floatArrayOf(fl[0] * w / ss.width, fl[0] * h / ss.height, w / 2f, h / 2f)
            }
        } catch (_: Exception) {
            intrinsics = floatArrayOf(w * 0.9f, h * 0.9f, w / 2f, h / 2f)
        }
    }

    private fun processFrame(proxy: ImageProxy) {
        try {
            val ts = proxy.imageInfo.timestamp / 1_000_000_000.0
            val png = toPng(proxy)
            val i = intrinsics ?: floatArrayOf(proxy.width * 0.9f, proxy.height * 0.9f, proxy.width / 2f, proxy.height / 2f)
            pushFrame(ts, png, i[0].toDouble(), i[1].toDouble(), i[2].toDouble(), i[3].toDouble())
        } finally {
            proxy.close()
        }
    }

    private fun toPng(proxy: ImageProxy): ByteArray {
        val w = proxy.width
        val h = proxy.height
        val buf = proxy.planes[0].buffer
        val rowStride = proxy.planes[0].rowStride
        val pixelStride = proxy.planes[0].pixelStride
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        if (rowStride == w * pixelStride) {
            bmp.copyPixelsFromBuffer(buf)
        } else {
            val row = ByteArray(rowStride)
            val px = IntArray(w)
            for (y in 0 until h) {
                buf.position(y * rowStride)
                buf.get(row, 0, minOf(rowStride, buf.remaining()))
                for (x in 0 until w) {
                    val off = x * pixelStride
                    px[x] = android.graphics.Color.argb(
                        row[off + 3].toInt() and 0xFF, row[off].toInt() and 0xFF,
                        row[off + 1].toInt() and 0xFF, row[off + 2].toInt() and 0xFF,
                    )
                }
                bmp.setPixels(px, 0, w, 0, y, w, 1)
            }
        }
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, out)
        bmp.recycle()
        return out.toByteArray()
    }
}
