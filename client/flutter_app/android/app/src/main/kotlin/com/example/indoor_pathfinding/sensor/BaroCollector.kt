package com.example.indoor_pathfinding.sensor

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import com.indoor_pathfinding.rust_core.pushBarometer

class BaroCollector(context: Context) {
    private val sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val barometer = sensorManager.getDefaultSensor(Sensor.TYPE_PRESSURE)

    // HUD 표시용
    @Volatile var displayPressure: Float = 0f
        private set

    private val listener = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent) {
            displayPressure = event.values[0]
            val timestamp = event.timestamp / 1_000_000_000.0
            pushBarometer(timestamp, event.values[0].toDouble())
        }
        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    fun start() {
        barometer?.let {
            sensorManager.registerListener(listener, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    fun stop() {
        sensorManager.unregisterListener(listener)
    }
}
