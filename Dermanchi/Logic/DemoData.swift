#if DEBUG
import Foundation
import SwiftData

/// Ekran şəkilləri üçün demo məlumat. Yalnız `-demo` arqumenti ilə işə düşür.
@MainActor
enum DemoData {
    static func seedIfRequested(context: ModelContext) {
        guard CommandLine.arguments.contains("-demo") else { return }
        // Ekran şəkilləri üçün dil: `-demo-lang en`
        if let flag = CommandLine.arguments.firstIndex(of: "-demo-lang"), flag + 1 < CommandLine.arguments.count {
            LanguageModel.shared.select(CommandLine.arguments[flag + 1])
        }
        try? context.delete(model: Dose.self)
        try? context.delete(model: DaySession.self)

        let now = Date.now
        let cal = Calendar.current
        for daysAgo in (1...3).reversed() {
            let day = cal.date(byAdding: .day, value: -daysAgo, to: now)!
            let start = cal.date(bySettingHour: 9, minute: 30, second: 0, of: day)!
            let end = cal.date(bySettingHour: 23, minute: 15, second: 0, of: day)!
            DayActions.startDay(firstMedicationID: "xiloial", start: start,
                                markPastAsTaken: true, now: end, context: context)
            if let session = try? context.fetch(FetchDescriptor<DaySession>(predicate: #Predicate { $0.endedAt == nil })).first {
                if daysAgo == 2, let skipped = session.sortedDoses.dropFirst(7).first {
                    skipped.takenAt = nil
                }
                DayActions.endDay(session, at: end, context: context)
            }
        }

        // `-demo-due`: növbəti damcının vaxtı 90 saniyə əvvəl keçib (qırmızı "TAKE NOW" vəziyyəti).
        let due = CommandLine.arguments.contains("-demo-due")
        let startOffset: TimeInterval = due ? 6 * 3600 + 90 : 6 * 3600 + 50 * 60
        DayActions.startDay(firstMedicationID: "xiloial",
                            start: now.addingTimeInterval(-startOffset),
                            markPastAsTaken: true, now: now, context: context)
        if let session = try? context.fetch(FetchDescriptor<DaySession>(predicate: #Predicate { $0.endedAt == nil })).first,
           let skipped = session.sortedDoses.first(where: { $0.medicationID == "maxidex" && $0.takenAt != nil && $0.priority > 0 && $0.scheduledAt > session.startedAt }) {
            skipped.takenAt = nil
        }
        if due,
           let session = try? context.fetch(FetchDescriptor<DaySession>(predicate: #Predicate { $0.endedAt == nil })).first {
            session.sortedDoses.last { $0.takenAt != nil && $0.scheduledAt <= now }?.takenAt = nil
        }
        try? context.save()
        DayActions.refreshSurfaces(context: context)
    }
}
#endif
