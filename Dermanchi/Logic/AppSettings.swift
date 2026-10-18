import Foundation

/// İstifadəçi ayarları. Dil kimi App Group-da saxlanılır ki, widget də oxuya bilsin.
enum AppSettings {
    /// Dynamic Island və kilid ekranındakı Live Activity. Standart: açıq.
    static let liveActivityKey = "liveActivityEnabled"

    static var liveActivityEnabled: Bool {
        get { LanguageModel.sharedDefaults.object(forKey: liveActivityKey) as? Bool ?? true }
        set { LanguageModel.sharedDefaults.set(newValue, forKey: liveActivityKey) }
    }
}
