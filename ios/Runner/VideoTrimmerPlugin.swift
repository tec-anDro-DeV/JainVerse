import AVFoundation
import Flutter

/// Flutter plugin that trims a video file natively using AVAssetExportSession
/// with AVAssetExportPresetPassthrough (lossless container copy, no re-encoding).
///
/// Used as Step 1 of the two-step trim+compress pipeline that bypasses
/// the OtaliaStudios TrimDataSource render=false / State.Wait bug present
/// in com.otaliastudios:transcoder:0.10.5 (used by video_compress 3.1.4).
///
/// Channel: "com.jainverse.video_trim"
/// Method : "trimVideo" { inputPath, outputPath, startUs, endUs }
class VideoTrimmerPlugin {
    private var channel: FlutterMethodChannel?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.jainverse.video_trim",
                                       binaryMessenger: messenger)
        channel?.setMethodCallHandler(handle)
    }

    // -------------------------------------------------------------------------
    // MethodCall handler
    // -------------------------------------------------------------------------

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "trimVideo" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard let args      = call.arguments as? [String: Any],
              let inputPath  = args["inputPath"]  as? String,
              let outputPath = args["outputPath"] as? String,
              let startUs    = (args["startUs"]   as? NSNumber)?.int64Value,
              let endUs      = (args["endUs"]     as? NSNumber)?.int64Value
        else {
            result(FlutterError(code: "INVALID_ARGS",
                                message: "trimVideo requires inputPath, outputPath, startUs, endUs",
                                details: nil))
            return
        }

        guard endUs > startUs else {
            result(FlutterError(code: "INVALID_RANGE",
                                message: "endUs (\(endUs)) must be > startUs (\(startUs))",
                                details: nil))
            return
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            do {
                try self.trimVideo(inputPath: inputPath, outputPath: outputPath,
                                   startUs: startUs, endUs: endUs)
                DispatchQueue.main.async { result(outputPath) }
            } catch {
                DispatchQueue.main.async {
                    result(FlutterError(code: "TRIM_FAILED",
                                        message: error.localizedDescription,
                                        details: nil))
                }
            }
        }
    }

    // -------------------------------------------------------------------------
    // Core trim logic
    // -------------------------------------------------------------------------

    private func trimVideo(inputPath: String, outputPath: String,
                           startUs: Int64, endUs: Int64) throws {
        let asset = AVAsset(url: URL(fileURLWithPath: inputPath))

        // Passthrough: copies sample data without re-encoding — no quality loss,
        // no decode/encode cycle.  Equivalent to Android MediaExtractor+MediaMuxer.
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw NSError(domain: "VideoTrimmer", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not create AVAssetExportSession"
            ])
        }

        session.outputURL      = URL(fileURLWithPath: outputPath)
        session.outputFileType = .mp4

        // CMTime timescale matches the microsecond units used by the Dart caller.
        let scale: CMTimeScale = 1_000_000
        let start = CMTime(value: startUs, timescale: scale)
        let end   = CMTime(value: endUs,   timescale: scale)
        session.timeRange = CMTimeRange(start: start, end: end)

        // AVAssetExportSession handles PTS rebasing (output starts at t=0) and
        // proper audio+video interleaving automatically.
        let semaphore = DispatchSemaphore(value: 0)
        session.exportAsynchronously { semaphore.signal() }
        semaphore.wait()

        switch session.status {
        case .completed:
            return
        case .failed:
            throw session.error ?? NSError(domain: "VideoTrimmer", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Export failed without error detail"
            ])
        case .cancelled:
            throw NSError(domain: "VideoTrimmer", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Export was cancelled"
            ])
        default:
            throw NSError(domain: "VideoTrimmer", code: 4, userInfo: [
                NSLocalizedDescriptionKey: "Unexpected export status: \(session.status.rawValue)"
            ])
        }
    }
}
