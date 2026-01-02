import Flutter
import UIKit

/// Renders a system material blur using `UIVisualEffectView` for Flutter `UiKitView`.
///
/// Dart viewType: `penny_pop/system_material`
final class SystemMaterialPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    SystemMaterialPlatformView(frame: frame, viewIdentifier: viewId, arguments: args, binaryMessenger: messenger)
  }
}

final class SystemMaterialPlatformView: NSObject, FlutterPlatformView {
  private let containerView: UIView

  init(
    frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?,
    binaryMessenger messenger: FlutterBinaryMessenger?
  ) {
    let params = args as? [String: Any]
    let styleName = params?["style"] as? String
    let cornerRadius = (params?["cornerRadius"] as? NSNumber)?.doubleValue ?? 0

    containerView = UIView(frame: frame)
    containerView.backgroundColor = .clear
    containerView.clipsToBounds = true
    containerView.layer.cornerRadius = cornerRadius

    let blurStyle = SystemMaterialPlatformView.blurStyle(from: styleName)
    let blurEffect = UIBlurEffect(style: blurStyle)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.backgroundColor = .clear
    blurView.frame = containerView.bounds
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    containerView.addSubview(blurView)
    super.init()
  }

  func view() -> UIView {
    containerView
  }

  private static func blurStyle(from styleName: String?) -> UIBlurEffect.Style {
    guard #available(iOS 13.0, *) else {
      return .light
    }

    switch styleName {
    case "ultraThin":
      return .systemUltraThinMaterial
    case "thin":
      return .systemThinMaterial
    case "regular":
      return .systemMaterial
    case "thick":
      return .systemThickMaterial
    case "chrome":
      if #available(iOS 13.0, *) {
        return .systemChromeMaterial
      } else {
        return .systemMaterial
      }
    default:
      return .systemMaterial
    }
  }
}


