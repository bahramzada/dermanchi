import SwiftData
import XCTest
@testable import Dermanchi

@MainActor
final class WidgetStateTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ day: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: min))!
    }

    private func startedDay(now: Date) throws -> (ModelContext, DaySession) {
        let container = try ModelContainer(
            for: DaySession.self, Dose.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = ModelContext(container)
        DayActions.startDay(firstMedicationID: "xiloial", start: date(18, 10),
                            markPastAsTaken: true, now: now, context: context)
        let session = try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first)
        return (context, session)
    }

    func testNoSessionIsNotStarted() {
        XCTAssertEqual(WidgetState.make(session: nil, at: date(18, 9)).phase, .notStarted)
    }

    func testActiveDayShowsNextAndAfterWithProgress() throws {
        let (_, session) = try startedDay(now: date(18, 17, 8))
        let state = WidgetState.make(session: session, at: date(18, 17, 8))

        XCTAssertEqual(state.phase, .active)
        XCTAssertEqual(state.next?.medicationID, "xiloial")
        XCTAssertEqual(state.next?.scheduledAt, date(18, 18))
        XCTAssertEqual(state.next?.isDue, false)
        XCTAssertEqual(state.after?.medicationID, "moxi-r")
        XCTAssertEqual(state.after?.scheduledAt, date(18, 19))

        let moxi = try XCTUnwrap(state.progress.first { $0.medicationID == "moxi-r" })
        XCTAssertEqual(moxi.taken, 3)
        XCTAssertEqual(moxi.total, 5)
        let xiloial = try XCTUnwrap(state.progress.first { $0.medicationID == "xiloial" })
        XCTAssertNil(xiloial.total)
        XCTAssertEqual(state.missedCount, 0)
    }

    func testFutureEntryTurnsDueThenMissed() throws {
        let (_, session) = try startedDay(now: date(18, 17, 8))
        XCTAssertEqual(WidgetState.make(session: session, at: date(18, 18, 2)).next?.isDue, true)

        // 18:00 Xiloial bir saatdan çox gecikəndə buraxılmış sayılır, növbəti 19:00 Moxi-R olur.
        let later = WidgetState.make(session: session, at: date(18, 19, 1))
        XCTAssertEqual(later.missedCount, 1)
        XCTAssertNotEqual(later.next?.scheduledAt, date(18, 18))
    }

    func testEndedDayIsFinishedUntilMidnight() throws {
        let (context, session) = try startedDay(now: date(18, 17, 8))
        DayActions.endDay(session, at: date(18, 23), context: context)

        XCTAssertEqual(WidgetState.make(session: session, at: date(18, 23, 30)).phase, .finished)
        XCTAssertEqual(WidgetState.make(session: session, at: date(19, 8)).phase, .notStarted)
    }
}
