import Foundation
import SwiftData

@MainActor
enum AppModel {
    /// Tətbiq və bildiriş düymələri eyni məlumat bazasını istifadə edir.
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: DaySession.self, Dose.self)
        } catch {
            fatalError("SwiftData açılmadı: \(error)")
        }
    }()
}

/// "Günə başla" ilə "Yatıram" arasındakı bir gün.
@Model
final class DaySession {
    var startedAt: Date
    var endedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \Dose.session)
    var doses: [Dose] = []

    init(startedAt: Date) {
        self.startedAt = startedAt
    }

    var isActive: Bool { endedAt == nil }

    var sortedDoses: [Dose] {
        doses.sorted { ($0.scheduledAt, $0.priority) < ($1.scheduledAt, $1.priority) }
    }

    var lastTakenAt: Date? {
        doses.compactMap(\.takenAt).max()
    }
}

enum DoseStatus {
    case taken, upcoming, due, missed
}

@Model
final class Dose {
    var id: UUID
    var medicationID: String
    /// Eyni vaxta düşən damcıların sırası.
    var priority: Int
    /// Cədvələ görə əsl vaxt (dəyişmir).
    var plannedAt: Date
    /// Bildiriş vaxtı — damcılar arası 5 dəq. fasilə üçün sürüşdürülə bilər.
    var scheduledAt: Date
    var takenAt: Date?
    /// Bildirişdən "10 dəq sonra" basılıbsa, bu vaxtdan tez xatırladılmır.
    var snoozedUntil: Date?
    var session: DaySession?

    init(medicationID: String, priority: Int, plannedAt: Date) {
        self.id = UUID()
        self.medicationID = medicationID
        self.priority = priority
        self.plannedAt = plannedAt
        self.scheduledAt = plannedAt
    }

    var medication: Medication? { Medication.with(id: medicationID) }

    func status(at now: Date) -> DoseStatus {
        if takenAt != nil { return .taken }
        if session?.endedAt != nil { return .missed }
        if now > scheduledAt.addingTimeInterval(DoseScheduler.missedAfter) { return .missed }
        if now >= scheduledAt { return .due }
        return .upcoming
    }
}
