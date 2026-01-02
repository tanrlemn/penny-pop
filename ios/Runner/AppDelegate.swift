import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let methodChannel = FlutterMethodChannel(
        name: "penny_pop/accessibility",
        binaryMessenger: controller.binaryMessenger
      )
      methodChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "getReduceTransparencyEnabled":
          result(UIAccessibility.isReduceTransparencyEnabled)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      let eventChannel = FlutterEventChannel(
        name: "penny_pop/accessibility_reduce_transparency",
        binaryMessenger: controller.binaryMessenger
      )
      eventChannel.setStreamHandler(ReduceTransparencyStreamHandler())
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}

private final class ReduceTransparencyStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var observer: NSObjectProtocol?

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events

    // Send initial value immediately.
    events(UIAccessibility.isReduceTransparencyEnabled)

    observer = NotificationCenter.default.addObserver(
      forName: UIAccessibility.reduceTransparencyStatusDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.eventSink?(UIAccessibility.isReduceTransparencyEnabled)
    }

    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    if let observer = observer {
      NotificationCenter.default.removeObserver(observer)
      self.observer = nil
    }
    return nil
  }
}
