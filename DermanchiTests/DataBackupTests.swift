import SwiftData
import XCTest
@testable import Dermanchi

@MainActor
final class DataBackupTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ day: Int, _ h: Int, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h, minute: min))!
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(
            for: DaySession.self, Dose.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func snapshot(_ context: ModelContext) throws -> [[String]] {
        try context.fetch(FetchDescriptor<DaySession>(sortBy: [SortDescriptor(\.startedAt)])).map { session in
            ["\(session.startedAt.timeIntervalSince1970)", "\(session.endedAt?.timeIntervalSince1970 ?? 0)"]
                + session.sortedDoses.map {
                    "\($0.id)|\($0.medicationID)|\($0.priority)|\($0.plannedAt.timeIntervalSince1970)|"
                        + "\($0.scheduledAt.timeIntervalSince1970)|\($0.takenAt?.timeIntervalSince1970 ?? 0)|"
                        + "\($0.snoozedUntil?.timeIntervalSince1970 ?? 0)"
                }
        }
    }

    func testExportThenRestoreIntoAnEmptyStoreKeepsEverything() throws {
        let source = try makeContext()
        DayActions.startDay(firstMedicationID: "xiloial", start: date(17, 10), markPastAsTaken: true,
                            now: date(17, 22), context: source)
        let first = try XCTUnwrap(try source.fetch(FetchDescriptor<DaySession>()).first)
        DayActions.endDay(first, at: date(17, 22, 30), context: source)
        DayActions.startDay(firstMedicationID: "moxi-r", start: date(18, 10), markPastAsTaken: true,
                            now: date(18, 15), context: source)
        let open = try XCTUnwrap(DaySession.openSessions(in: source).first)
        let pending = try XCTUnwrap(open.pendingDoses(at: date(18, 15)).first)
        DayActions.snooze(pending, at: date(18, 15), context: source)

        let data = try DataBackup.export(context: source, now: date(18, 16))
        let target = try makeContext()
        XCTAssertEqual(try DataBackup.restore(data, context: target), 2)

        XCTAssertEqual(try snapshot(target), try snapshot(source))
        XCTAssertEqual(DaySession.openSessions(in: target).count, 1)
    }

    func testRestoreReplacesWhatIsAlreadyThere() throws {
        let source = try makeContext()
        DayActions.startDay(firstMedicationID: "xiloial", start: date(17, 10), now: date(17, 10), context: source)
        let data = try DataBackup.export(context: source)

        let target = try makeContext()
        DayActions.startDay(firstMedicationID: "maxidex", start: date(16, 9), now: date(16, 9), context: target)
        DayActions.startDay(firstMedicationID: "moxi-r", start: date(18, 9), now: date(18, 9), context: target)
        try DataBackup.restore(data, context: target)

        XCTAssertEqual(try target.fetch(FetchDescriptor<DaySession>()).count, 1)
        XCTAssertEqual(try snapshot(target), try snapshot(source))
    }

    func testUnreadableFileLeavesTheDataUntouched() throws {
        let context = try makeContext()
        DayActions.startDay(firstMedicationID: "xiloial", start: date(17, 10), now: date(17, 10), context: context)
        let before = try snapshot(context)

        XCTAssertThrowsError(try DataBackup.restore(Data("not json".utf8), context: context))
        let future = #"{"version":99,"exportedAt":"2026-10-18T10:00:00Z","sessions":[]}"#
        XCTAssertThrowsError(try DataBackup.restore(Data(future.utf8), context: context))

        XCTAssertEqual(try snapshot(context), before)
    }
}
