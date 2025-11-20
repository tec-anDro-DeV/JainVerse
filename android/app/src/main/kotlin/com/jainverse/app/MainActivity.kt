package com.jainverse.app

import android.content.Context
import android.content.Intent
import android.app.ActivityManager
import android.annotation.TargetApi
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.Settings
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.pm.ActivityInfo
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.view.KeyEvent
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.util.Rational
import android.os.Build.VERSION
import android.os.Build.VERSION_CODES
import android.content.res.Configuration
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import kotlin.math.max
import kotlin.math.min

class MainActivity: AudioServiceFragmentActivity() {
    private val CHANNEL = "com.jainverse.background_audio"
    private val PIP_CHANNEL = "com.jainverse.pip"
    private val ACTION_PIP_TOGGLE = "com.jainverse.action.PIP_TOGGLE"
    private val REQUEST_PIP_TOGGLE = 101
    private val pipExitHandler = Handler(Looper.getMainLooper())
    private var pipExitRunnable: Runnable? = null
    private var pipExitPending: Boolean = false
    private var wasInPictureInPictureMode: Boolean = false
    
    // FIX: Use TextureView instead of SurfaceView to prevent crashes after UCrop
    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }
    private var wakeLock: PowerManager.WakeLock? = null
    private lateinit var audioManager: AudioManager
    private lateinit var methodChannel: MethodChannel
    private lateinit var pipChannel: MethodChannel
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

    private fun isPipSupported(): Boolean {
        return VERSION.SDK_INT >= VERSION_CODES.O &&
            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
    }

    private fun enterPictureInPictureModeCompat(isPlaying: Boolean, aspectRatio: Double?): Boolean {
        if (!isPipSupported() || VERSION.SDK_INT < VERSION_CODES.O) return false
        return try {
            lastKnownIsPlaying = isPlaying
            if (aspectRatio != null) {
                lastKnownAspectRatio = aspectRatio
            }
            val params = buildPictureInPictureParams(isPlaying, aspectRatio)
            enterPictureInPictureMode(params)
        } catch (e: Exception) {
            false
        }
    }

    private fun updatePictureInPictureParams(isPlaying: Boolean, aspectRatio: Double?) {
        if (VERSION.SDK_INT < VERSION_CODES.O) return
        if (!isInPictureInPictureMode) return
        lastKnownIsPlaying = isPlaying
        if (aspectRatio != null) {
            lastKnownAspectRatio = aspectRatio
        }
        try {
            setPictureInPictureParams(buildPictureInPictureParams(isPlaying, aspectRatio))
        } catch (_: Exception) {
        }
    }

    @TargetApi(Build.VERSION_CODES.O)
    private fun buildPictureInPictureParams(isPlaying: Boolean, aspectRatio: Double?): PictureInPictureParams {
        val builder = PictureInPictureParams.Builder()
        builder.setAspectRatio(buildAspectRatio(aspectRatio ?: lastKnownAspectRatio))
        if (VERSION.SDK_INT >= VERSION_CODES.S) {
                builder.setAutoEnterEnabled(false)
            }
            // Only expose the play/pause toggle action in PiP; the platform
            // provides a default close affordance and we avoid adding a
            // duplicate close action here.
            builder.setActions(listOf(createToggleAction(isPlaying)))
        return builder.build()
    }

    private fun buildAspectRatio(ratio: Double): Rational {
        val sanitized = max(0.1, min(ratio, 4.0))
        val numerator = max(1, (sanitized * 1000).toInt())
        return Rational(numerator, 1000)
    }

    @TargetApi(Build.VERSION_CODES.O)
    private fun createToggleAction(isPlaying: Boolean): RemoteAction {
        val iconRes = if (isPlaying) android.R.drawable.ic_media_pause else android.R.drawable.ic_media_play
        val title = if (isPlaying) "Pause" else "Play"
        val pendingIntent = createPendingIntent(ACTION_PIP_TOGGLE, REQUEST_PIP_TOGGLE)
        return RemoteAction(Icon.createWithResource(this, iconRes), title, title, pendingIntent)
    }

    // Close action removed: rely on platform-provided close affordance.

    private fun createPendingIntent(action: String, requestCode: Int): PendingIntent {
        val intent = Intent(action).setPackage(packageName)
        val flags = PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        return PendingIntent.getBroadcast(this, requestCode, intent, flags)
    }

    private fun exitPictureInPicture() {
        if (VERSION.SDK_INT >= VERSION_CODES.N && isInPictureInPictureMode) {
            try {
                moveTaskToBack(false)
                finish()
            } catch (_: Exception) {
            }
        }
    }

    private fun notifyPipState(isInPip: Boolean) {
        if (::pipChannel.isInitialized) {
            pipChannel.invokeMethod("onPipStateChanged", mapOf("isInPip" to isInPip))
        }
    }

    override fun onPictureInPictureModeChanged(isInPictureInPictureMode: Boolean, newConfig: Configuration) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        notifyPipState(isInPictureInPictureMode)

        if (isInPictureInPictureMode) {
            cancelPendingPipExitClassification()
        } else if (wasInPictureInPictureMode) {
            schedulePipExitClassification()
        }

        wasInPictureInPictureMode = isInPictureInPictureMode
    }

    override fun onResume() {
        super.onResume()
        if (pipExitPending) {
            cancelPendingPipExitClassification()
        }
    }

    private fun schedulePipExitClassification() {
        cancelPendingPipExitClassification()
        pipExitPending = true
        pipExitRunnable = Runnable {
            pipExitPending = false
            if (!::pipChannel.isInitialized) {
                return@Runnable
            }

            if (hasWindowFocus()) {
                pipChannel.invokeMethod("onPipExpanded", null)
            } else {
                pipChannel.invokeMethod("onPipClosed", null)
            }
        }
        pipExitRunnable?.let {
            pipExitHandler.postDelayed(it, 350)
        }
    }

    private fun cancelPendingPipExitClassification() {
        pipExitRunnable?.let { pipExitHandler.removeCallbacks(it) }
        pipExitRunnable = null
        pipExitPending = false
    }

    private val pipActionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            when (intent?.action) {
                ACTION_PIP_TOGGLE -> {
                    if (::pipChannel.isInitialized) {
                        pipChannel.invokeMethod(
                            "onAction",
                            mapOf("action" to "togglePlayback")
                        )
                    }
                }
            }
        }
    }

    private var lastKnownAspectRatio: Double = 16.0 / 9.0
    private var lastKnownIsPlaying: Boolean = false

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
    audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
    // Orientation channel used by Dart `OrientationHelper` to request native
    // orientation changes. This gives a stronger enforcement than the
    // Flutter SystemChrome API on some OEMs/devices.
    val orientationChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.jainverse.orientation")
    orientationChannel.setMethodCallHandler { call, result ->
        when (call.method) {
            "setOrientationLock" -> {
                val orient = call.argument<String>("orientation")
                try {
                    when (orient) {
                        "portrait" -> requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
                        "portraitUpsideDown" -> requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_REVERSE_PORTRAIT
                        "landscape" -> requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE
                        "landscapeLeft" -> requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_LANDSCAPE
                        "landscapeRight" -> requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_REVERSE_LANDSCAPE
                        "all" -> requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                        else -> requestedOrientation = ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED
                    }
                    result.success(null)
                } catch (e: Exception) {
                    result.error("orientation_failed", e.message, null)
                }
            }
            else -> result.notImplemented()
        }
    }

    pipChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
    pipChannel.setMethodCallHandler { call, result ->
        when (call.method) {
            "isPictureInPictureSupported" -> {
                result.success(isPipSupported())
            }
            "enterPictureInPicture" -> {
                val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                val aspectRatio = call.argument<Double>("aspectRatio")
                val entered = enterPictureInPictureModeCompat(isPlaying, aspectRatio)
                result.success(entered)
            }
            "updatePlaybackState" -> {
                val isPlaying = call.argument<Boolean>("isPlaying") ?: false
                val aspectRatio = call.argument<Double>("aspectRatio")
                updatePictureInPictureParams(isPlaying, aspectRatio)
                result.success(null)
            }
            "exitPictureInPicture" -> {
                exitPictureInPicture()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    val pipFilter = IntentFilter().apply {
        addAction(ACTION_PIP_TOGGLE)
    }
    if (VERSION.SDK_INT >= VERSION_CODES.TIRAMISU) {
        registerReceiver(pipActionReceiver, pipFilter, Context.RECEIVER_NOT_EXPORTED)
    } else {
        registerReceiver(pipActionReceiver, pipFilter)
    }

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
        try {
            unregisterReceiver(pipActionReceiver)
        } catch (_: Exception) {
        }
        super.onDestroy()
    }
}
