import Foundation
import SwiftData

@MainActor
enum AppModel {
    nonisolated static let appGroupID = "group.com.raullte.dermanchi"

    /// Məlumat bazası App Group-dadır ki, widget də oxuya bilsin.
    static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "Dermanchi.store")
    }

    /// Tətbiq, bildiriş düymələri və widget eyni məlumat bazasını istifadə edir.
    static let container: ModelContainer = {
        let schema = Schema([DaySession.self, Dose.self])
        do {
            guard let url = storeURL else {
                return try ModelContainer(for: schema)
            }
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        } catch {
            fatalError("Could not open the SwiftData store: \(error)")
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

    /// "Yatıram" basılmayan günlər (normalda biri).
    static func openSessions(in context: ModelContext) -> [DaySession] {
        (try? context.fetch(FetchDescriptor<DaySession>(predicate: #Predicate { $0.endedAt == nil }))) ?? []
    }

    /// Hələ vurulmayan və buraxılmış sayılmayan dozalar, vaxt sırası ilə.
    func pendingDoses(at now: Date) -> [Dose] {
        sortedDoses.filter { $0.takenAt == nil && $0.status(at: now) != .missed }
    }

    /// "Yatıram" basılmayıb: gün əvvəlki təqvim günündən qalıb və gözləyən damcı da yoxdur
    /// (hamısı vurulub və ya buraxılıb). Belə gün artıq bitmiş sayılır.
    func isAbandoned(at now: Date, calendar: Calendar = .current) -> Bool {
        guard endedAt == nil, !calendar.isDate(startedAt, inSameDayAs: now) else { return false }
        return pendingDoses(at: now).isEmpty
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
