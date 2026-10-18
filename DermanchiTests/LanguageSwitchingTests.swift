import XCTest
@testable import Dermanchi

/// Dil seçimi, sətirlərin düzgün dildə gəlməsi, cəm formaları və formatlayıcılar.
final class LanguageSwitchingTests: XCTestCase {
    private var originalSelection = LanguageModel.systemSelection

    override func setUp() {
        originalSelection = LanguageModel.shared.selection
    }

    override func tearDown() {
        LanguageModel.shared.select(originalSelection)
    }

    private func use(_ code: String) {
        LanguageModel.shared.select(code)
    }

    // MARK: - Dil seçimi

    func testExplicitSelectionWinsOverSystemLanguage() {
        XCTAssertEqual(L10n.resolve(selection: "en", preferredLanguages: ["az-AZ"]).code, "en")
        XCTAssertEqual(L10n.resolve(selection: "az", preferredLanguages: ["en-US"]).code, "az")
    }

    func testSystemSelectionPicksFirstSupportedPreferredLanguage() {
        XCTAssertEqual(L10n.resolve(selection: "system", preferredLanguages: ["tr-TR", "az-AZ", "en-US"]).code, "az")
        XCTAssertEqual(L10n.resolve(selection: "system", preferredLanguages: ["en-GB"]).code, "en")
        XCTAssertEqual(L10n.resolve(selection: "system", preferredLanguages: ["az-Latn-AZ"]).code, "az")
    }

    func testUnsupportedSystemLanguageFallsBackToEnglish() {
        XCTAssertEqual(L10n.resolve(selection: "system", preferredLanguages: ["ru-RU", "tr-TR"]).code, "en")
        XCTAssertEqual(L10n.resolve(selection: "system", preferredLanguages: []).code, "en")
        XCTAssertEqual(AppLanguage.fallback.code, "en")
    }

    func testUnknownStoredSelectionBecomesSystem() {
        let suite = UserDefaults(suiteName: "LanguageSwitchingTests.\(UUID().uuidString)")!
        suite.set("klingon", forKey: "appLanguage")
        XCTAssertEqual(LanguageModel(defaults: suite).selection, LanguageModel.systemSelection)

        let model = LanguageModel(defaults: suite)
        model.select("az")
        XCTAssertEqual(LanguageModel(defaults: suite).selection, "az", "Seçim yadda qalmalıdır")
        model.select("klingon")
        XCTAssertEqual(model.selection, LanguageModel.systemSelection)
    }

    // MARK: - Sətirlər

    func testPlainStringsFollowTheSelectedLanguage() {
        use("en")
        XCTAssertEqual(tr("Start the day"), "Start the day")
        XCTAssertEqual(tr("Taken"), "Taken")
        use("az")
        XCTAssertEqual(tr("Start the day"), "Günə başla")
        XCTAssertEqual(tr("Taken"), "Vurdum")
    }

    func testInterpolatedStringsKeepTheirArguments() {
        use("en")
        XCTAssertEqual(tr("Taken at \("10:00")"), "Taken at 10:00")
        XCTAssertEqual(tr("Next: \("Moxi-R") (in \(5) min)."), "Next: Moxi-R (in 5 min).")
        use("az")
        XCTAssertEqual(tr("Taken at \("10:00")"), "Vuruldu 10:00")
        XCTAssertEqual(tr("Next: \("Moxi-R") (in \(5) min)."), "Sonra: Moxi-R (5 dəq sonra).")
    }

    func testEnglishPluralsUseSingularAndPlural() {
        use("en")
        XCTAssertEqual(tr("Every \(1) hours"), "Every hour")
        XCTAssertEqual(tr("Every \(3) hours"), "Every 3 hours")
        XCTAssertEqual(tr("\(1) times a day"), "1 time a day")
        XCTAssertEqual(tr("\(4) times a day"), "4 times a day")
        XCTAssertEqual(tr("\(1) times today"), "1 time today")
    }

    func testPluralWithAnotherArgumentInTheSameSentence() {
        use("en")
        XCTAssertEqual(tr("From \("10:00") until now, \(1) drops will be logged as taken at their scheduled times."),
                       "From 10:00 until now, 1 drop will be logged as taken at their scheduled times.")
        XCTAssertEqual(tr("From \("10:00") until now, \(7) drops will be logged as taken at their scheduled times."),
                       "From 10:00 until now, 7 drops will be logged as taken at their scheduled times.")
        use("az")
        XCTAssertEqual(tr("From \("10:00") until now, \(7) drops will be logged as taken at their scheduled times."),
                       "10:00-dan indiyə qədərki 7 doza öz vaxtında vurulmuş kimi qeyd olunacaq.")
    }

    func testMedicationScheduleReadsNaturallyInBothLanguages() throws {
        let xiloial = try XCTUnwrap(Medication.with(id: "xiloial"))
        let moxi = try XCTUnwrap(Medication.with(id: "moxi-r"))
        let day = xiloial.startDate.addingTimeInterval(86_400)

        use("en")
        XCTAssertEqual(xiloial.scheduleDescription(on: day), "Every 2 hours · until bedtime")
        XCTAssertEqual(moxi.scheduleDescription(on: day), "5 times today · every 3 hours")
        use("az")
        XCTAssertEqual(xiloial.scheduleDescription(on: day), "Hər 2 saatdan bir · yatana qədər")
        XCTAssertEqual(moxi.scheduleDescription(on: day), "Bu gün 5 dəfə · hər 3 saatdan bir")
    }

    // MARK: - Formatlayıcılar

    func testDurationFollowsTheSelectedLanguage() {
        use("en")
        XCTAssertEqual(durationText(80 * 60), "1 hr, 20 min")
        XCTAssertEqual(durationText(5 * 60), "5 min")
        XCTAssertEqual(durationText(0), "0 min")
        use("az")
        XCTAssertEqual(durationText(80 * 60), "1 saat, 20 dəq")
        XCTAssertEqual(durationText(5 * 60), "5 dəq")
    }

    func testDurationRoundsPartialMinutesUp() {
        use("en")
        XCTAssertEqual(durationText(61), "2 min")
    }

    func testDayTitleUsesSelectedLanguageNames() {
        // 2026-10-18 bazar günüdür.
        let sunday = DateComponents(calendar: .current, year: 2026, month: 10, day: 18, hour: 12).date!
        use("en")
        XCTAssertTrue(sunday.dayTitle.contains("Sunday"), sunday.dayTitle)
        XCTAssertTrue(sunday.dayTitle.contains("October"), sunday.dayTitle)
        use("az")
        XCTAssertTrue(sunday.dayTitle.contains("Bazar"), sunday.dayTitle)
        XCTAssertTrue(sunday.dayTitle.contains("Oktyabr"), sunday.dayTitle)
        XCTAssertTrue(sunday.shortDay.contains("oktyabr"), sunday.shortDay)
    }

    func testLocaleCombinesSelectedLanguageWithSystemRegion() {
        use("az")
        XCTAssertEqual(L10n.locale.language.languageCode?.identifier, "az")
        use("en")
        XCTAssertEqual(L10n.locale.language.languageCode?.identifier, "en")
    }
}
