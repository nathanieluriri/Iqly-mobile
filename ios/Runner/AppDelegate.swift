import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Lets flutter_local_notifications show banners in the foreground and
    // hear taps.
    UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SecureChannel") {
      SecureChannel.shared.register(with: registrar.messenger())
    }
  }
}

final class SecureChannel {
  static let name = "net.iqly/secure"
  static let shared = SecureChannel()

  private var channel: FlutterMethodChannel?
  private var field: UITextField?
  private var observers: [NSObjectProtocol] = []

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: Self.name, binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setSecure":
      let on: Bool
      if let flag = call.arguments as? Bool {
        on = flag
      } else if let args = call.arguments as? [String: Any] {
        on = args["on"] as? Bool ?? false
      } else {
        on = false
      }
      DispatchQueue.main.async {
        self.setSecure(on)
        result(true)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func setSecure(_ on: Bool) {
    if on {
      installShield()
      watchCapture()
    } else {
      removeShield()
      stopWatch()
    }
  }

  private func keyWindow() -> UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)
  }

  private func installShield() {
    guard field == nil, let window = keyWindow() else { return }
    let field = UITextField()
    field.isSecureTextEntry = true
    field.isUserInteractionEnabled = false
    field.translatesAutoresizingMaskIntoConstraints = false
    window.addSubview(field)
    NSLayoutConstraint.activate([
      field.centerXAnchor.constraint(equalTo: window.centerXAnchor),
      field.centerYAnchor.constraint(equalTo: window.centerYAnchor),
      field.widthAnchor.constraint(equalToConstant: 1),
      field.heightAnchor.constraint(equalToConstant: 1),
    ])
    if let superlayer = window.layer.superlayer {
      superlayer.addSublayer(field.layer)
      field.layer.sublayers?.last?.addSublayer(window.layer)
    }
    self.field = field
  }

  private func removeShield() {
    field?.removeFromSuperview()
    field = nil
  }

  private func watchCapture() {
    stopWatch()
    let rec = NotificationCenter.default.addObserver(
      forName: UIScreen.capturedDidChangeNotification,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      if UIScreen.main.isCaptured {
        self?.channel?.invokeMethod("captured", arguments: nil)
      }
    }
    observers = [rec]
    if UIScreen.main.isCaptured {
      channel?.invokeMethod("captured", arguments: nil)
    }
  }

  private func stopWatch() {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
    observers = []
  }
}
