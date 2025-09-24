package com.jainverse.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.view.KeyEvent
import androidx.core.content.ContextCompat

/**
 * Receives app-level audio control intents and forwards them to the
 * system/media framework so the existing audio_service plugin can react.
 */
class AudioControlReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        try {
            when (action) {
                "com.jainverse.action.PAUSE" -> {
                    // Forward as MEDIA_BUTTON pause event so MediaButtonReceiver/AudioService handles it
                    val down = Intent(Intent.ACTION_MEDIA_BUTTON)
                    down.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PAUSE))
                    context.sendBroadcast(down)

                    val up = Intent(Intent.ACTION_MEDIA_BUTTON)
                    up.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PAUSE))
                    context.sendBroadcast(up)
                }
                "com.jainverse.action.RESUME" -> {
                    val down = Intent(Intent.ACTION_MEDIA_BUTTON)
                    down.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY))
                    context.sendBroadcast(down)

                    val up = Intent(Intent.ACTION_MEDIA_BUTTON)
                    up.putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_UP, KeyEvent.KEYCODE_MEDIA_PLAY))
                    context.sendBroadcast(up)
                }
                "com.jainverse.action.START_FOREGROUND" -> {
                    // Request the audio service to start in foreground. Start the plugin's service by class name.
                    val svc = Intent()
                    svc.setClassName(context.packageName, "com.ryanheise.audioservice.AudioService")
                    try {
                        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                            ContextCompat.startForegroundService(context, svc)
                        } else {
                            context.startService(svc)
                        }
                    } catch (e: Exception) {
                        // best-effort
                    }
                }
            }
        } catch (e: Exception) {
            // swallow to avoid crashing broadcast dispatch
        }
    }
}
