package com.jainverse.app

import android.content.Context
import android.content.Intent
import android.app.ActivityManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.view.KeyEvent
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode

class MainActivity: AudioServiceFragmentActivity() {
    private val CHANNEL = "com.jainverse.background_audio"
    
    // FIX: Use TextureView instead of SurfaceView to prevent crashes after UCrop
    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }
    private var wakeLock: PowerManager.WakeLock? = null
    private lateinit var audioManager: AudioManager
    private lateinit var methodChannel: MethodChannel
    private val audioFocusChangeListener = AudioManager.OnAudioFocusChangeListener { focusChange ->
        when (focusChange) {
            AudioManager.AUDIOFOCUS_GAIN -> {
                if (::methodChannel.isInitialized) {
                    methodChannel.invokeMethod("onAudioFocusChanged", mapOf("hasFocus" to true))
                }
            }
            AudioManager.AUDIOFOCUS_LOSS, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                if (::methodChannel.isInitialized) {
                    methodChannel.invokeMethod("onAudioFocusChanged", mapOf("hasFocus" to false))
                }
            }
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        // Register the enhanced audio visualizer plugin
        flutterEngine.plugins.add(AudioVisualizerPlugin())

        // Register the just_audio integration plugin
        flutterEngine.plugins.add(JustAudioVisualizerIntegrationPlugin())

        // Set up method channel for background audio management
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestBatteryOptimizationExemption" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }
                "isBatteryOptimizationExempted" -> {
                    val isExempted = isBatteryOptimizationExempted()
                    result.success(isExempted)
                }
                "acquireWakeLock" -> {
                    acquireWakeLock()
                    result.success(true)
                }
                "releaseWakeLock" -> {
                    releaseWakeLock()
                    result.success(true)
                }
                "isWakeLockHeld" -> {
                    val isHeld = wakeLock?.isHeld == true
                    result.success(isHeld)
                }
                "startForegroundService" -> {
                    try {
                        val intent = Intent("com.jainverse.action.START_FOREGROUND")
                        intent.setPackage(packageName)
                        if (VERSION.SDK_INT >= VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("start_failed", e.message, null)
                    }
                }
                "stopForegroundService" -> {
                    try {
                        val svc = Intent()
                        svc.setClassName(packageName, "com.ryanheise.audioservice.AudioService")
                        // Best-effort stop of the audio service
                        stopService(svc)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("stop_failed", e.message, null)
                    }
                }
                "stopPlayback" -> {
                    try {
                        // Send MEDIA_BUTTON stop event so audio_service/MediaSession stops
                        val down = Intent(Intent.ACTION_MEDIA_BUTTON)
                        down.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_STOP))
                        sendBroadcast(down)

                        val up = Intent(Intent.ACTION_MEDIA_BUTTON)
                        up.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_STOP))
                        sendBroadcast(up)

                        // Also attempt to stop the service class directly
                        val svc = Intent()
                        svc.setClassName(packageName, "com.ryanheise.audioservice.AudioService")
                        stopService(svc)

                        result.success(true)
                    } catch (e: Exception) {
                        result.error("stop_playback_failed", e.message, null)
                    }
                }
                "pausePlayback" -> {
                    val intent = Intent("com.jainverse.action.PAUSE")
                    intent.setPackage(packageName)
                    sendBroadcast(intent)
                    result.success(null)
                }
                "resumePlayback" -> {
                    val intent = Intent("com.jainverse.action.RESUME")
                    intent.setPackage(packageName)
                    sendBroadcast(intent)
                    result.success(null)
                }
                "isPlaying" -> {
                    // Use AudioManager to detect whether music/audio is active
                    try {
                        val isPlaying = audioManager.isMusicActive
                        result.success(isPlaying)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                }
                "isAudioServiceRunning" -> {
                    val manager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    var found = false
                    try {
                        val services = manager.getRunningServices(Int.MAX_VALUE)
                        for (s in services) {
                            if (s.service.className == "com.ryanheise.audioservice.AudioService") {
                                found = true
                                break
                            }
                        }
                    } catch (e: Exception) {
                        // fallback: assume not running
                    }
                    result.success(found)
                }
                "requestAudioFocus" -> {
                    val res = audioManager.requestAudioFocus(audioFocusChangeListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
                    result.success(res == AudioManager.AUDIOFOCUS_REQUEST_GRANTED)
                }
                "abandonAudioFocus" -> {
                    audioManager.abandonAudioFocus(audioFocusChangeListener)
                    result.success(true)
                }
                "showBatteryOptimizationSettings" -> {
                    showBatteryOptimizationSettings()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent().apply {
                    action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                try {
                    startActivity(intent)
                } catch (e: Exception) {
                    // Fallback to settings page if direct exemption fails
                    val settingsIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    startActivity(settingsIntent)
                }
            }
        }
    }

    private fun isBatteryOptimizationExempted(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true // Older Android versions don't have battery optimization
        }
    }

    private fun acquireWakeLock() {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock?.let {
            if (it.isHeld) it.release()
        }
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "JainVerse::BackgroundAudioWakeLock"
        ).apply {
            acquire(10 * 60 * 1000L) // 10 minutes timeout for safety
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }

    private fun showBatteryOptimizationSettings() {
        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
        startActivity(intent)
    }

    override fun onDestroy() {
        // Abandon audio focus and release wake lock
        try {
            audioManager.abandonAudioFocus(audioFocusChangeListener)
        } catch (e: Exception) { }
        releaseWakeLock()
        super.onDestroy()
    }
}
