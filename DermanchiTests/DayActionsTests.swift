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
}
