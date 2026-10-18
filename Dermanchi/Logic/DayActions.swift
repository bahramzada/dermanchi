import Foundation
import SwiftData
import WidgetKit

@MainActor
enum DayActions {
    /// İstifadəçi ilk damcını vurub "Günə başla" basanda.
    /// `start` keçmişdə ola bilər; `markPastAsTaken` olarsa, `start`-dan `now`-a qədərki dozalar
    /// öz vaxtlarında vurulmuş sayılır. `replacing` verilərsə, həmin gün silinib yenidən qurulur.
    static func startDay(
        firstMedicationID: String,
        start: Date = .now,
        markPastAsTaken: Bool = false,
        replacing: DaySession? = nil,
        now: Date = .now,
        context: ModelContext
    ) {
        if let replacing { context.delete(replacing) }
        closeForgottenSessions(context: context, except: replacing)

        let start = min(start, now)
        let session = DaySession(startedAt: start)
        context.insert(session)
        for planned in DoseScheduler.plan(start: start, firstMedicationID: firstMedicationID) {
            let dose = Dose(medicationID: planned.medicationID, priority: planned.priority, plannedAt: planned.plannedAt)
            dose.session = session
            context.insert(dose)
        }

        let doses = session.doses.sorted { ($0.plannedAt, $0.priority) < ($1.plannedAt, $1.priority) }
        let times = DoseScheduler.stagger(doses.map(\.plannedAt), after: nil)
        for (dose, time) in zip(doses, times) {
            dose.scheduledAt = time
        }
        doses.first?.takenAt = start
        if markPastAsTaken {
            for dose in doses where dose.scheduledAt <= now {
                dose.takenAt = dose.scheduledAt
            }
        }
        restagger(session, now: now)
        save(context)
    }

    static func markTaken(_ dose: Dose, at now: Date = .now, context: ModelContext) {
        dose.takenAt = now
        if let session = dose.session { restagger(session, now: now) }
        save(context)
    }

    static func undo(_ dose: Dose, at now: Date = .now, context: ModelContext) {
        dose.takenAt = nil
        if let session = dose.session { restagger(session, now: now) }
        save(context)
    }

    /// "Yatıram": gələcək dozalar silinir, gecikmiş olanlar buraxılmış kimi qalır.
    static func endDay(_ session: DaySession, at now: Date = .now, context: ModelContext) {
        for dose in session.doses where dose.takenAt == nil && dose.scheduledAt > now {
            context.delete(dose)
        }
        session.endedAt = now
        save(context)
    }

    /// Bildirişdən "10 dəq sonra xatırlat".
    static func snooze(_ dose: Dose, minutes: Int = 10, at now: Date = .now, context: ModelContext) {
        dose.snoozedUntil = now.addingTimeInterval(TimeInterval(minutes * 60))
        if let session = dose.session { restagger(session, now: now) }
        save(context)
    }

    /// Gözləyən dozaların bildiriş vaxtlarını son vurulan damcıdan ən azı 5 dəq. sonraya çəkir.
    /// Ertələmə bütün o vaxta qədərki damcı qrupunu sürüşdürür: ertələnən doza birinci,
    /// qalanları 5 dəq. fasilə ilə ondan sonra gəlir.
    static func restagger(_ session: DaySession, now: Date) {
        let pending = session.doses
            .filter { $0.takenAt == nil && ($0.status(at: now) != .missed || ($0.snoozedUntil ?? .distantPast) > now) }
        let snoozeFloor = pending.compactMap(\.snoozedUntil).filter { $0 > now }.max()
        func base(_ dose: Dose) -> Date {
            var t = max(dose.plannedAt, dose.snoozedUntil ?? dose.plannedAt)
            if let snoozeFloor, dose.plannedAt < snoozeFloor { t = max(t, snoozeFloor) }
            return t
        }
        func snoozedRank(_ dose: Dose) -> Int { (dose.snoozedUntil ?? .distantPast) > now ? 0 : 1 }
        let sorted = pending.sorted {
            (base($0), snoozedRank($0), $0.priority) < (base($1), snoozedRank($1), $1.priority)
        }
        let times = DoseScheduler.stagger(sorted.map(base), after: session.lastTakenAt)
        for (dose, time) in zip(sorted, times) {
            dose.scheduledAt = time
        }
    }

    /// "Yatıram" basılmayıbsa, köhnə günü son vurulan damcıda bitirir.
    /// Ondan sonrakı vurulmamış dozalar yuxu vaxtı sayılır və silinir.
    private static func closeForgottenSessions(context: ModelContext, except skipped: DaySession? = nil) {
        let open = (try? context.fetch(FetchDescriptor<DaySession>(predicate: #Predicate { $0.endedAt == nil }))) ?? []
        for session in open where session !== skipped {
            let end = session.lastTakenAt ?? session.startedAt
            for dose in session.doses where dose.takenAt == nil && dose.scheduledAt > end {
                context.delete(dose)
            }
            session.endedAt = end
        }
    }

    /// Bildirişdəki düymədən gələn əmri icra edir.
    static func handleNotificationAction(_ actionID: String, doseID: UUID, context: ModelContext, now: Date = .now) {
        let descriptor = FetchDescriptor<Dose>(predicate: #Predicate { $0.id == doseID })
        guard let dose = try? context.fetch(descriptor).first else { return }
        switch actionID {
        case NotificationManager.takenAction:
            if dose.takenAt == nil { markTaken(dose, at: now, context: context) }
        case NotificationManager.snoozeAction:
            if dose.takenAt == nil { snooze(dose, at: now, context: context) }
        default:
            break
        }
    }

    private static func save(_ context: ModelContext) {
        try? context.save()
        NotificationManager.sync(context: context)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
