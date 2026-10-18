#if !WIDGET_EXTENSION
import ActivityKit
import Foundation
import OSLog
import SwiftData

/// "Növbəti damcı" Live Activity-sini aktiv günlə sinxron saxlayır:
/// gün başlayanda açılır, hər dəyişiklikdə yenilənir, "Yatıram" ilə bağlanır.
@MainActor
enum LiveActivityManager {
    private static let logger = Logger(subsystem: "com.raullte.dermanchi", category: "LiveActivity")

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

        guard let state, AppSettings.liveActivityEnabled, ActivityAuthorizationInfo().areActivitiesEnabled else {
            end(activities)
            return
        }

        // Damcının vaxtı keçəndə activity "köhnəlmiş" sayılır və görünüş qırmızıya keçir.
        // Tarix artıq keçibsə heç qoyulmur: keçmiş köhnəlmə tarixi ilə başlayan activity ekranda görünmür.
        // Bu halda qırmızı görünüşü `state.isOverdue` verir.
        let content = ActivityContent(state: state, staleDate: state.scheduledAt > now ? state.scheduledAt : nil)
        // Vaxtı keçmiş damcıda activity `stale` olur — o da canlıdır, bağlanıb yenidən başladılmamalıdır.
        let live = activities.filter { $0.activityState == .active || $0.activityState == .stale }

        if let current = live.first, now.timeIntervalSince(current.attributes.startedAt) < maxAge {
            Task { await current.update(content) }
            end(Array(live.dropFirst()))
            return
        }

        // Yeni activity əvvəl açılır, köhnə yalnız bundan sonra bağlanır: tətbiq arxa planda (məs. bildiriş
        // düyməsi ilə) işləyirsə iOS yeni activity açmağa icazə verməyə bilər, onda köhnəsi qalmalıdır.
        do {
            _ = try Activity.request(
                attributes: DoseActivityAttributes(startedAt: now),
                content: content,
                pushType: nil)
            end(activities)
        } catch {
            // Tətbiq növbəti dəfə açılanda yenidən cəhd olunur.
            logger.error("Live Activity failed to start: \(error.localizedDescription, privacy: .public)")
            if let current = live.first {
                Task { await current.update(content) }
                end(Array(live.dropFirst()))
            } else {
                end(activities)
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
