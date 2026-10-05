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
      Text(section?.label ?? "polls open")
        .font(IqWidgetFont.strong)
        .foregroundColor(IqColors.fg)
      if let line = section?.line {
        Text(line)
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
