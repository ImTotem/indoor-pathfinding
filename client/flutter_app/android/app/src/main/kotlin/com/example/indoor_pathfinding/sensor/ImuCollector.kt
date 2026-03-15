package com.example.indoor_pathfinding.sensor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import com.indoor_pathfinding.rust_core.pushImu

class ImuCollector(context: Context) {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val gyroscope = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)

    @Volatile private var latestAccel: FloatArray? = null
    @Volatile private var latestGyro: FloatArray? = null

    // HUD 표시용 최신 값
    @Volatile var displayAccel: FloatArray = floatArrayOf(0f, 0f, 0f)
        private set
    @Volatile var displayGyro: FloatArray = floatArrayOf(0f, 0f, 0f)
        private set

    private val accelListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            latestAccel = event.values.clone()
            displayAccel = event.values.clone()
            trySendImu(event.timestamp)
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    private val gyroListener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            latestGyro = event.values.clone()
            displayGyro = event.values.clone()
            trySendImu(event.timestamp)
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    fun start() {
        accelerometer?.let {
            sensorManager.registerListener(accelListener, it, SensorManager.SENSOR_DELAY_GAME)
        }
        gyroscope?.let {
            sensorManager.registerListener(gyroListener, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    fun stop() {
        sensorManager.unregisterListener(accelListener)
        sensorManager.unregisterListener(gyroListener)
        latestAccel = null
        latestGyro = null
    }

    private fun trySendImu(timestampNs: Long) {
        val accel = latestAccel ?: return
        val gyro = latestGyro ?: return
        val timestamp = timestampNs / 1_000_000_000.0
        pushImu(
            timestamp,
            accel[0].toDouble(), accel[1].toDouble(), accel[2].toDouble(),
            gyro[0].toDouble(), gyro[1].toDouble(), gyro[2].toDouble(),
        )
    }
}
