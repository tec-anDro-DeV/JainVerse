package com.jainverse.app

import android.content.Context
import android.media.AudioManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Helper plugin to get audio session ID from just_audio or system
 * This bridges the gap between just_audio and the visualizer
 */
class JustAudioVisualizerIntegrationPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var context: Context
    private lateinit var channel: MethodChannel

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "just_audio_visualizer_integration")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "getAudioSessionId" -> {
                getAudioSessionId(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getAudioSessionId(call: MethodCall, result: Result) {
        try {
            // For now, we'll use the system's default media output session
            // This captures audio being played through the system's media stream
            // Using 0 tells the Visualizer to capture from the main audio output mix
            val sessionId = 0 // AudioManager.AUDIO_SESSION_ID_GENERATE equivalent

            println("[JustAudioVisualizerIntegration] Returning session ID: $sessionId")
            result.success(sessionId)
        } catch (e: Exception) {
            println("[JustAudioVisualizerIntegration] Error getting session ID: ${e.message}")
            // Fallback: Use default session ID for system audio output
            result.success(0)
        }
    }

    // No V1 embedding registration required; MainActivity registers this plugin via FlutterEngine
}
