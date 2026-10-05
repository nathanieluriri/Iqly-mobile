import Foundation
import UIKit

// Decodes WidgetTimeline.toJson from lib/surfaces/widget_snapshot.dart.
struct WidgetTimelineFile: Decodable {
  let version: Int
  let entries: [WidgetSnapshotEntry]
}

struct WidgetSnapshotEntry: Decodable {
  let at: Double
  let closingSoon: ClosingSoonSection
  let polls: PollsSection

  var date: Date { Date(timeIntervalSince1970: at / 1000) }
}

struct ClosingSoonSection: Decodable {
  let title: String
  let link: String
  let rows: [BriefRow]
}

struct BriefRow: Decodable, Identifiable {
  let id: String
  let title: String
  let meta: String
  let thumb: String
  let link: String
}

struct PollsSection: Decodable {
  let count: String
  let label: String
  let line: String?
  let link: String
}

enum WidgetTimelineStore {
  static func load() -> [WidgetSnapshotEntry] {
    guard
      let raw = SurfaceShared.defaults?.string(forKey: SurfaceShared.timelineKey),
      let data = raw.data(using: .utf8),
      let file = try? JSONDecoder().decode(WidgetTimelineFile.self, from: data)
    else { return [] }
    return file.entries
  }

  static func thumb(_ name: String) -> UIImage? {
    guard let dir = SurfaceShared.thumbsDirectory else { return nil }
    let url = dir.appendingPathComponent((name as NSString).lastPathComponent)
    return UIImage(contentsOfFile: url.path)
  }
}
