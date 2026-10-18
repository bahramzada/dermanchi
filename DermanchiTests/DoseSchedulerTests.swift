import XCTest
@testable import Dermanchi

final class DoseSchedulerTests: XCTestCase {
    private let cal = Calendar.current

    private func date(_ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: 2026, month: m, day: d, hour: h, minute: min))!
    }

    private var xiloial: Medication { Medication.with(id: "xiloial")! }
    private var moxi: Medication { Medication.with(id: "moxi-r")! }
    private var maxidex: Medication { Medication.with(id: "maxidex")! }

    func testMaxidexTaper() {
        XCTAssertEqual(maxidex.dailyDoses(on: date(10, 14)), .inactive)
        XCTAssertEqual(maxidex.dailyDoses(on: date(10, 15)), .count(5))
        XCTAssertEqual(maxidex.dailyDoses(on: date(10, 19)), .count(5))
        XCTAssertEqual(maxidex.dailyDoses(on: date(10, 20)), .count(4))
        XCTAssertEqual(maxidex.dailyDoses(on: date(10, 25)), .count(3))
        XCTAssertEqual(maxidex.dailyDoses(on: date(10, 30)), .count(2))
        XCTAssertEqual(maxidex.dailyDoses(on: date(11, 8)), .count(1))
        XCTAssertEqual(maxidex.dailyDoses(on: date(11, 9)), .inactive)
    }

    func testDurations() {
        XCTAssertEqual(moxi.dailyDoses(on: date(11, 13)), .count(5))
        XCTAssertEqual(moxi.dailyDoses(on: date(11, 14)), .inactive)
        XCTAssertEqual(xiloial.dailyDoses(on: date(12, 13)), .untilSleep)
        XCTAssertEqual(xiloial.dailyDoses(on: date(12, 14)), .inactive)
        XCTAssertEqual(xiloial.dayNumber(on: date(10, 18)), 5)
    }

    func testPlanPutsFirstMedicationFirstAndCountsDoses() {
        let start = date(10, 18, 8)
        let plan = DoseScheduler.plan(start: start, firstMedicationID: "maxidex")
        XCTAssertEqual(plan.first?.medicationID, "maxidex")
        XCTAssertEqual(plan.filter { $0.medicationID == "maxidex" }.count, 5)
        XCTAssertEqual(plan.filter { $0.medicationID == "moxi-r" }.count, 5)
        XCTAssertEqual(plan.filter { $0.medicationID == "xiloial" }.count, 10)
        XCTAssertEqual(plan.filter { $0.medicationID == "moxi-r" }.last?.plannedAt, date(10, 18, 20))
    }

    func testStaggerKeepsFiveMinuteGap() {
        let start = date(10, 18, 8)
        let plan = DoseScheduler.plan(start: start, firstMedicationID: "xiloial")
        let times = DoseScheduler.stagger(plan.map(\.plannedAt), after: nil)
        // 08:00 Xiloial, 08:05 Moxi-R, 08:10 Maxidex
        XCTAssertEqual(Array(times.prefix(3)), [date(10, 18, 8), date(10, 18, 8, 5), date(10, 18, 8, 10)])
        for (a, b) in zip(times, times.dropFirst()) {
            XCTAssertGreaterThanOrEqual(b.timeIntervalSince(a), DoseScheduler.gap)
        }
        for (t, p) in zip(times, plan) {
            XCTAssertGreaterThanOrEqual(t, p.plannedAt)
        }
    }

    func testStaggerAfterLateDose() {
        // 10:58-də vurulub; 11:00-dakı doza 11:03-ə keçməlidir.
        let times = DoseScheduler.stagger([date(10, 18, 11), date(10, 18, 11)], after: date(10, 18, 10, 58))
        XCTAssertEqual(times, [date(10, 18, 11, 3), date(10, 18, 11, 8)])
    }
}
