#if DEBUG
import Foundation
import SwiftData

/// Ekran şəkilləri üçün demo məlumat. Yalnız `-demo` arqumenti ilə işə düşür.
@MainActor
enum DemoData {
    static func seedIfRequested(context: ModelContext) {
        guard CommandLine.arguments.contains("-demo") else { return }
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

        DayActions.startDay(firstMedicationID: "xiloial",
                            start: now.addingTimeInterval(-(6 * 3600 + 50 * 60)),
                            markPastAsTaken: true, now: now, context: context)
        if let session = try? context.fetch(FetchDescriptor<DaySession>(predicate: #Predicate { $0.endedAt == nil })).first,
           let skipped = session.sortedDoses.first(where: { $0.medicationID == "maxidex" && $0.takenAt != nil && $0.priority > 0 && $0.scheduledAt > session.startedAt }) {
            skipped.takenAt = nil
        }
        try? context.save()
    }
}
#endif
