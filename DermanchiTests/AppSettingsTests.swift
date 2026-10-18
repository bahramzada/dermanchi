import XCTest
@testable import Dermanchi

final class AppSettingsTests: XCTestCase {
    private var original: Any?

    override func setUp() {
        original = LanguageModel.sharedDefaults.object(forKey: AppSettings.liveActivityKey)
    }

    override func tearDown() {
        if let original {
            LanguageModel.sharedDefaults.set(original, forKey: AppSettings.liveActivityKey)
        } else {
            LanguageModel.sharedDefaults.removeObject(forKey: AppSettings.liveActivityKey)
        }
    }

    func testLiveActivityIsOnByDefault() {
        LanguageModel.sharedDefaults.removeObject(forKey: AppSettings.liveActivityKey)
        XCTAssertTrue(AppSettings.liveActivityEnabled)
    }

    func testLiveActivitySettingPersists() {
        AppSettings.liveActivityEnabled = false
        XCTAssertFalse(AppSettings.liveActivityEnabled)
        XCTAssertEqual(LanguageModel.sharedDefaults.object(forKey: AppSettings.liveActivityKey) as? Bool, false)

        AppSettings.liveActivityEnabled = true
        XCTAssertTrue(AppSettings.liveActivityEnabled)
    }

    /// Settings-dəki `@AppStorage` ilə `AppSettings` eyni açarı və eyni yaddaşı oxumalıdır.
    func testSettingsScreenAndManagerShareTheSameStorage() {
        LanguageModel.sharedDefaults.set(false, forKey: AppSettings.liveActivityKey)
        XCTAssertFalse(AppSettings.liveActivityEnabled)
    }
}
