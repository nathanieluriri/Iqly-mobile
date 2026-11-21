import Flutter
import UIKit
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit
#endif

// The iOS half of SurfacesBridge (lib/surfaces/surfaces.dart), Runner target
// only, registered from AppDelegate. It takes only iqly:// links from the
// scene, so sign-in callbacks and other plugins' links pass untouched.
final class SurfacesChannel: NSObject, FlutterSceneLifeCycleDelegate {
  static let name = "net.iqly/surfaces"
  static let shared = SurfacesChannel()

  private var channel: FlutterMethodChannel?
  private var launchLink: String?

  func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: Self.name, binaryMessenger: registrar.messenger())
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    self.channel = channel
    registrar.addSceneDelegate(self)
  }

  // A cold start from a widget or Live Activity: Dart asks for the link once
  // it is ready to route it.
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions?
  ) -> Bool {
    if let url = connectionOptions?.urlContexts.map(\.url).first(where: Self.isOurs) {
      launchLink = url.absoluteString
    }
    return false
  }

  func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
    guard let url = URLContexts.map(\.url).first(where: Self.isOurs) else { return false }
    open(url)
    return true
  }

  private static func isOurs(_ url: URL) -> Bool { url.scheme == "iqly" }

  // A widget or Live Activity tap while the app is running.
  func open(_ url: URL) {
    guard url.scheme == "iqly" else { return }
    if let channel {
      channel.invokeMethod("openLink", arguments: url.absoluteString)
    } else {
      launchLink = url.absoluteString
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    let args = call.arguments as? [String: Any] ?? [:]
    switch call.method {
    case "publishWidgets":
      result(publishWidgets(args))
    case "takeLaunchLink":
      result(launchLink)
      launchLink = nil
    case "payoutActivity":
      payoutActivity(args, result: result)
    case "endPayoutActivity":
      endPayoutActivity(args["withdrawalId"] as? String, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func publishWidgets(_ args: [String: Any]) -> Bool {
    guard
      let timeline = args["timeline"],
      let data = try? JSONSerialization.data(withJSONObject: timeline),
      let json = String(data: data, encoding: .utf8),
      let defaults = SurfaceShared.defaults
    else { return false }
    if let dir = SurfaceShared.thumbsDirectory,
      let thumbs = args["thumbs"] as? [String: FlutterStandardTypedData]
    {
      try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
      for (name, bytes) in thumbs {
        let file = dir.appendingPathComponent((name as NSString).lastPathComponent)
        try? bytes.data.write(to: file, options: .atomic)
      }
    }
    defaults.set(json, forKey: SurfaceShared.timelineKey)
    WidgetCenter.shared.reloadAllTimelines()
    return true
  }

  private func payoutActivity(_ args: [String: Any], result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *), ActivityAuthorizationInfo().areActivitiesEnabled,
      let id = args["withdrawalId"] as? String,
      let amount = args["amount"] as? String,
      let headline = args["headline"] as? String,
      let detail = args["detail"] as? String,
      let step = args["step"] as? Int,
      let steps = args["steps"] as? [String],
      let compact = args["compact"] as? String,
      let link = args["link"] as? String
    else {
      result(false)
      return
    }
    let state = PayoutAttributes.ContentState(
      headline: headline, detail: detail, step: step, steps: steps,
      compact: compact, link: link)
    if let running = Activity<PayoutAttributes>.activities.first(where: {
      $0.attributes.withdrawalId == id
    }) {
      Task {
        await running.update(using: state)
        if step >= steps.count {
          await running.end(using: state, dismissalPolicy: .default)
        }
        result(true)
      }
      return
    }
    do {
      _ = try Activity.request(
        attributes: PayoutAttributes(withdrawalId: id, amount: amount),
        contentState: state)
      result(true)
    } catch {
      result(false)
    }
    #else
    result(false)
    #endif
  }

  private func endPayoutActivity(_ id: String?, result: @escaping FlutterResult) {
    #if canImport(ActivityKit)
    guard #available(iOS 16.1, *), let id else {
      result(false)
      return
    }
    Task {
      for activity in Activity<PayoutAttributes>.activities
      where activity.attributes.withdrawalId == id {
        await activity.end(dismissalPolicy: .immediate)
      }
      result(true)
    }
    #else
    result(false)
    #endif
  }
}
