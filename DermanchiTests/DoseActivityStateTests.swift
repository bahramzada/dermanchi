import SwiftData
import XCTest
@testable import Dermanchi

@MainActor
final class DoseActivityStateTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: 18, hour: h, minute: min))!
    }

    private func startedDay(now: Date) throws -> (ModelContext, DaySession) {
        let container = try ModelContainer(
            for: DaySession.self, Dose.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        DayActions.startDay(firstMedicationID: "xiloial", start: date(10),
                            markPastAsTaken: true, now: now, context: context)
        let session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)
        return (context, session)
    }

    func testNoActivityWithoutActiveDay() {
        XCTAssertNil(DoseActivityAttributes.ContentState.make(session: nil, at: date(9)))
    }

    func testNextDoseCountdownAndProgressStartAtLastTakenDrop() throws {
        let (_, session) = try startedDay(now: date(17, 8))
        let state = try XCTUnwrap(DoseActivityAttributes.ContentState.make(session: session, at: date(17, 8)))

        XCTAssertEqual(state.medicationID, "xiloial")
        XCTAssertEqual(state.scheduledAt, date(18))
        // Son vurulan damcı 16:10 Maxidex — zolaq oradan 18:00-a qədər dolur.
        XCTAssertEqual(state.intervalStart, date(16, 10))
        XCTAssertEqual(state.afterMedicationID, "moxi-r")
        XCTAssertEqual(state.afterScheduledAt, date(19))
    }

    func testTakingDoseMovesActivityToNextDrop() throws {
        let (context, session) = try startedDay(now: date(17, 59))
        let next = try XCTUnwrap(session.sortedDoses.first { $0.takenAt == nil })
        DayActions.markTaken(next, at: date(18, 1), context: context)

        let state = try XCTUnwrap(DoseActivityAttributes.ContentState.make(session: session, at: date(18, 1)))
        XCTAssertEqual(state.medicationID, "moxi-r")
        XCTAssertEqual(state.scheduledAt, date(19))
        XCTAssertEqual(state.intervalStart, date(18, 1))
    }

    func testOverdueFlagFollowsTheDoseTime() throws {
        let (_, session) = try startedDay(now: date(17, 8))
        XCTAssertEqual(DoseActivityAttributes.ContentState.make(session: session, at: date(17, 8))?.isOverdue, false)
        // 18:00 Xiloial vaxtı keçib (1 saatdan az gecikmə) — hələ buraxılmış sayılmır.
        XCTAssertEqual(DoseActivityAttributes.ContentState.make(session: session, at: date(18, 5))?.isOverdue, true)
    }

    func testProgressRangeIsNeverEmpty() throws {
        // Vurulan damcıdan dərhal sonra növbəti damcı 5 dəq. sonradır, zolaq yenə ən azı 1 dəqiqədir.
        let (_, session) = try startedDay(now: date(10, 1))
        let state = try XCTUnwrap(DoseActivityAttributes.ContentState.make(session: session, at: date(10, 1)))
        XCTAssertLessThan(state.intervalStart, state.scheduledAt)
        XCTAssertGreaterThanOrEqual(state.scheduledAt.timeIntervalSince(state.intervalStart), 60)
    }

    func testEndedDayHasNoActivity() throws {
        let (context, session) = try startedDay(now: date(17, 8))
        DayActions.endDay(session, at: date(23), context: context)
        XCTAssertNil(DoseActivityAttributes.ContentState.make(session: session, at: date(23, 1)))
    }
}
