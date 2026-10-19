import Foundation
import Observation
import os

/// Dərmanların siyahısı. App Group-da JSON kimi saxlanılır ki, widget və Live Activity də oxuya bilsin.
/// Heç nə yazılmayıbsa `Medication.defaults` istifadə olunur.
enum MedicationStore {
    static let key = "medications"

    /// SwiftUI görünüşləri `current`-i oxuyanda bu saygaca baxır və siyahı dəyişəndə yenilənir.
    @Observable
    final class Revision {
        var value = 0
    }

    // Yalnız `value` oxunur/artırılır, yazma əsas thread-dən olur.
    nonisolated(unsafe) static let revision = Revision()

    private static let cache = OSAllocatedUnfairLock<[Medication]?>(initialState: nil)

    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    /// Testlər real telefonun/simulyatorun ayarlarına toxunmasın deyə ayrı yaddaş istifadə edir.
    private static var defaults: UserDefaults {
        isRunningTests
            ? UserDefaults(suiteName: "com.raullte.dermanchi.tests") ?? .standard
            : LanguageModel.sharedDefaults
    }

    static var current: [Medication] {
        _ = revision.value
        if let cached = cache.withLock({ $0 }) { return cached }
        let loaded = read() ?? Medication.defaults
        cache.withLock { $0 = loaded }
        return loaded
    }

    static func save(_ medications: [Medication]) {
        guard let data = try? JSONEncoder().encode(medications) else { return }
        defaults.set(data, forKey: key)
        cache.withLock { $0 = medications }
        revision.value += 1
    }

    /// Başqa prosesdə (tətbiqdə) dəyişibsə, növbəti oxunuşda yaddaşdan təzədən götürülür.
    static func invalidate() {
        cache.withLock { $0 = nil }
    }

    /// Standart üç dərmana qayıdır.
    static func reset() {
        defaults.removeObject(forKey: key)
        invalidate()
        revision.value += 1
    }

    private static func read() -> [Medication]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode([Medication].self, from: data)
    }
}
