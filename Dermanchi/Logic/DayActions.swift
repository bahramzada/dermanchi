import Foundation
import SwiftData

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

    /// Gözləyən dozaların bildiriş vaxtlarını son vurulan damcıdan ən azı 5 dəq. sonraya çəkir.
    static func restagger(_ session: DaySession, now: Date) {
        let pending = session.doses
            .filter { $0.takenAt == nil && $0.status(at: now) != .missed }
            .sorted { ($0.plannedAt, $0.priority) < ($1.plannedAt, $1.priority) }
        let times = DoseScheduler.stagger(pending.map(\.plannedAt), after: session.lastTakenAt)
        for (dose, time) in zip(pending, times) {
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

    private static func save(_ context: ModelContext) {
        try? context.save()
        NotificationManager.sync(context: context)
    }
}
