import Foundation
import SwiftData

@MainActor
enum AppModel {
    nonisolated static let appGroupID = "group.com.raullte.dermanchi"
    nonisolated private static let migratedKey = "legacyStoreMigrated"

    /// Məlumat bazası App Group-dadır ki, widget də oxuya bilsin.
    static var storeURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appending(path: "Dermanchi.store")
    }

    static var isExtension: Bool { Bundle.main.bundlePath.hasSuffix(".appex") }

    /// Tətbiq, bildiriş düymələri və widget eyni məlumat bazasını istifadə edir.
    static let container: ModelContainer = {
        let schema = Schema([DaySession.self, Dose.self])
        do {
            guard let url = storeURL else {
                return try ModelContainer(for: schema)
            }
            if !isExtension { migrateLegacyStoreIfNeeded(to: url) }
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, url: url))
        } catch {
            fatalError("Could not open the SwiftData store: \(error)")
        }
    }()

    /// Widget-dən əvvəlki versiyalar məlumatı tətbiqin öz qovluğunda saxlayırdı
    /// (Application Support/default.store). Bir dəfəlik App Group-a köçürülür.
    private static func migrateLegacyStoreIfNeeded(to url: URL) {
        let fm = FileManager.default
        let defaults = UserDefaults(suiteName: appGroupID)
        guard defaults?.bool(forKey: migratedKey) != true else { return }
        defer { defaults?.set(true, forKey: migratedKey) }

        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let legacy = support.appending(path: "default.store")
        guard fm.fileExists(atPath: legacy.path) else { return }

        let suffixes = ["", "-shm", "-wal"]
        for suffix in suffixes {
            try? fm.removeItem(at: URL(fileURLWithPath: url.path + suffix))
        }
        for suffix in suffixes {
            let src = URL(fileURLWithPath: legacy.path + suffix)
            guard fm.fileExists(atPath: src.path) else { continue }
            try? fm.copyItem(at: src, to: URL(fileURLWithPath: url.path + suffix))
        }
    }

    /// Widget bazaya yalnız tətbiq köçürməni bitirəndən sonra toxunur.
    nonisolated static var isStoreReady: Bool {
        UserDefaults(suiteName: appGroupID)?.bool(forKey: migratedKey) == true
    }
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

    /// "Yatıram" basılmayıb: gün əvvəlki təqvim günündən qalıb və gözləyən damcı da yoxdur
    /// (hamısı vurulub və ya buraxılıb). Belə gün artıq bitmiş sayılır.
    func isAbandoned(at now: Date, calendar: Calendar = .current) -> Bool {
        guard endedAt == nil, !calendar.isDate(startedAt, inSameDayAs: now) else { return false }
        return !doses.contains { $0.takenAt == nil && $0.status(at: now) != .missed }
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
