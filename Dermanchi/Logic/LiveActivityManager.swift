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

        let state = DoseActivityAttributes.ContentState.make(session: DaySession.openSessions(in: context).first, at: now)
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
            update(current, content)
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
                update(current, content)
                end(Array(live.dropFirst()))
            } else {
                end(activities)
            }
        }
    }

    /// Yeniləmələr və bağlamalar sırayla icra olunur: ayrı `Task`-lar ard-arda gələndə köhnə vəziyyət
    /// yenisindən sonra çatıb Live Activity-ni geri qaytara bilərdi.
    private static var queue: Task<Void, Never>?

    private static func enqueue(_ work: @escaping @MainActor () async -> Void) {
        let previous = queue
        queue = Task {
            await previous?.value
            await work()
        }
    }

    private static func update(_ activity: Activity<DoseActivityAttributes>, _ content: ActivityContent<DoseActivityAttributes.ContentState>) {
        // `Activity` yalnız bu sıradan istifadə olunur.
        nonisolated(unsafe) let activity = activity
        enqueue { await activity.update(content) }
    }

    private static func end(_ activities: [Activity<DoseActivityAttributes>]) {
        for activity in activities {
            nonisolated(unsafe) let activity = activity
            enqueue { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
#endif
