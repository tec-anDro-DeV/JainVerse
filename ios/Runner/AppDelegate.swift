import Flutter
import UIKit
import AVFoundation
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  // Native orientation lock used by supportedInterfaceOrientationsFor
  // Defaults to portrait so the app remains portrait unless changed from Dart.
  static var orientationLock: UIInterfaceOrientationMask = .portrait

  private let orientationChannelName = "com.jainverse.orientation"
  private var orientationChannel: FlutterMethodChannel?

  private let channelName = "com.jainverse.background_audio"
  private var methodChannel: FlutterMethodChannel?
  private let pipChannelName = "com.jainverse.pip"
  private var pipChannel: FlutterMethodChannel?
  private var pipController: AVPictureInPictureController?
  private weak var pipPlayerLayer: AVPlayerLayer?
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

      // Orientation control channel: allows Dart to request a change to the
      // native supported interface orientations at runtime. This works in
      // tandem with Info.plist entries - Info.plist must still include the
      // orientations we want to allow (we already updated it).
      orientationChannel = FlutterMethodChannel(name: orientationChannelName, binaryMessenger: controller.binaryMessenger)
      orientationChannel?.setMethodCallHandler({ (call, result) in
        switch call.method {
        case "setOrientationLock":
          if let args = call.arguments as? [String: Any], let orientation = args["orientation"] as? String {
            switch orientation {
            case "portrait":
              AppDelegate.orientationLock = .portrait
            case "portraitUpsideDown":
              AppDelegate.orientationLock = .portraitUpsideDown
            case "landscape":
              AppDelegate.orientationLock = [.landscapeLeft, .landscapeRight]
            case "landscapeLeft":
              AppDelegate.orientationLock = .landscapeLeft
            case "landscapeRight":
              AppDelegate.orientationLock = .landscapeRight
            case "all":
              AppDelegate.orientationLock = .all
            default:
              AppDelegate.orientationLock = .all
            }
          }
          result(nil)

        case "getOrientationLock":
          result(AppDelegate.orientationLock.rawValue)

        default:
          result(FlutterMethodNotImplemented)
        }
      })

      pipChannel = FlutterMethodChannel(name: pipChannelName, binaryMessenger: controller.binaryMessenger)
      pipChannel?.setMethodCallHandler({ [weak self] (call, result) in
        guard let self = self else { return }
        switch call.method {
        case "isPictureInPictureSupported":
          result(AVPictureInPictureController.isPictureInPictureSupported())
        case "enterPictureInPicture":
          DispatchQueue.main.async {
            let success = self.startPictureInPicture(from: controller.view)
            result(success)
          }
        case "updatePlaybackState":
          result(nil) // Native AVPlayer handles playback state changes automatically
        case "exitPictureInPicture":
          DispatchQueue.main.async {
            self.stopPictureInPicture()
            result(nil)
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      })
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func startPictureInPicture(from view: UIView?) -> Bool {
    guard AVPictureInPictureController.isPictureInPictureSupported() else { return false }
    guard let layer = resolvePlayerLayer(in: view) else { return false }

    if pipController == nil || pipPlayerLayer !== layer {
      pipPlayerLayer = layer
      pipController = AVPictureInPictureController(playerLayer: layer)
      pipController?.delegate = self
      if #available(iOS 14.0, *) {
        pipController?.canStartPictureInPictureAutomaticallyFromInline = true
      }
    }

    return pipController?.startPictureInPicture() ?? false
  }

  private func stopPictureInPicture() {
    guard let controller = pipController else { return }
    if #available(iOS 14.2, *) {
      if controller.isPictureInPictureActive {
        controller.stopPictureInPicture()
      }
    } else {
      controller.stopPictureInPicture()
    }
  }

  private func resolvePlayerLayer(in view: UIView?) -> AVPlayerLayer? {
    guard let view = view else { return nil }
    if let layer = view.layer as? AVPlayerLayer, layer.player != nil {
      return layer
    }
    if let layer = resolvePlayerLayer(in: view.layer) {
      return layer
    }
    for subview in view.subviews {
      if let found = resolvePlayerLayer(in: subview) {
        return found
      }
    }
    return nil
  }

  private func resolvePlayerLayer(in layer: CALayer?) -> AVPlayerLayer? {
    guard let layer = layer else { return nil }
    if let playerLayer = layer as? AVPlayerLayer, playerLayer.player != nil {
      return playerLayer
    }
    if let sublayers = layer.sublayers {
      for sublayer in sublayers {
        if let found = resolvePlayerLayer(in: sublayer) {
          return found
        }
      }
    }
    return nil
  }

  // Respect the currently requested orientation mask. This is invoked by
  // iOS when deciding which orientations the app supports for the active
  // window. We return the value set by Dart via the orientation channel.
  override func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
    return AppDelegate.orientationLock
  }
}

extension AppDelegate: AVPictureInPictureControllerDelegate {
  func pictureInPictureControllerWillStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    pipChannel?.invokeMethod("onPipStateChanged", arguments: ["isInPip": true])
  }

  func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
    pipChannel?.invokeMethod("onPipStateChanged", arguments: ["isInPip": false])
    pipChannel?.invokeMethod("onPipClosed", arguments: nil)
  }

  func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
    completionHandler(true)
  }
}
