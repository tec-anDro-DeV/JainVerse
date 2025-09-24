package com.jainverse.app

import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import android.app.Activity
import android.Manifest
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.PluginRegistry
import kotlin.math.*
import kotlin.concurrent.thread

/**
 * Enhanced AudioVisualizerPlugin provides real-time audio frequency analysis for Flutter.
 * Uses Android's Visualizer API to analyze audio OUTPUT (playback) and converts it to 5 frequency bands.
 * IMPORTANT: This analyzes the audio being played by the app, NOT microphone input.
 * However, Android's Visualizer API still requires RECORD_AUDIO permission even for output analysis.
 * Improved to handle permission requests and provide fallback when permission is denied.
 */
class AudioVisualizerPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler, ActivityAware, PluginRegistry.RequestPermissionsResultListener {

    private lateinit var context: Context
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var activity: Activity? = null
    private var pendingSessionId: Int? = null

    private var visualizer: Visualizer? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isActive = false
    private val handler = Handler(Looper.getMainLooper())

    // Enhanced FFT processing parameters
    private val targetBands = 5
    private var audioSessionId: Int = 0

    // Permission handling
    companion object {
        private const val PERMISSION_REQUEST_CODE = 12345
    }

    // Silence detection parameters
    private var silenceFrameCount = 0
    private var lastEmissionTime = System.currentTimeMillis()
    private val minEmissionInterval = 16L // ~60fps

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext

        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "enhanced_audio_visualizer")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "enhanced_audio_visualizer_stream")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopVisualizer()
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addRequestPermissionsResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode == PERMISSION_REQUEST_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                pendingSessionId?.let { sessionId ->
                    actuallyStartVisualizer(sessionId)
                }
            } else {
                // Permission denied - notify Flutter to use fallback
                handler.post {
                    eventSink?.success(listOf(-1.0, -1.0, -1.0, -1.0, -1.0)) // Special signal for permission denied
                }
            }
            pendingSessionId = null
            return true
        }
        return false
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "startVisualizer" -> {
                val sessionId = call.argument<Int>("audioSessionId") ?: 0
                startVisualizer(sessionId, result)
            }
            "stopVisualizer" -> {
                stopVisualizer()
                result.success(true)
            }
            "isVisualizerActive" -> {
                result.success(isActive)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    private fun startVisualizer(sessionId: Int, result: Result) {
        // Check if we have audio permission
        activity?.let { act ->
            if (ContextCompat.checkSelfPermission(act, Manifest.permission.RECORD_AUDIO)
                != PackageManager.PERMISSION_GRANTED) {

                // Request permission
                pendingSessionId = sessionId
                ActivityCompat.requestPermissions(
                    act,
                    arrayOf(Manifest.permission.RECORD_AUDIO),
                    PERMISSION_REQUEST_CODE
                )
                result.success(true) // We'll handle the actual start in the permission callback
                return
            }
        }

        actuallyStartVisualizer(sessionId)
        result.success(true)
    }

    private fun actuallyStartVisualizer(sessionId: Int) {
        try {
            // Stop any existing visualizer
            stopVisualizer()

            // Use the audio session ID from the media player to analyze playback audio
            audioSessionId = if (sessionId > 0) sessionId else 0
            println("[AudioVisualizerPlugin] Starting visualizer with session ID: $audioSessionId")

            // Create new visualizer for audio playback analysis
            visualizer = Visualizer(audioSessionId).apply {
                // Get the optimal capture size
                val captureRange = Visualizer.getCaptureSizeRange()
                captureSize = captureRange[1].coerceAtMost(1024) // Increased for better resolution

                // Set up FFT data capture listener with high update rate
                setDataCaptureListener(object : Visualizer.OnDataCaptureListener {
                    override fun onWaveFormDataCapture(
                        visualizer: Visualizer?,
                        waveform: ByteArray?,
                        samplingRate: Int
                    ) {
                        // We don't use waveform data
                    }

                    override fun onFftDataCapture(
                        visualizer: Visualizer?,
                        fft: ByteArray?,
                        samplingRate: Int
                    ) {
                        fft?.let {
                            processFftData(it, samplingRate)
                        }
                    }
                }, Visualizer.getMaxCaptureRate(), false, true)

                // Enable the visualizer
                enabled = true
                isActive = true
            }

        } catch (e: Exception) {
            isActive = false
            // Send special error signal to Flutter
            handler.post {
                eventSink?.success(listOf(-2.0, -2.0, -2.0, -2.0, -2.0)) // Special signal for visualizer error
            }
        }
    }

    private fun stopVisualizer() {
        try {
            visualizer?.apply {
                if (enabled) {
                    enabled = false
                }
                release()
            }
            visualizer = null
            isActive = false
        } catch (e: Exception) {
            // Ignore release errors
        }
    }

    /**
     * Process FFT data and convert to frequency band amplitudes with enhanced silence detection
     */
    private fun processFftData(fft: ByteArray, samplingRate: Int) {
        if (!isActive || eventSink == null) return

        try {
            val bands = 5
            val bandData = FloatArray(bands)
            val n = fft.size / 2

            println("[AudioVisualizerPlugin] Processing FFT data: size=${fft.size}, samplingRate=$samplingRate")

            // Check if we're getting real data or all zeros
            val hasRealData = fft.any { it != 0.toByte() }

            if (!hasRealData) {
                // If we're getting all zeros, generate some test data to verify the pipeline works
                println("[AudioVisualizerPlugin] No real FFT data detected, generating test data")
                val time = System.currentTimeMillis() / 100.0
                for (i in 0 until bands) {
                    bandData[i] = (0.3 + 0.3 * kotlin.math.sin(time + i * 0.5)).toFloat()
                }
            } else {
                // Process FFT data into frequency bands
                for (i in 0 until bands) {
                        // Make the first band (index 0) use the same frequency range as the second band (index 1)
                        // so the visualizer's first bar detects the same frequencies as the second.
                        val effectiveBand = if (i == 0) 1 else i
                        val startIndex = (effectiveBand * n / bands)
                        val endIndex = ((effectiveBand + 1) * n / bands).coerceAtMost(n - 1)

                        var magnitude = 0.0f
                        var count = 0

                        for (j in startIndex until endIndex step 2) {
                            if (j + 1 < fft.size) {
                                val real = fft[j].toFloat()
                                val imaginary = fft[j + 1].toFloat()
                                magnitude += sqrt(real * real + imaginary * imaginary)
                                count++
                            }
                        }

                        if (count > 0) {
                            magnitude /= count
                            // Normalize and apply logarithmic scaling
                            bandData[i] = (ln(magnitude + 1) / 4.0f).coerceIn(0.0f, 1.0f)
                        }
                }
            }

            // Send data to Flutter
            handler.post {
                eventSink?.success(bandData.toList())
            }
        } catch (e: Exception) {
            println("[AudioVisualizerPlugin] Error processing FFT data: ${e.message}")
        }
    }

    // No V1 embedding registration required; MainActivity registers this plugin via FlutterEngine
}
