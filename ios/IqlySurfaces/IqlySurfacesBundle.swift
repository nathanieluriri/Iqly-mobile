import SwiftUI
import WidgetKit

@main
struct IqlySurfacesBundle: WidgetBundle {
  var body: some Widget {
    ClosingSoonWidget()
    PollsWidget()
    if #available(iOSApplicationExtension 16.1, *) {
      PayoutLiveActivity()
    }
  }
}

struct SnapshotEntry: TimelineEntry {
  let date: Date
  let snapshot: WidgetSnapshotEntry?
}

struct SnapshotProvider: TimelineProvider {
  func placeholder(in context: Context) -> SnapshotEntry {
    SnapshotEntry(date: Date(), snapshot: nil)
  }

  func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
    let entries = WidgetTimelineStore.load()
    let now = Date()
    completion(SnapshotEntry(date: now, snapshot: entries.last { $0.date <= now } ?? entries.first))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
    let now = Date()
    let stored = WidgetTimelineStore.load()
    let current = stored.last { $0.date <= now } ?? stored.first
    var entries = [SnapshotEntry(date: now, snapshot: current)]
    entries += stored.filter { $0.date > now }.map { SnapshotEntry(date: $0.date, snapshot: $0) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}

struct WidgetHeader: View {
  var trailing: String?

  var body: some View {
    HStack(spacing: 6) {
      Image("WidgetLogomark")
        .resizable()
        .frame(width: 24, height: 24)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      Text("iQLY")
        .font(IqWidgetFont.strong)
        .foregroundColor(IqColors.fg)
      Spacer(minLength: 4)
      if let trailing {
        Text(trailing)
          .font(IqWidgetFont.regular)
          .foregroundColor(IqColors.fg3)
      }
    }
  }
}

// Mob/Small, Mob/Small strong, Mob/Body strong and Mob/Figure.
enum IqWidgetFont {
  static let regular = Font.custom("PlusJakartaSans-Regular", size: 13)
  static let strong = Font.custom("PlusJakartaSans-SemiBold", size: 13)
  static let meta = regular
  static let body = Font.custom("PlusJakartaSans-SemiBold", size: 15)
  static let figure = Font.custom("BricolageGrotesque30ptExtraBold", size: 30)
}

extension View {
  @ViewBuilder
  func iqWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(IqColors.card, for: .widget)
    } else {
      padding(14).background(IqColors.card)
    }
  }
}
