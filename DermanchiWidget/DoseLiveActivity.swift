import ActivityKit
import SwiftUI
import WidgetKit

/// Variant 1 · Geri sayım — Dynamic Island və kilid ekranı.
struct DoseLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DoseActivityAttributes.self) { context in
            let _ = MedicationStore.invalidate()
            DoseActivityLockView(state: context.state, isStale: context.isStale || context.state.isOverdue)
                .environment(\.locale, L10n.locale)
                .activityBackgroundTint(Color(red: 0.10, green: 0.13, blue: 0.20))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            MedicationStore.invalidate()
            let state = context.state
            let overdue = context.isStale || state.isOverdue
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(overdue ? tr("TAKE NOW") : tr("NEXT DROP"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(overdue ? .red : .white.opacity(0.6))
                        Label {
                            Text(state.name).lineLimit(1)
                        } icon: {
                            Image(systemName: "drop.fill").foregroundStyle(state.color)
                        }
                        .font(.headline)
                    }
                    .padding(.leading, 14)
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(state.scheduledAt.hm)
                        .font(.title3.weight(.semibold).monospacedDigit())
                        .padding(.trailing, 14)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    DoseActivityExpandedBottom(state: state, isStale: overdue)
                        .padding(.horizontal, 10)
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(state.color)
            } compactTrailing: {
                Text(state.scheduledAt, style: .timer)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundStyle(overdue ? .red : state.color)
            } minimal: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(overdue ? .red : state.color)
            }
            .keylineTint(state.color)
        }
    }
}
