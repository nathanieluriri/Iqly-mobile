import Foundation

#if canImport(ActivityKit)
import ActivityKit
#endif

// In both the Runner and the IqlySurfaces targets.
enum SurfaceShared {
  static let appGroup = "group.net.iqly.iqlyMobile"
  static let timelineKey = "widget_timeline"
  static let thumbsFolder = "surfaces"

  static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

  static var thumbsDirectory: URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
      .appendingPathComponent(thumbsFolder, isDirectory: true)
  }
}

#if canImport(ActivityKit)
// ContentState mirrors PayoutActivityState.toJson in lib/surfaces/live_activity.dart.
@available(iOS 16.1, *)
struct PayoutAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var headline: String
    var detail: String
    var step: Int
    var steps: [String]
    var compact: String
    var link: String
  }

  var withdrawalId: String
  var amount: String
}
#endif
