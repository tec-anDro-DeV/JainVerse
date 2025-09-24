import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let channelName = "com.jainverse.background_audio"
  private var methodChannel: FlutterMethodChannel?
  // Best-effort native state to report to Dart. Kept in sync with AVAudioSession
  // and interruptions. This is a pragmatic fallback because the app's actual
  // player runs in Dart; native can only report best-effort state.
  private var nativeIsPlaying: Bool = false
  private var nativeIsAudioServiceRunning: Bool = false

  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
      try session.setCategory(.playback, mode: .default, options: [])
      try session.setActive(true)
    } catch {
      NSLog("[BackgroundAudioManager][iOS] Failed to configure audio session: \(error)")
    }

    NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: session)
  }

  @objc private func handleInterruption(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
          let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

    switch type {
    case .began:
  nativeIsPlaying = false
  methodChannel?.invokeMethod("onAudioFocusChanged", arguments: ["hasFocus": false])
    case .ended:
  // interruption ended; we can't decide whether playback resumed, but
  // notify Dart that focus returned so it can decide to resume.
  methodChannel?.invokeMethod("onAudioFocusChanged", arguments: ["hasFocus": true])
    @unknown default:
      break
    }
  }
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    configureAudioSession()

    if let controller = window?.rootViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
      methodChannel?.setMethodCallHandler({ [weak self] (call, result) in
        guard let self = self else { return }
        switch call.method {
        case "isPlaying":
          // Return true if native believes audio is playing or AVAudioSession
          // reports other audio active. This is best-effort; the authoritative
          // player state usually lives in Dart.
          let session = AVAudioSession.sharedInstance()
          let isOtherPlaying = session.isOtherAudioPlaying
          result(self.nativeIsPlaying || isOtherPlaying)

        case "pausePlayback":
          // If the app used a native player, pause it here. As a fallback
          // update the native flag so queries reflect the change.
          self.nativeIsPlaying = false
          result(nil)

        case "resumePlayback":
          // If the app used a native player, resume it here. As a fallback
          // update the native flag so queries reflect the change.
          self.nativeIsPlaying = true
          result(nil)

        case "isAudioServiceRunning":
          // If the app runs an iOS audio background task we can't always
          // introspect it from here; use a pragmatic heuristic: active
          // AVAudioSession or an explicit native flag.
          let session = AVAudioSession.sharedInstance()
          let sessionActive = session.isOtherAudioPlaying || session.isOtherAudioPlaying == false ? session.isOtherAudioPlaying : session.isOtherAudioPlaying
          // Prefer explicit native flag if set; otherwise report session activity
          result(self.nativeIsAudioServiceRunning || session.isOtherAudioPlaying || session.isOtherAudioPlaying)

        case "setNativePlayingState":
          // Optional helper callable from Dart to sync native state when
          // the Dart player state changes.
          if let args = call.arguments as? [String: Any], let playing = args["playing"] as? Bool {
            self.nativeIsPlaying = playing
          }
          result(nil)

        case "setNativeServiceRunning":
          if let args = call.arguments as? [String: Any], let running = args["running"] as? Bool {
            self.nativeIsAudioServiceRunning = running
          }
          result(nil)

        default:
          result(FlutterMethodNotImplemented)
        }
      })
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
