import Foundation
import SwiftUI
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
  let empty: String?
}

struct BriefRow: Decodable, Identifiable {
  let id: String
  let title: String
  let meta: String
  let thumb: String
  let link: String
  let closesAt: Double?
  let live: String?
}

struct PollsSection: Decodable {
  let count: String
  let label: String
  let line: String?
  let empty: String?
  let link: String
  let closesAt: Double?
  let live: String?
}

// Briefs within a day of their close count down live (Figma 1340:28610):
// the live text with the time ticking where "%s" stands. A closed brief
// keeps nothing to count.
enum LiveCountdown {
  static func closes(_ closesAt: Double?) -> Date? {
    closesAt.map { Date(timeIntervalSince1970: $0 / 1000) }
  }

  static func isOpen(_ closesAt: Double?, at now: Date = Date()) -> Bool {
    guard let end = closes(closesAt) else { return true }
    return end > now
  }

  static func text(_ live: String?, closesAt: Double?, fallback: String) -> Text {
    let now = Date()
    guard let live, live.contains("%s"), let end = closes(closesAt), end > now else {
      return Text(fallback)
    }
    let parts = live.components(separatedBy: "%s")
    let before = parts[0].replacingOccurrences(of: "%%", with: "%")
    let after = parts.dropFirst().joined(separator: "%s").replacingOccurrences(of: "%%", with: "%")
    return Text(before) + Text(timerInterval: now...end, countsDown: true) + Text(after)
  }
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
