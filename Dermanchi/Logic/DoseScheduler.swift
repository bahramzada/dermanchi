import Foundation

struct PlannedDose: Equatable {
    let medicationID: String
    let priority: Int
    let plannedAt: Date
}

enum DoseScheduler {
    /// Damcılar arası minimum fasilə.
    static let gap: TimeInterval = 5 * 60
    /// "Yatana qədər" dərmanlar üçün nə qədər irəli planlaşdırılır.
    static let untilSleepHorizon: TimeInterval = 18 * 3600
    /// Bu qədər gecikən doza "buraxıldı" sayılır.
    static let missedAfter: TimeInterval = 60 * 60

    /// Günün bütün dozalarını `start` anından başlayaraq planlaşdırır.
    /// `firstMedicationID` — istifadəçinin ilk vurduğu damcı; eyni vaxta düşəndə o birinci gəlir.
    static func plan(
        start: Date,
        firstMedicationID: String?,
        medications: [Medication] = Medication.all,
        calendar: Calendar = .current
    ) -> [PlannedDose] {
        var ordered = medications
        if let first = firstMedicationID, let i = ordered.firstIndex(where: { $0.id == first }) {
            ordered.insert(ordered.remove(at: i), at: 0)
        }

        var result: [PlannedDose] = []
        for (priority, med) in ordered.enumerated() {
            let count: Int
            switch med.dailyDoses(on: start, calendar: calendar) {
            case .inactive: continue
            case .count(let n): count = n
            case .untilSleep: count = Int(untilSleepHorizon / med.interval) + 1
            }
            for i in 0..<count {
                result.append(PlannedDose(
                    medicationID: med.id,
                    priority: priority,
                    plannedAt: start.addingTimeInterval(Double(i) * med.interval)
                ))
            }
        }
        return result.sorted { ($0.plannedAt, $0.priority) < ($1.plannedAt, $1.priority) }
    }

    /// Başlanğıc vaxtı düzəldiləndə yeni cədvəldəki hər dozanı köhnə günün dozası ilə əlaqələndirir:
    /// eyni dərman, ən yaxın planlanmış vaxt (yarım interval daxilində), hər köhnə doza yalnız bir dəfə.
    /// Nəticənin `i`-ci elementi `planned[i]`-nin köhnə qarşılığının `previous`-dakı indeksidir (yoxdursa `nil`).
    static func match(
        previous: [(medicationID: String, plannedAt: Date)],
        planned: [(medicationID: String, plannedAt: Date)]
    ) -> [Int?] {
        var free = Array(previous.indices)
        return planned.map { dose in
            let tolerance = (Medication.with(id: dose.medicationID)?.interval ?? 0) / 2
            func distance(_ i: Int) -> TimeInterval { abs(previous[i].plannedAt.timeIntervalSince(dose.plannedAt)) }
            let best = free
                .filter { previous[$0].medicationID == dose.medicationID && distance($0) <= tolerance }
                .min { distance($0) < distance($1) }
            if let best { free.removeAll { $0 == best } }
            return best
        }
    }

    /// Planlanmış vaxtları elə sürüşdürür ki, ardıcıl damcılar arasında ən azı `gap` olsun.
    /// Heç bir doza planlanmış vaxtından və ya `anchor + gap`-dan tez qoyulmur.
    static func stagger(_ planned: [Date], after anchor: Date?) -> [Date] {
        var previous = anchor
        return planned.map { p in
            var t = p
            if let previous { t = max(t, previous.addingTimeInterval(gap)) }
            previous = t
            return t
        }
    }
}
