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

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      WidgetHeader()
      Spacer(minLength: 0)
      Text(section?.count ?? "")
        .font(IqWidgetFont.figure)
        .tracking(-0.75)
        .foregroundColor(IqColors.fg)
        .modifier(NumberRoll(value: Double(section?.count ?? "") ?? 0))
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
