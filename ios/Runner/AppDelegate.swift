import Flutter
import UIKit
import MediaPlayer

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "music_playback_notification",
        binaryMessenger: controller.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "update":
          guard let args = call.arguments as? [String: Any] else {
            result(nil)
            return
          }
          let title = args["title"] as? String ?? "Music"
          let artist = args["artist"] as? String ?? ""
          let source = args["source"] as? String ?? "Music"
          let isPlaying = args["isPlaying"] as? Bool ?? false
          var info: [String: Any] = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyArtist: artist.isEmpty ? source : artist,
            MPMediaItemPropertyAlbumTitle: "播放自 \(source)",
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
          ]
          MPNowPlayingInfoCenter.default().nowPlayingInfo = info
          if #available(iOS 13.0, *) {
            MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
          }
          result(nil)
        case "cancel":
          MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
          if #available(iOS 13.0, *) {
            MPNowPlayingInfoCenter.default().playbackState = .stopped
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
