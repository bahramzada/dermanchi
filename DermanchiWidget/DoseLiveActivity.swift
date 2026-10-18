import ActivityKit
import SwiftUI
import WidgetKit

/// Variant 1 · Geri sayım — Dynamic Island və kilid ekranı.
struct DoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseActivityAttributes.self) { context in
            DoseActivityLockView(state: context.state, isStale: context.isStale)
                .environment(\.locale, Locale(identifier: "az_AZ"))
                .activityBackgroundTint(Color(red: 0.10, green: 0.13, blue: 0.20))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.isStale ? "İNDİ VUR" : "NÖVBƏTİ DAMCI")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(context.isStale ? .red : .white.opacity(0.6))
                        Label {
                            Text(state.name).lineLimit(1)
                        } icon: {
                            Image(systemName: "drop.fill").foregroundStyle(state.color)
                        }
                        .font(.headline)
                    }
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.scheduledAt.hm)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DoseActivityExpandedBottom(state: state, isStale: context.isStale)
                        .padding(.horizontal, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                    Text(state.name)
                        .lineLimit(1)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(state.color)
            } compactTrailing: {
                Text(state.scheduledAt, style: .timer)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 58)
                    .foregroundStyle(context.isStale ? .red : state.color)
            } minimal: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(context.isStale ? .red : state.color)
            }
            .keylineTint(state.color)
        }
    }
}
