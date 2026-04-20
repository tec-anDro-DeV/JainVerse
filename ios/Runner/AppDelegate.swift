import Flutter
import UIKit
import AVFoundation
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  static var orientationLock: UIInterfaceOrientationMask = .portrait

  private let orientationChannelName = "com.jainverse.orientation"
  private var orientationChannel: FlutterMethodChannel?

  private let channelName = "com.jainverse.background_audio"
  private var methodChannel: FlutterMethodChannel?
  private let pipChannelName = "com.jainverse.pip"
  private var pipChannel: FlutterMethodChannel?
  private var videoTrimmerPlugin: VideoTrimmerPlugin?
  private let pluginRegistrarName = "com.jainverse.AppDelegate"
  private var pluginMessenger: FlutterBinaryMessenger? {
    registrar(forPlugin: pluginRegistrarName)?.messenger()
  }
  
  // PiP management with AVPlayerViewController
  private var pipViewController: AVPlayerViewController?
  private var pipPlayer: AVPlayer?
  private var pipController: AVPictureInPictureController?
  private var pipPlayerLayer: AVPlayerLayer?
  private var isInPipMode = false
  private var pendingPipUrl: String?
  
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

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleInterruption(_:)),
      name: AVAudioSession.interruptionNotification,
      object: session
    )
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

    if let messenger = pluginMessenger {
      setupMethodChannels(messenger: messenger)
    } else {
      NSLog("[BackgroundAudioManager][iOS] Unable to register Flutter channels: messenger unavailable")
    }
    
    // Observe app lifecycle for PiP
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(appWillResignActive),
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  @objc private func appWillResignActive() {
    // PiP disabled on iOS; ensure any pending resources are cleaned up.
    cleanupPipResources()
  }
  
  private func setupMethodChannels(messenger: FlutterBinaryMessenger) {
    // Background audio channel
    methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    methodChannel?.setMethodCallHandler({ [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "isPlaying":
        let session = AVAudioSession.sharedInstance()
        result(self.nativeIsPlaying || session.isOtherAudioPlaying)
      case "pausePlayback":
        self.nativeIsPlaying = false
        result(nil)
      case "resumePlayback":
        self.nativeIsPlaying = true
        result(nil)
      case "isAudioServiceRunning":
        let session = AVAudioSession.sharedInstance()
        result(self.nativeIsAudioServiceRunning || session.isOtherAudioPlaying)
      case "setNativePlayingState":
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

    // Orientation channel
    orientationChannel = FlutterMethodChannel(name: orientationChannelName, binaryMessenger: messenger)
    orientationChannel?.setMethodCallHandler({ (call, result) in
      switch call.method {
      case "setOrientationLock":
        if let args = call.arguments as? [String: Any], let orientation = args["orientation"] as? String {
          switch orientation {
          case "portrait": AppDelegate.orientationLock = .portrait
          case "portraitUpsideDown": AppDelegate.orientationLock = .portraitUpsideDown
          case "landscape": AppDelegate.orientationLock = [.landscapeLeft, .landscapeRight]
          case "landscapeLeft": AppDelegate.orientationLock = .landscapeLeft
          case "landscapeRight": AppDelegate.orientationLock = .landscapeRight
          case "all": AppDelegate.orientationLock = .all
          default: AppDelegate.orientationLock = .all
          }
        }
        result(nil)
      case "getOrientationLock":
        result(AppDelegate.orientationLock.rawValue)
      default:
        result(FlutterMethodNotImplemented)
      }
    })

    // Video trimmer channel (two-step trim+compress pipeline)
    videoTrimmerPlugin = VideoTrimmerPlugin(messenger: messenger)

    // PiP channel
    pipChannel = FlutterMethodChannel(name: pipChannelName, binaryMessenger: messenger)
    pipChannel?.setMethodCallHandler({ [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "isPictureInPictureSupported":
        // PiP disabled on iOS for this app.
        result(false)
        
      case "enterPictureInPicture":
        // Block PiP requests.
        result(false)
        
      case "updatePlaybackState":
        // No-op; PiP disabled.
        result(nil)
        
      case "exitPictureInPicture":
        // Ensure resources are cleaned up even if called.
        DispatchQueue.main.async {
          self.cleanupPipResources()
          result(nil)
        }
        
      default:
        result(FlutterMethodNotImplemented)
      }
    })
  }

  private func startPictureInPicture(videoUrl: String?, positionMs: Int, isPlaying: Bool) -> Bool {
    // PiP disabled on iOS.
    cleanupPipResources()
    return false
  }

  private func stopPictureInPicture() {
    NSLog("[VideoPiP][iOS] Stopping PiP")
    
    if let controller = pipController {
      if controller.isPictureInPictureActive {
        controller.stopPictureInPicture()
      }
    }
    
    cleanupPipResources()
  }

  private func cleanupPipResources() {
    NSLog("[VideoPiP][iOS] Cleaning up PiP resources")
    
    pendingPipUrl = nil
    
    pipPlayer?.pause()
    pipPlayer = nil
    
    pipPlayerLayer?.removeFromSuperlayer()
    pipPlayerLayer = nil
    
    if let controller = pipController {
      controller.delegate = nil
    }
    pipController = nil
    
    if let vc = pipViewController {
      vc.view.removeFromSuperview()
      vc.removeFromParent()
    }
    pipViewController = nil
    
    isInPipMode = false
  }

  override func application(
    _ application: UIApplication,
    supportedInterfaceOrientationsFor window: UIWindow?
  ) -> UIInterfaceOrientationMask {
    return AppDelegate.orientationLock
  }
}

extension AppDelegate: AVPictureInPictureControllerDelegate {
  func pictureInPictureControllerWillStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    NSLog("[VideoPiP][iOS] PiP will start")
    isInPipMode = true
    pipChannel?.invokeMethod("onPipStateChanged", arguments: ["isInPip": true])
  }

  func pictureInPictureControllerDidStartPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    NSLog("[VideoPiP][iOS] PiP started successfully!")
    
    // Now hide the player view
    DispatchQueue.main.async { [weak self] in
      self?.pipViewController?.view.isHidden = true
    }
  }

  func pictureInPictureControllerDidStopPictureInPicture(
    _ pictureInPictureController: AVPictureInPictureController
  ) {
    NSLog("[VideoPiP][iOS] PiP stopped")
    isInPipMode = false
    pipChannel?.invokeMethod("onPipStateChanged", arguments: ["isInPip": false])
    pipChannel?.invokeMethod("onPipClosed", arguments: nil)
    cleanupPipResources()
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    failedToStartPictureInPictureWithError error: Error
  ) {
    NSLog("[VideoPiP][iOS] Failed to start PiP: \(error.localizedDescription)")
    isInPipMode = false
    pipChannel?.invokeMethod("onPipStateChanged", arguments: ["isInPip": false])
    cleanupPipResources()
  }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
  ) {
    NSLog("[VideoPiP][iOS] Restoring UI")
    pipChannel?.invokeMethod("onPipExpanded", arguments: nil)
    completionHandler(true)
  }
}