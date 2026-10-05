import ActivityKit
import SwiftUI
import WidgetKit

// Exp/LiveActivity: Lock screen (347:16446) and Island (347:16489).
@available(iOSApplicationExtension 16.1, *)
struct PayoutLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PayoutAttributes.self) { context in
      PayoutLockScreenView(state: context.state)
        .activityBackgroundTint(IqColors.brand)
        .activitySystemActionForegroundColor(IqColors.primaryFg)
        .widgetURL(URL(string: context.state.link))
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.bottom) {
          PayoutLockScreenView(state: context.state)
        }
      } compactLeading: {
        Image("WidgetLogomark")
          .resizable()
          .frame(width: 22, height: 22)
          .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
      } compactTrailing: {
        Text(context.state.compact)
          .font(IqWidgetFont.strong)
          .foregroundColor(IqColors.accent)
      } minimal: {
        Image("WidgetLogomark")
          .resizable()
          .frame(width: 22, height: 22)
          .clipShape(Circle())
      }
      .widgetURL(URL(string: context.state.link))
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
struct PayoutLockScreenView: View {
  let state: PayoutAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 10) {
        Image("WidgetLogomark")
          .resizable()
          .frame(width: 32, height: 32)
          .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        VStack(alignment: .leading, spacing: 2) {
          Text(state.headline)
            .font(IqWidgetFont.body)
          Text(state.detail)
            .font(IqWidgetFont.regular)
            .opacity(0.8)
            .lineLimit(1)
        }
        .foregroundColor(IqColors.primaryFg)
      }
      HStack(spacing: 6) {
        ForEach(Array(state.steps.enumerated()), id: \.offset) { index, label in
          let done = index < state.step
          VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
              .fill(done ? IqColors.accent : IqColors.primaryFg.opacity(0.3))
              .frame(height: 4)
            Text(label)
              .font(IqWidgetFont.regular)
              .foregroundColor(IqColors.primaryFg)
              .opacity(done ? 1 : 0.6)
          }
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}
