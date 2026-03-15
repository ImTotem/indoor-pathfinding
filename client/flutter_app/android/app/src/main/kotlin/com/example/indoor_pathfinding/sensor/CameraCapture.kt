package com.example.indoor_pathfinding.sensor

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.ImageFormat
import android.graphics.Matrix
import android.graphics.Rect
import android.graphics.YuvImage
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
import java.util.concurrent.Executors

class CameraCapture(
    private val context: Context,
    private val lifecycleOwner: LifecycleOwner,
) {
    private var cameraProvider: ProcessCameraProvider? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var intrinsics: FloatArray? = null
    private val analyzerExecutor = Executors.newSingleThreadExecutor()

    @Volatile var capturing = false
    @Volatile var flipImage = false // 왼손 모드일 때 180° 회전

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
    }

    fun stopCapture() {
        capturing = false
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

        val preview = Preview.Builder()
            .setTargetResolution(Size(1920, 1080))
            .build()
        preview.surfaceProvider = Preview.SurfaceProvider { request ->
            val surfaceTexture = entry.surfaceTexture()
            surfaceTexture.setDefaultBufferSize(request.resolution.width, request.resolution.height)
            val surface = Surface(surfaceTexture)
            request.provideSurface(surface, ContextCompat.getMainExecutor(context)) {
                surface.release()
            }
        }

        // ImageAnalysis 항상 바인딩 — capturing 플래그로 전송 제어
        val analysis = ImageAnalysis.Builder()
            .setTargetResolution(Size(640, 480))
            .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
            .build() // YUV_420_888 기본 포맷

        analysis.setAnalyzer(analyzerExecutor) { proxy ->
            if (capturing) {
                processFrame(proxy)
            } else {
                proxy.close()
            }
        }

        val selector = CameraSelector.DEFAULT_BACK_CAMERA
        provider.bindToLifecycle(lifecycleOwner, selector, preview, analysis)
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
            var jpeg = yuvToJpeg(proxy)
            if (flipImage) {
                jpeg = rotateJpeg(jpeg, 180f)
            }
            val i = intrinsics ?: floatArrayOf(
                proxy.width * 0.9f, proxy.height * 0.9f,
                proxy.width / 2f, proxy.height / 2f,
            )
            pushFrame(ts, jpeg, i[0].toDouble(), i[1].toDouble(), i[2].toDouble(), i[3].toDouble())
        } finally {
            proxy.close()
        }
    }

    private fun rotateJpeg(jpeg: ByteArray, degrees: Float): ByteArray {
        val bmp = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)
        val matrix = Matrix().apply { postRotate(degrees) }
        val rotated = Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, matrix, true)
        bmp.recycle()
        val out = ByteArrayOutputStream()
        rotated.compress(Bitmap.CompressFormat.JPEG, 95, out)
        rotated.recycle()
        return out.toByteArray()
    }

    private fun yuvToJpeg(proxy: ImageProxy): ByteArray {
        val yBuffer = proxy.planes[0].buffer
        val uBuffer = proxy.planes[1].buffer
        val vBuffer = proxy.planes[2].buffer

        val ySize = yBuffer.remaining()
        val uSize = uBuffer.remaining()
        val vSize = vBuffer.remaining()

        val nv21 = ByteArray(ySize + uSize + vSize)
        yBuffer.get(nv21, 0, ySize)
        vBuffer.get(nv21, ySize, vSize)
        uBuffer.get(nv21, ySize + vSize, uSize)

        val yuvImage = YuvImage(nv21, ImageFormat.NV21, proxy.width, proxy.height, null)
        val out = ByteArrayOutputStream()
        yuvImage.compressToJpeg(Rect(0, 0, proxy.width, proxy.height), 95, out)
        return out.toByteArray()
    }
}
