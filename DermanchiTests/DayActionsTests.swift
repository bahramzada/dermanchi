import SwiftData
import XCTest
@testable import Dermanchi

@MainActor
final class DayActionsTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: h, minute: min))!
    }

    func testBackfilledStartMarksPastDosesAndSchedulesRest() throws {
        let container = try ModelContainer(
            for: DaySession.self, Dose.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        DayActions.startDay(firstMedicationID: "xiloial", start: date(10),
                            markPastAsTaken: true, now: date(16, 35), context: context)

        let session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)
        func taken(_ id: String) -> [Date] {
            session.doses.filter { $0.medicationID == id }.compactMap(\.takenAt).sorted()
        }
        XCTAssertEqual(taken("xiloial"), [date(10), date(12), date(14), date(16)])
        XCTAssertEqual(taken("moxi-r"), [date(10, 5), date(13), date(16, 5)])
        XCTAssertEqual(taken("maxidex"), [date(10, 10), date(13, 5), date(16, 10)])

        let next = session.sortedDoses.filter { $0.takenAt == nil }.prefix(3)
        XCTAssertEqual(next.map(\.medicationID), ["xiloial", "moxi-r", "maxidex"])
        XCTAssertEqual(next.map(\.scheduledAt), [date(18), date(19), date(19, 5)])
    }

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: DaySession.self, Dose.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    func testSnoozeFromNotificationDelaysDoseAndRespacesNext() throws {
        let context = try makeContext()
        DayActions.startDay(firstMedicationID: "xiloial", start: date(10),
                            markPastAsTaken: true, now: date(15, 59), context: context)
        let session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)
        // 16:00 Xiloial, 16:05 Moxi-R, 16:10 Maxidex gözləyir.
        let xiloial = try XCTUnwrap(session.sortedDoses.first { $0.takenAt == nil })
        XCTAssertEqual(xiloial.scheduledAt, date(16))

        DayActions.handleNotificationAction(NotificationManager.snoozeAction, doseID: xiloial.id,
                                            context: context, now: date(16))

        XCTAssertNil(xiloial.takenAt)
        XCTAssertEqual(xiloial.scheduledAt, date(16, 10))
        let pending = session.sortedDoses.filter { $0.takenAt == nil }.prefix(3)
        // Bütün 16:00 qrupu ertələnir: Xiloial 16:10, sonra Moxi-R 16:15, Maxidex 16:20.
        XCTAssertEqual(pending.map(\.medicationID), ["xiloial", "moxi-r", "maxidex"])
        XCTAssertEqual(pending.map(\.scheduledAt), [date(16, 10), date(16, 15), date(16, 20)])
    }

    /// Başlanğıc vaxtı düzəldiləndə buraxılmış damcılar "vurulmuş" olmamalı, əsl vurulma vaxtları itməməlidir.
    func testEditingStartKeepsMissedDosesAndRealTakenTimes() throws {
        let context = try makeContext()
        DayActions.startDay(firstMedicationID: "xiloial", start: date(10), now: date(10), context: context)
        var session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)
        let moxi = try XCTUnwrap(session.sortedDoses.first { $0.medicationID == "moxi-r" })
        DayActions.markTaken(moxi, at: date(10, 20), context: context)

        let now = date(13, 30)
        func missedCount(_ s: DaySession) -> Int { s.doses.filter { $0.status(at: now) == .missed }.count }
        let missedBefore = missedCount(session)
        XCTAssertGreaterThan(missedBefore, 0)

        DayActions.startDay(firstMedicationID: "xiloial", start: date(10), markPastAsTaken: true,
                            replacing: session, now: now, context: context)

        session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)
        XCTAssertEqual(missedCount(session), missedBefore)
        XCTAssertEqual(session.doses.first { $0.medicationID == "moxi-r" && $0.plannedAt == date(10) }?.takenAt, date(10, 20))
    }

    func testEditingStartStillBackfillsDosesThatDidNotExistBefore() throws {
        let context = try makeContext()
        DayActions.startDay(firstMedicationID: "xiloial", start: date(12), now: date(12), context: context)
        var session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)

        // Başlanğıc 2 saat tezə çəkilir: 10:00–12:00 arası dozaların köhnə qarşılığı yoxdur.
        DayActions.startDay(firstMedicationID: "xiloial", start: date(10), markPastAsTaken: true,
                            replacing: session, now: date(12, 30), context: context)
        session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)
        let xiloial = session.sortedDoses.filter { $0.medicationID == "xiloial" && $0.scheduledAt <= date(12, 30) }
        XCTAssertEqual(xiloial.count, 2)
        XCTAssertTrue(xiloial.allSatisfy { $0.takenAt != nil })
    }

    /// "Yatıram" unudulub: səhər gün özü bitir, widget isə "Günə başla" təklif edir.
    func testForgottenSleepIsClosedTheNextMorning() throws {
        let context = try makeContext()
        DayActions.startDay(firstMedicationID: "xiloial", start: date(10),
                            markPastAsTaken: true, now: date(22), context: context)
        let session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)
        let nextMorning = cal.date(byAdding: .day, value: 1, to: date(8))!
        let lateEvening = cal.date(byAdding: .day, value: 1, to: date(0, 30))!

        // Gecə yarısından sonra hələ gözləyən damcı var: gün davam edir.
        XCTAssertFalse(session.isAbandoned(at: lateEvening))
        DayActions.closeAbandonedSessions(context: context, now: lateEvening)
        XCTAssertNil(session.endedAt)

        XCTAssertEqual(WidgetState.make(session: session, at: nextMorning).phase, .notStarted)
        XCTAssertTrue(session.isAbandoned(at: nextMorning))
        DayActions.closeAbandonedSessions(context: context, now: nextMorning)
        XCTAssertEqual(session.endedAt, date(22))
        // Buraxılmış dozalar tarixçədə qalır.
        XCTAssertFalse(session.doses.isEmpty)
    }

    func testTodaysSessionIsNeverAbandoned() throws {
        let context = try makeContext()
        DayActions.startDay(firstMedicationID: "xiloial", start: date(10), now: date(10), context: context)
        let session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)
        // Hamısı buraxılsa da (məs. telefon uzun söndürülüb), eyni gündə bitmiş sayılmır.
        XCTAssertFalse(session.isAbandoned(at: date(23, 59)))
    }

    func testTakenFromNotificationMarksDose() throws {
        let context = try makeContext()
        DayActions.startDay(firstMedicationID: "xiloial", start: date(10),
                            markPastAsTaken: true, now: date(15, 59), context: context)
        let session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)
        let next = try XCTUnwrap(session.sortedDoses.first { $0.takenAt == nil })

        DayActions.handleNotificationAction(NotificationManager.takenAction, doseID: next.id,
                                            context: context, now: date(16, 2))

        XCTAssertEqual(next.takenAt, date(16, 2))
        // Növbəti damcı vurulandan ən azı 5 dəq. sonra.
        let following = try XCTUnwrap(session.sortedDoses.first { $0.takenAt == nil })
        XCTAssertEqual(following.scheduledAt, date(16, 7))
    }
}
