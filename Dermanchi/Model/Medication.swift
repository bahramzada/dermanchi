import SwiftUI

/// Bir gün ərzində dərmanın neçə dəfə vurulacağı.
enum DailyDoses: Equatable {
    case inactive
    case count(Int)
    /// "Yatıram" basılana qədər davam edir.
    case untilSleep
}

/// Dərman üçün seçilə bilən rənglər. Adla saxlanılır ki, fayla yazılanda rəng dəyişməsin.
enum MedicationColor: String, Codable, CaseIterable, Sendable {
    case blue, green, orange, red, purple, pink, teal, indigo

    var color: Color {
        switch self {
        case .blue: .blue
        case .green: .green
        case .orange: .orange
        case .red: .red
        case .purple: .purple
        case .pink: .pink
        case .teal: .teal
        case .indigo: .indigo
        }
    }
}

struct Medication: Identifiable, Hashable, Codable, Sendable {
    /// Müalicənin ardıcıl mərhələsi: `days` gün ərzində gündə `drops` dəfə.
    /// `drops == nil` — yatana qədər hər `intervalHours` saatdan bir.
    struct Phase: Hashable, Codable, Sendable {
        var days: Int
        var drops: Int?
    }

    var id: String
    var name: String
    var palette: MedicationColor
    var intervalHours: Int
    var startDate: Date
    var phases: [Phase]
    /// Silinmiş dərman cədvəldən çıxır, amma keçmiş günlərin adı və rəngi qalır.
    var isArchived = false

    var color: Color { palette.color }
    var interval: TimeInterval { TimeInterval(intervalHours * 3600) }
    var totalDays: Int { phases.reduce(0) { $0 + $1.days } }

    /// Müalicənin son günü (həmin gün daxildir).
    func lastDay(calendar: Calendar = .current) -> Date {
        calendar.date(byAdding: .day, value: totalDays - 1, to: startDate) ?? startDate
    }

    /// 1-dən başlayan gün nömrəsi (müalicənin neçənci günü).
    func dayNumber(on date: Date, calendar: Calendar = .current) -> Int {
        let day = calendar.startOfDay(for: date)
        return (calendar.dateComponents([.day], from: calendar.startOfDay(for: startDate), to: day).day ?? 0) + 1
    }

    /// `date` günü hansı mərhələdədir (`nil` — müalicə getmir).
    func phaseIndex(on date: Date, calendar: Calendar = .current) -> Int? {
        var remaining = dayNumber(on: date, calendar: calendar) - 1
        guard remaining >= 0 else { return nil }
        for (index, phase) in phases.enumerated() {
            if remaining < phase.days { return index }
            remaining -= phase.days
        }
        return nil
    }

    /// Mərhələnin ilk və son günü (hər ikisi daxil).
    func range(ofPhase index: Int, calendar: Calendar = .current) -> (from: Date, to: Date) {
        let before = phases.prefix(index).reduce(0) { $0 + $1.days }
        let from = calendar.date(byAdding: .day, value: before, to: startDate) ?? startDate
        let to = calendar.date(byAdding: .day, value: phases[index].days - 1, to: from) ?? from
        return (from, to)
    }

    func dailyDoses(on date: Date, calendar: Calendar = .current) -> DailyDoses {
        guard let index = phaseIndex(on: date, calendar: calendar) else { return .inactive }
        return phases[index].drops.map { .count($0) } ?? .untilSleep
    }

    func scheduleDescription(on date: Date) -> String {
        switch dailyDoses(on: date) {
        case .inactive: return tr("Not today")
        case .untilSleep: return tr("Every \(intervalHours) hours") + " · " + tr("until bedtime")
        case .count(let n): return tr("\(n) times today") + " · " + tr("every \(intervalHours) hours")
        }
    }
}

extension Medication {
    /// Tətbiq ilk dəfə açılanda olan üç dərman. İdlər köhnə qeydlərlə eynidir.
    static var defaults: [Medication] {
        let cal = Calendar.current
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d))!
        }
        return [
            Medication(id: "xiloial", name: "Xiloial", palette: .blue, intervalHours: 2,
                       startDate: day(2026, 10, 14), phases: [Phase(days: 61, drops: nil)]),
            Medication(id: "moxi-r", name: "Moxi-R", palette: .green, intervalHours: 3,
                       startDate: day(2026, 10, 14), phases: [Phase(days: 31, drops: 5)]),
            // 5+4+3+2+1 — hər mərhələ 5 gün, cəmi 25 gün.
            Medication(id: "maxidex", name: "Maxidex", palette: .orange, intervalHours: 3,
                       startDate: day(2026, 10, 15), phases: (1...5).reversed().map { Phase(days: 5, drops: $0) }),
        ]
    }

    /// Cədvələ düşən dərmanlar (silinmişlər yox).
    static var all: [Medication] {
        MedicationStore.current.filter { !$0.isArchived }
    }

    /// Silinmiş dərman da tapılır: keçmiş günlərin adı və rəngi üçün.
    static func with(id: String) -> Medication? {
        MedicationStore.current.first { $0.id == id }
    }

    static func active(on date: Date) -> [Medication] {
        all.filter { $0.dailyDoses(on: date) != .inactive }
    }
}
