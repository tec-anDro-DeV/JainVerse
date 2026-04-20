package com.jainverse.app

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.nio.ByteBuffer
import java.util.concurrent.Executors

/**
 * Flutter plugin that trims a video file natively using Android's
 * MediaExtractor + MediaMuxer (lossless frame copy, no re-encoding).
 *
 * Used as Step 1 of the two-step trim+compress pipeline that bypasses
 * the OtaliaStudios TrimDataSource render=false / State.Wait bug present
 * in com.otaliastudios:transcoder:0.10.5 (used by video_compress 3.1.4).
 *
 * Channel: "com.jainverse.video_trim"
 * Method : "trimVideo" { inputPath, outputPath, startUs, endUs }
 */
class VideoTrimmerPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel

    // Serialise trim operations; avoids unbounded thread spawning.
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    // -------------------------------------------------------------------------
    // FlutterPlugin
    // -------------------------------------------------------------------------

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.jainverse.video_trim")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        executor.shutdown()
    }

    // -------------------------------------------------------------------------
    // MethodCallHandler
    // -------------------------------------------------------------------------

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "trimVideo" -> {
                val inputPath  = call.argument<String>("inputPath")
                val outputPath = call.argument<String>("outputPath")
                // Use Number to safely handle Dart int arriving as Int or Long.
                val startUs    = call.argument<Number>("startUs")?.toLong()
                val endUs      = call.argument<Number>("endUs")?.toLong()

                if (inputPath == null || outputPath == null ||
                    startUs == null || endUs == null) {
                    result.error(
                        "INVALID_ARGS",
                        "trimVideo requires inputPath, outputPath, startUs, endUs",
                        null,
                    )
                    return
                }
                if (endUs <= startUs) {
                    result.error(
                        "INVALID_RANGE",
                        "endUs ($endUs) must be > startUs ($startUs)",
                        null,
                    )
                    return
                }

                executor.execute {
                    try {
                        trimVideo(inputPath, outputPath, startUs, endUs)
                        mainHandler.post { result.success(outputPath) }
                    } catch (e: Exception) {
                        mainHandler.post {
                            result.error("TRIM_FAILED", e.message, null)
                        }
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    // -------------------------------------------------------------------------
    // Core trim logic
    // -------------------------------------------------------------------------

    private fun trimVideo(
        inputPath: String,
        outputPath: String,
        startUs: Long,
        endUs: Long,
    ) {
        val extractor = MediaExtractor()
        var muxer: MediaMuxer? = null

        try {
            extractor.setDataSource(inputPath)

            // --- Track discovery ---------------------------------------------------

            val trackMap = mutableMapOf<Int, Int>() // extractor index → muxer index
            muxer = MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var videoExtractorIndex = -1
            // Start at a safe floor; grow to KEY_MAX_INPUT_SIZE if the track declares
            // larger frames (covers 1080p H.264 and most 4K H.265 at normal bitrates).
            var maxSampleSize = MIN_BUFFER_SIZE

            for (i in 0 until extractor.trackCount) {
                val format = extractor.getTrackFormat(i)
                val mime   = format.getString(MediaFormat.KEY_MIME) ?: continue
                if (!mime.startsWith("video/") && !mime.startsWith("audio/")) continue

                trackMap[i] = muxer.addTrack(format)
                extractor.selectTrack(i)

                if (mime.startsWith("video/") && videoExtractorIndex < 0) {
                    videoExtractorIndex = i
                    // Copy container-level rotation before muxer.start() so the output
                    // does not render sideways on portrait recordings.
                    // KEY_ROTATION = "rotation-degrees" is a compile-time constant — safe
                    // on all API levels without a version guard.
                    if (format.containsKey(MediaFormat.KEY_ROTATION)) {
                        muxer.setOrientationHint(format.getInteger(MediaFormat.KEY_ROTATION))
                    }
                }

                // KEY_MAX_INPUT_SIZE is the codec's declared per-sample ceiling.
                // Not always present (some containers omit it); tolerate absence.
                if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                    maxSampleSize = maxOf(maxSampleSize, format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE))
                }
            }

            // Guard: muxer.start() with zero tracks throws IllegalStateException.
            if (trackMap.isEmpty()) {
                throw IllegalStateException("No audio or video tracks found in: $inputPath")
            }

            muxer.start()

            // One seek positions all selected tracks simultaneously.
            // SEEK_TO_PREVIOUS_SYNC lands on a keyframe at or before startUs so
            // the first written video frame is always an I-frame.
            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC)

            // --- Read/write loop ---------------------------------------------------

            var buffer           = ByteBuffer.allocate(maxSampleSize)
            val activeTracks     = trackMap.keys.toMutableSet()
            var firstVideoWritten = false
            // For video+audio: overwritten with the keyframe PTS on the first video
            // write, so all tracks are rebased from the I-frame boundary.
            // For audio-only: stays at startUs so audio is correctly rebased from
            // the trim start without the overflow that Long.MIN_VALUE would cause.
            var effectiveStartUs = startUs

            while (activeTracks.isNotEmpty()) {
                val trackIndex = extractor.sampleTrackIndex
                if (trackIndex < 0) break  // EOS across all remaining selected tracks

                // Guard against sampleTrackIndex returning a deselected track index on
                // certain OEM MediaExtractor implementations.
                if (!activeTracks.contains(trackIndex)) {
                    extractor.advance()
                    continue
                }

                val pts = extractor.sampleTime
                // Malformed containers can return -1 for a non-EOS sample; treat as EOS.
                if (pts < 0) break

                if (pts >= endUs) {
                    // Track exhausted for this trim window.  Unselecting causes
                    // sampleTrackIndex to skip this track without a manual advance().
                    activeTracks.remove(trackIndex)
                    extractor.unselectTrack(trackIndex)
                    continue
                }

                val isVideoTrack = (trackIndex == videoExtractorIndex)

                when {
                    isVideoTrack -> {
                        // Write video unconditionally from the keyframe position.
                        // The first frame is guaranteed to be an I-frame (SEEK_TO_PREVIOUS_SYNC),
                        // which is required for decoders to start decoding successfully.
                    }
                    videoExtractorIndex >= 0 -> {
                        // Video+audio file.  Suppress audio until the first video keyframe
                        // has been written — prevents an audio-only leading segment that
                        // causes OtaliaStudios to return State.Wait on the VIDEO decoder.
                        if (!firstVideoWritten) {
                            extractor.advance()
                            continue
                        }
                    }
                    else -> {
                        // Audio-only file.  SEEK_TO_PREVIOUS_SYNC can land before startUs
                        // for audio tracks too; skip those pre-trim frames to avoid writing
                        // negative rebased timestamps.
                        if (pts < startUs) {
                            extractor.advance()
                            continue
                        }
                    }
                }

                // --- Dynamic buffer sizing ----------------------------------------
                // On API 28+ we know the exact sample size before reading; grow the
                // buffer if a large I-frame would overflow it.  On older APIs we rely
                // on maxSampleSize computed from KEY_MAX_INPUT_SIZE (set above).
                if (Build.VERSION.SDK_INT >= 28) {
                    val needed = extractor.sampleSize.toInt()
                    if (needed > buffer.capacity()) {
                        buffer = ByteBuffer.allocate(needed + BUFFER_GROWTH_PAD)
                    }
                }

                buffer.clear()
                val sampleSize = extractor.readSampleData(buffer, 0)
                if (sampleSize < 0) {
                    // readSampleData returns -1 when the track is truly exhausted.
                    activeTracks.remove(trackIndex)
                    extractor.unselectTrack(trackIndex)
                    continue
                }

                // Capture the keyframe PTS as the rebase anchor on the first video write.
                // effectiveStartUs ≤ startUs; audio is gated out until this point.
                if (isVideoTrack && !firstVideoWritten) {
                    effectiveStartUs  = pts
                    firstVideoWritten = true
                }

                // --- Flag mapping -------------------------------------------------
                // MediaExtractor and MediaCodec.BufferInfo share the same bit positions
                // but with DIFFERENT semantics for bits 2 and 4:
                //
                //   Extractor SAMPLE_FLAG_ENCRYPTED    (2)  ↔  Muxer BUFFER_FLAG_CODEC_CONFIG (2)
                //   Extractor SAMPLE_FLAG_PARTIAL_FRAME(4)  ↔  Muxer BUFFER_FLAG_END_OF_STREAM(4)
                //
                // Passing extractor.sampleFlags raw would silently tag normal frames as
                // CSD or EOS, causing the muxer to corrupt or prematurely close tracks.
                // Only forward the KEY_FRAME / SYNC bit; all others are extractor-internal.
                val muxerFlags = if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0)
                    MediaCodec.BUFFER_FLAG_KEY_FRAME else 0

                val info = MediaCodec.BufferInfo().apply {
                    presentationTimeUs = pts - effectiveStartUs
                    size               = sampleSize
                    offset             = 0
                    flags              = muxerFlags
                }
                muxer.writeSampleData(trackMap[trackIndex]!!, buffer, info)
                extractor.advance()
            }

        } finally {
            // Release order: extractor first (reader), then muxer stop + release (writer).
            try { extractor.release() } catch (_: Exception) {}
            try { muxer?.stop()       } catch (_: Exception) {}
            try { muxer?.release()    } catch (_: Exception) {}
        }
    }

    // -------------------------------------------------------------------------
    // Constants
    // -------------------------------------------------------------------------

    companion object {
        // 4 MiB floor covers 1080p H.264 I-frames at up to ~30 Mbps and most 4K H.265.
        // KEY_MAX_INPUT_SIZE from the track format raises this further when needed.
        private const val MIN_BUFFER_SIZE    = 4 * 1024 * 1024

        // Extra headroom added when reallocating on API 28+ to avoid thrashing on
        // consecutive large frames near the declared maximum.
        private const val BUFFER_GROWTH_PAD = 512 * 1024
    }
}
