#if !WIDGET_EXTENSION
import ActivityKit
import Foundation
import SwiftData

/// "Növbəti damcı" Live Activity-sini aktiv günlə sinxron saxlayır:
/// gün başlayanda açılır, hər dəyişiklikdə yenilənir, "Yatıram" ilə bağlanır.
@MainActor
enum LiveActivityManager {
    /// iOS activity-ni ~8 saatdan sonra bitirir. Bundan əvvəl yenisi ilə əvəz edirik.
    static let maxAge: TimeInterval = 7 * 3600

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func sync(context: ModelContext, now: Date = .now) {
        guard !isRunningTests else { return }

        let open = (try? context.fetch(FetchDescriptor<DaySession>(predicate: #Predicate { $0.endedAt == nil }))) ?? []
        let state = DoseActivityAttributes.ContentState.make(session: open.first, at: now)
        let activities = Activity<DoseActivityAttributes>.activities

        guard let state, ActivityAuthorizationInfo().areActivitiesEnabled else {
            end(activities)
            return
        }

        // Damcının vaxtı keçəndə activity "köhnəlmiş" sayılır və görünüş qırmızıya keçir.
        let content = ActivityContent(state: state, staleDate: state.scheduledAt)
        let live = activities.filter { $0.activityState == .active }

        if let current = live.first, now.timeIntervalSince(current.attributes.startedAt) < maxAge {
            Task { await current.update(content) }
            end(Array(live.dropFirst()))
        } else {
            end(activities)
            do {
                _ = try Activity.request(
                    attributes: DoseActivityAttributes(startedAt: now),
                    content: content,
                    pushType: nil)
            } catch {
                // Məs. tətbiq arxa plandadır və ya istifadəçi Live Activity-ləri söndürüb.
                // Tətbiq növbəti dəfə açılanda yenidən cəhd olunur.
            }
        }
    }

    private static func end(_ activities: [Activity<DoseActivityAttributes>]) {
        for activity in activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
#endif
