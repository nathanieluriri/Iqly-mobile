import SwiftUI
import WidgetKit

// Exp/Widget Medium (347:16187).
struct ClosingSoonWidget: Widget {
  var body: some WidgetConfiguration {
    StaticConfiguration(kind: "ClosingSoonWidget", provider: SnapshotProvider()) { entry in
      ClosingSoonView(section: entry.snapshot?.closingSoon)
    }
    .configurationDisplayName("Closing soon")
    .description("Briefs closing soon")
    .supportedFamilies([.systemMedium])
  }
}

struct ClosingSoonView: View {
  let section: ClosingSoonSection?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      WidgetHeader(trailing: section?.title ?? "Closing soon")
      ForEach(section?.rows ?? []) { row in
        Link(destination: URL(string: row.link) ?? URL(string: "iqly://app/home")!) {
          HStack(spacing: 12) {
            thumb(row.thumb)
            VStack(alignment: .leading, spacing: 2) {
              Text(row.title)
                .font(IqWidgetFont.strong)
                .foregroundColor(IqColors.fg)
                .lineLimit(2)
              Text(row.meta)
                .font(IqWidgetFont.meta)
                .foregroundColor(IqColors.fg2)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
          }
        }
      }
      if section?.rows.isEmpty ?? true {
        Spacer(minLength: 0)
        HStack(spacing: 12) {
          Image("WidgetBriefsArt")
            .resizable()
            .scaledToFit()
            .frame(width: 70, height: 56)
            .accessibilityHidden(true)
          Text(section?.empty ?? "Nothing closing soon")
            .font(IqWidgetFont.strong)
            .foregroundColor(IqColors.fg)
            .lineLimit(2)
          Spacer(minLength: 0)
        }
      }
      Spacer(minLength: 0)
    }
    .widgetURL(section.flatMap { URL(string: $0.link) })
    .iqWidgetBackground()
  }

  @ViewBuilder
  private func thumb(_ name: String) -> some View {
    if let image = WidgetTimelineStore.thumb(name) {
      Image(uiImage: image).resizable().frame(width: 44, height: 44)
    } else {
      RoundedRectangle(cornerRadius: 10).fill(IqColors.panel).frame(width: 44, height: 44)
    }
  }
}
