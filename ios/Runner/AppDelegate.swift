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

    if let controller = window?.rootViewController as? FlutterViewController {
      setupMethodChannels(controller: controller)
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
    // If we have a pending PiP URL, start PiP now as app is backgrounding
    if let urlString = pendingPipUrl {
      NSLog("[VideoPiP][iOS] App backgrounding, auto-starting PiP")
      // The PiP will automatically start via AVPlayerViewController
    }
  }
  
  private func setupMethodChannels(controller: FlutterViewController) {
    // Background audio channel
    methodChannel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)
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
    orientationChannel = FlutterMethodChannel(name: orientationChannelName, binaryMessenger: controller.binaryMessenger)
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

    // PiP channel
    pipChannel = FlutterMethodChannel(name: pipChannelName, binaryMessenger: controller.binaryMessenger)
    pipChannel?.setMethodCallHandler({ [weak self] (call, result) in
      guard let self = self else { return }
      switch call.method {
      case "isPictureInPictureSupported":
        result(AVPictureInPictureController.isPictureInPictureSupported())
        
      case "enterPictureInPicture":
        let args = call.arguments as? [String: Any]
        let url = args?["videoUrl"] as? String
        let positionMs = args?["positionMs"] as? Int ?? 0
        let isPlaying = args?["isPlaying"] as? Bool ?? false

        DispatchQueue.main.async {
          let success = self.startPictureInPicture(
            videoUrl: url,
            positionMs: positionMs,
            isPlaying: isPlaying
          )
          result(success)
        }
        
      case "updatePlaybackState":
        if let args = call.arguments as? [String: Any],
           let isPlaying = args["isPlaying"] as? Bool {
          DispatchQueue.main.async {
            if isPlaying {
              self.pipPlayer?.play()
            } else {
              self.pipPlayer?.pause()
            }
          }
        }
        result(nil)
        
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

  private func startPictureInPicture(videoUrl: String?, positionMs: Int, isPlaying: Bool) -> Bool {
    NSLog("[VideoPiP][iOS] startPictureInPicture - positionMs: \(positionMs), isPlaying: \(isPlaying)")

    guard AVPictureInPictureController.isPictureInPictureSupported() else {
      NSLog("[VideoPiP][iOS] PiP not supported")
      return false
    }

    guard let urlString = videoUrl, let url = URL(string: urlString) else {
      NSLog("[VideoPiP][iOS] Invalid video URL")
      return false
    }

    // Clean up any existing session
    cleanupPipResources()
    
    // Store URL for app backgrounding
    pendingPipUrl = urlString

    // Create player
    let player = AVPlayer(url: url)
    self.pipPlayer = player
    
    // Seek to position
    let seekTime = CMTime(value: CMTimeValue(positionMs), timescale: 1000)
    player.seek(to: seekTime, toleranceBefore: .zero, toleranceAfter: .zero)
    
    // Create AVPlayerViewController (the modern iOS way)
    let playerViewController = AVPlayerViewController()
    playerViewController.player = player
    playerViewController.allowsPictureInPicturePlayback = true
    
    if #available(iOS 14.2, *) {
      playerViewController.canStartPictureInPictureAutomaticallyFromInline = true
    }
    
    self.pipViewController = playerViewController
    
    // Create player layer for PiP controller
    let playerLayer = AVPlayerLayer(player: player)
    playerLayer.videoGravity = .resizeAspect
    self.pipPlayerLayer = playerLayer
    
    // Add as child to root view controller (required for PiP)
    if let rootVC = window?.rootViewController {
      rootVC.addChild(playerViewController)
      
      // Add view but make it tiny and transparent
      playerViewController.view.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
      playerViewController.view.alpha = 0.01
      playerViewController.view.layer.addSublayer(playerLayer)
      playerLayer.frame = playerViewController.view.bounds
      rootVC.view.insertSubview(playerViewController.view, at: 0)
      playerViewController.didMove(toParent: rootVC)
      
      NSLog("[VideoPiP][iOS] Player view controller added to hierarchy")
    }
    
    // Create PiP controller manually
    guard let controller = AVPictureInPictureController(playerLayer: playerLayer) else {
      NSLog("[VideoPiP][iOS] Failed to create PiP controller")
      cleanupPipResources()
      return false
    }
    
    controller.delegate = self
    self.pipController = controller
    
    if #available(iOS 14.2, *) {
      controller.canStartPictureInPictureAutomaticallyFromInline = true
    }
    
    if #available(iOS 15.0, *) {
      controller.requiresLinearPlayback = false
    }
    
    NSLog("[VideoPiP][iOS] PiP controller created")
    
    // Wait for player to be ready, then start playback
    var observer: NSKeyValueObservation?
    observer = player.currentItem?.observe(\.status, options: [.new, .initial]) { [weak self] item, _ in
      guard let self = self else { return }
      
      NSLog("[VideoPiP][iOS] Player status: \(item.status.rawValue)")
      
      if item.status == .readyToPlay {
        observer?.invalidate()
        
        NSLog("[VideoPiP][iOS] Player ready!")
        
        // Start playback if requested
        if isPlaying {
          player.play()
          NSLog("[VideoPiP][iOS] Playback started")
        }
        
        // Try to start PiP immediately
        if let pipCtrl = self.pipController {
          if pipCtrl.isPictureInPicturePossible {
            NSLog("[VideoPiP][iOS] Attempting to start PiP immediately")
            pipCtrl.startPictureInPicture()
          } else {
            NSLog("[VideoPiP][iOS] PiP not possible yet, will auto-start on background")
          }
        } else {
          NSLog("[VideoPiP][iOS] No PiP controller available")
        }
        
      } else if item.status == .failed {
        NSLog("[VideoPiP][iOS] Player failed: \(String(describing: item.error))")
        observer?.invalidate()
        self.cleanupPipResources()
      }
    }

    return true
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