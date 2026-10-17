import SwiftUI
import WidgetKit

// Exp/Widget Small (347:16187).
struct PollsWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "PollsWidget", provider: SnapshotProvider()) { entry in
      PollsView(section: entry.snapshot?.polls)
    }
    .configurationDisplayName("Polls")
    .description("Polls open")
    .supportedFamilies([.systemSmall])
  }
}

struct PollsView: View {
  let section: PollsSection?

  // Before the first snapshot, or with nothing open, the illustration
  // and its line stand in for a zero.
  private var empty: String? {
    guard let section else { return "No open polls right now" }
    if let empty = section.empty { return empty }
    return section.count == "0" ? "No open polls right now" : nil
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      WidgetHeader()
      Spacer(minLength: 0)
      HStack(alignment: .bottom, spacing: 6) {
        if empty == nil {
          Text(section?.count ?? "")
            .font(IqWidgetFont.figure)
            .tracking(-0.75)
            .foregroundColor(IqColors.fg)
            .modifier(NumberRoll(value: Double(section?.count ?? "") ?? 0))
        }
        Image("WidgetPollsArt")
          .resizable()
          .scaledToFit()
          .frame(width: 44, height: 35)
          .accessibilityHidden(true)
      }
      if let empty {
        Text(empty)
          .font(IqWidgetFont.strong)
          .foregroundColor(IqColors.fg)
          .lineLimit(2)
      } else {
        Text(section?.label ?? "polls open")
          .font(IqWidgetFont.strong)
          .foregroundColor(IqColors.fg)
        if let section, let line = section.line, LiveCountdown.isOpen(section.closesAt) {
          LiveCountdown.text(section.live, closesAt: section.closesAt, fallback: line)
            .font(IqWidgetFont.meta)
            .foregroundColor(IqColors.fg2)
            .lineLimit(1)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .widgetURL(section.flatMap { URL(string: $0.link) })
    .iqWidgetBackground()
  }
}

// The count rolls to its new number when the timeline moves on (iOS 17).
struct NumberRoll: ViewModifier {
  let value: Double

  func body(content: Content) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content.contentTransition(.numericText(value: value))
    } else {
      content
    }
  }
}
