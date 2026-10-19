import SwiftData
import XCTest
@testable import Dermanchi

@MainActor
final class MedicationEditingTests: XCTestCase {
    private let cal = Calendar.current

    override func setUp() { MedicationStore.reset() }
    override func tearDown() { MedicationStore.reset() }

    private func date(_ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: m, day: d, hour: h, minute: min))!
    }

    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(
            for: DaySession.self, Dose.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    /// 18 oktyabr 10:00-da başlanmış, 15:00-a qədər vurulmuş gün.
    private func startedDay() throws -> (ModelContext, DaySession) {
        let context = try makeContext()
        DayActions.startDay(firstMedicationID: "xiloial", start: date(10, 18, 10), markPastAsTaken: true,
                            now: date(10, 18, 15), context: context)
        return (context, try XCTUnwrap(try context.fetch(FetchDescriptor<DaySession>()).first))
    }

    private func edit(_ id: String, _ change: (inout Medication) -> Void) throws {
        var all = MedicationStore.current
        let index = try XCTUnwrap(all.firstIndex { $0.id == id })
        change(&all[index])
        MedicationStore.save(all)
    }

    private func doses(_ session: DaySession, _ id: String) -> [Dose] {
        session.sortedDoses.filter { $0.medicationID == id }
    }

    // MARK: - Phases

    /// "Maxidex-i 5 gün daha gündə 5 damcı ilə davam et": birinci mərhələ 5 gün uzadılır.
    func testExtendingAPhaseShiftsTheRestOfTheCourse() throws {
        try edit("maxidex") { $0.phases[0].days = 10 }
        let maxidex = try XCTUnwrap(Medication.with(id: "maxidex"))

        XCTAssertEqual(maxidex.dailyDoses(on: date(10, 24)), .count(5))
        XCTAssertEqual(maxidex.dailyDoses(on: date(10, 25)), .count(4))
        XCTAssertEqual(maxidex.dailyDoses(on: date(11, 13)), .count(1))
        XCTAssertEqual(maxidex.dailyDoses(on: date(11, 14)), .inactive)
        XCTAssertEqual(maxidex.totalDays, 30)
        XCTAssertEqual(maxidex.lastDay(), date(11, 13))
    }

    func testPhaseRangesFollowEachOther() throws {
        let maxidex = try XCTUnwrap(Medication.with(id: "maxidex"))
        XCTAssertEqual(maxidex.range(ofPhase: 0).from, date(10, 15))
        XCTAssertEqual(maxidex.range(ofPhase: 0).to, date(10, 19))
        XCTAssertEqual(maxidex.range(ofPhase: 1).from, date(10, 20))
        XCTAssertEqual(maxidex.range(ofPhase: 4).to, date(11, 8))
        XCTAssertEqual(maxidex.phaseIndex(on: date(10, 21)), 1)
        XCTAssertNil(maxidex.phaseIndex(on: date(10, 14)))
    }

    // MARK: - Store

    func testStoreKeepsEditsAndResetRestoresDefaults() throws {
        XCTAssertEqual(MedicationStore.current, Medication.defaults)
        try edit("moxi-r") { $0.name = "Moxi-R 0.5%"; $0.intervalHours = 4 }

        MedicationStore.invalidate()  // başqa prosesdə olduğu kimi yaddaşdan təzədən oxu
        XCTAssertEqual(Medication.with(id: "moxi-r")?.name, "Moxi-R 0.5%")
        XCTAssertEqual(Medication.with(id: "moxi-r")?.intervalHours, 4)

        MedicationStore.reset()
        XCTAssertEqual(Medication.with(id: "moxi-r")?.name, "Moxi-R")
    }

    func testAddedMedicationIsListedAndDeletedOneKeepsItsNameForHistory() throws {
        let new = Medication(id: "new", name: "Systane", palette: .teal, intervalHours: 6,
                             startDate: date(10, 18), phases: [.init(days: 7, drops: 2)])
        MedicationStore.save(MedicationStore.current + [new])
        XCTAssertTrue(Medication.all.contains { $0.id == "new" })
        XCTAssertEqual(Medication.active(on: date(10, 20)).map(\.id).contains("new"), true)

        try edit("new") { $0.isArchived = true }
        XCTAssertFalse(Medication.all.contains { $0.id == "new" })
        XCTAssertEqual(Medication.with(id: "new")?.name, "Systane")
        XCTAssertFalse(Medication.active(on: date(10, 20)).contains { $0.id == "new" })
    }

    // MARK: - Aktiv günün uyğunlaşdırılması

    func testRaisingDropsPerDayAddsOnlyFutureDoses() throws {
        let (context, session) = try startedDay()
        XCTAssertEqual(doses(session, "maxidex").count, 5)
        let takenBefore = session.doses.filter { $0.takenAt != nil }.map(\.id)

        try edit("maxidex") { $0.phases[0].drops = 6 }
        DayActions.applyMedicationChanges(context: context, now: date(10, 18, 15))

        let maxidex = doses(session, "maxidex")
        XCTAssertEqual(maxidex.count, 6)
        XCTAssertEqual(maxidex.last?.plannedAt, date(10, 19, 1, 0))
        XCTAssertEqual(Set(session.doses.filter { $0.takenAt != nil }.map(\.id)), Set(takenBefore))
    }

    func testLoweringDropsPerDayRemovesOnlyPendingFutureDoses() throws {
        let (context, session) = try startedDay()
        try edit("maxidex") { $0.phases[0].drops = 3 }
        DayActions.applyMedicationChanges(context: context, now: date(10, 18, 15))

        let maxidex = doses(session, "maxidex")
        XCTAssertEqual(maxidex.count, 3)
        // 10:10, 13:10 vurulub, 16:10 gözləyir.
        XCTAssertEqual(maxidex.map { $0.takenAt != nil }, [true, true, false])
    }

    func testDeletingAMedicationRemovesItsPendingDosesAndKeepsWhatWasTaken() throws {
        let (context, session) = try startedDay()
        let takenXiloial = doses(session, "xiloial").filter { $0.takenAt != nil }.count
        XCTAssertGreaterThan(takenXiloial, 0)

        try edit("xiloial") { $0.isArchived = true }
        DayActions.applyMedicationChanges(context: context, now: date(10, 18, 15))

        let remaining = doses(session, "xiloial")
        XCTAssertEqual(remaining.count, takenXiloial)
        XCTAssertTrue(remaining.allSatisfy { $0.takenAt != nil })
        XCTAssertEqual(remaining.first?.medication?.name, "Xiloial")
    }

    func testNewMedicationStartsAtItsNextFutureDoseNotRetroactively() throws {
        let (context, session) = try startedDay()
        let new = Medication(id: "new", name: "Systane", palette: .teal, intervalHours: 6,
                             startDate: date(10, 18), phases: [.init(days: 5, drops: 2)])
        MedicationStore.save(MedicationStore.current + [new])
        DayActions.applyMedicationChanges(context: context, now: date(10, 18, 15))

        // 10:00 doza artıq keçib, sonradan əlavə olunan dərman üçün buraxılmış yazılmır; 16:00 gələcəkdədir.
        XCTAssertEqual(doses(session, "new").map(\.plannedAt), [date(10, 18, 16)])
    }

    func testApplyingChangesWithoutAnOpenDayDoesNothing() throws {
        let context = try makeContext()
        try edit("maxidex") { $0.phases[0].drops = 6 }
        DayActions.applyMedicationChanges(context: context, now: date(10, 18, 15))
        XCTAssertTrue(try context.fetch(FetchDescriptor<Dose>()).isEmpty)
    }

    // MARK: - Ehtiyat nüsxə

    func testBackupCarriesTheMedicationList() throws {
        let context = try makeContext()
        try edit("maxidex") { $0.phases[0].days = 10 }
        let data = try DataBackup.export(context: context)

        MedicationStore.reset()
        XCTAssertEqual(Medication.with(id: "maxidex")?.phases[0].days, 5)
        try DataBackup.restore(data, context: context)
        XCTAssertEqual(Medication.with(id: "maxidex")?.phases[0].days, 10)
    }

    func testBackupFromBeforeMedicationsWereEditableKeepsTheCurrentList() throws {
        let context = try makeContext()
        try edit("maxidex") { $0.phases[0].days = 10 }
        let old = #"{"version":1,"exportedAt":"2026-10-18T10:00:00Z","sessions":[]}"#
        try DataBackup.restore(Data(old.utf8), context: context)
        XCTAssertEqual(Medication.with(id: "maxidex")?.phases[0].days, 10)
    }
}
