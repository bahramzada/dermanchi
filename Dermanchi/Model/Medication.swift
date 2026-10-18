import SwiftUI

/// Bir gün ərzində dərmanın neçə dəfə vurulacağı.
enum DailyDoses: Equatable {
    case inactive
    case count(Int)
    /// "Yatıram" basılana qədər davam edir.
    case untilSleep
}

struct Medication: Identifiable, Hashable {
    enum Rule: Hashable {
        /// Yatana qədər hər `intervalHours` saatdan bir.
        case untilSleep
        /// Gündə sabit sayda.
        case fixed(Int)
        /// `start` dəfədən başlayır, hər `stepDays` gündən bir 1 azalır.
        case taper(start: Int, stepDays: Int)
    }

    let id: String
    let name: String
    let color: Color
    let intervalHours: Int
    let startDate: Date
    /// Bu gün daxil deyil — müalicə bu tarixdən əvvəl bitir.
    let endDate: Date
    let rule: Rule

    var interval: TimeInterval { TimeInterval(intervalHours * 3600) }

    func totalDays(calendar: Calendar = .current) -> Int {
        calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }

    /// 1-dən başlayan gün nömrəsi (müalicənin neçənci günü).
    func dayNumber(on date: Date, calendar: Calendar = .current) -> Int {
        let day = calendar.startOfDay(for: date)
        return (calendar.dateComponents([.day], from: startDate, to: day).day ?? 0) + 1
    }

    func dailyDoses(on date: Date, calendar: Calendar = .current) -> DailyDoses {
        let index = dayNumber(on: date, calendar: calendar) - 1
        guard index >= 0, index < totalDays(calendar: calendar) else { return .inactive }
        switch rule {
        case .untilSleep:
            return .untilSleep
        case .fixed(let n):
            return .count(n)
        case .taper(let start, let step):
            let n = start - index / step
            return n > 0 ? .count(n) : .inactive
        }
    }

    func scheduleDescription(on date: Date) -> String {
        switch dailyDoses(on: date) {
        case .inactive: return "Bu gün yoxdur"
        case .untilSleep: return "Hər \(intervalHours) saatdan bir · yatana qədər"
        case .count(let n): return "Bu gün \(n) dəfə · hər \(intervalHours) saatdan bir"
        }
    }
}

extension Medication {
    static let all: [Medication] = {
        let cal = Calendar.current
        func day(_ y: Int, _ m: Int, _ d: Int) -> Date {
            cal.date(from: DateComponents(year: y, month: m, day: d))!
        }
        let xiloialStart = day(2026, 10, 14)
        let moxiStart = day(2026, 10, 14)
        let maxidexStart = day(2026, 10, 15)
        return [
            Medication(
                id: "xiloial", name: "Xiloial", color: .blue, intervalHours: 2,
                startDate: xiloialStart,
                endDate: cal.date(byAdding: .month, value: 2, to: xiloialStart)!,
                rule: .untilSleep
            ),
            Medication(
                id: "moxi-r", name: "Moxi-R", color: .green, intervalHours: 3,
                startDate: moxiStart,
                endDate: cal.date(byAdding: .month, value: 1, to: moxiStart)!,
                rule: .fixed(5)
            ),
            Medication(
                id: "maxidex", name: "Maxidex", color: .orange, intervalHours: 3,
                startDate: maxidexStart,
                // 5+4+3+2+1 — hər mərhələ 5 gün, cəmi 25 gün.
                endDate: cal.date(byAdding: .day, value: 25, to: maxidexStart)!,
                rule: .taper(start: 5, stepDays: 5)
            ),
        ]
    }()

    static func with(id: String) -> Medication? {
        all.first { $0.id == id }
    }

    static func active(on date: Date) -> [Medication] {
        all.filter { $0.dailyDoses(on: date) != .inactive }
    }
}
