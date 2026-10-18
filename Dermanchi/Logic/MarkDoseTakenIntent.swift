import AppIntents
import Foundation

/// Widget-dəki "Vurdum" düyməsi.
/// `LiveActivityIntent` olduğu üçün sistem onu tətbiqin prosesində işə salır:
/// beləcə bildirişlər də dərhal yenidən qurulur.
struct MarkDoseTakenIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Damcını vurulmuş qeyd et"
    static let isDiscoverable = false

    @Parameter(title: "Doza")
    var doseID: String

    init() {}

    init(doseID: UUID) {
        self.doseID = doseID.uuidString
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        if let id = UUID(uuidString: doseID) {
            DayActions.handleNotificationAction(
                NotificationManager.takenAction, doseID: id, context: AppModel.container.mainContext)
        }
        return .result()
    }
}
