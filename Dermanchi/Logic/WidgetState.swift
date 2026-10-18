import Foundation

/// Widget-in göstərdiyi hər şey — konkret bir an üçün hesablanır.
struct WidgetState: Equatable {
    struct NextDose: Equatable {
        let id: UUID
        let medicationID: String
        let scheduledAt: Date
        let isDue: Bool

        var medication: Medication? { Medication.with(id: medicationID) }
    }

    struct Progress: Equatable, Identifiable {
        let medicationID: String
        let taken: Int
        /// `nil` — "yatana qədər" dərmanlar üçün.
        let total: Int?
        let missed: Int

        var id: String { medicationID }
        var medication: Medication? { Medication.with(id: medicationID) }
    }

    enum Phase: Equatable {
        /// Bu gün hələ "Günə başla" basılmayıb.
        case notStarted
        case active
        /// "Yatıram" basılıb, gözləyən damcı yoxdur.
        case finished
    }

    var phase: Phase
    var next: NextDose?
    var after: NextDose?
    var progress: [Progress] = []
    var missedCount = 0

    static let notStarted = WidgetState(phase: .notStarted)

    /// Aktiv (və ya son) gündən `date` anı üçün vəziyyət.
    static func make(session: DaySession?, at date: Date, calendar: Calendar = .current) -> WidgetState {
        guard let session else { return .notStarted }
        if session.endedAt != nil {
            // Gecə yarısından sonra yeni gün başlamalıdır.
            return calendar.isDate(session.startedAt, inSameDayAs: date) ? WidgetState(phase: .finished) : .notStarted
        }

        // "Yatıram" unudulub və səhər olub: widget "Gün bitdi" yox, yeni gün təklif etməlidir.
        if session.isAbandoned(at: date, calendar: calendar) { return .notStarted }

        let doses = session.sortedDoses
        let upcoming = doses.filter { $0.takenAt == nil && $0.status(at: date) != .missed }
        func snapshot(_ dose: Dose?) -> NextDose? {
            dose.map { NextDose(id: $0.id, medicationID: $0.medicationID,
                                scheduledAt: $0.scheduledAt, isDue: $0.status(at: date) == .due) }
        }

        let progress = Medication.all.compactMap { med -> Progress? in
            let mine = doses.filter { $0.medicationID == med.id }
            guard !mine.isEmpty else { return nil }
            let total: Int? = med.dailyDoses(on: session.startedAt) == .untilSleep ? nil : mine.count
            return Progress(medicationID: med.id,
                            taken: mine.filter { $0.takenAt != nil }.count,
                            total: total,
                            missed: mine.filter { $0.status(at: date) == .missed }.count)
        }

        return WidgetState(
            phase: upcoming.isEmpty ? .finished : .active,
            next: snapshot(upcoming.first),
            after: snapshot(upcoming.dropFirst().first),
            progress: progress,
            missedCount: progress.reduce(0) { $0 + $1.missed })
    }
}
