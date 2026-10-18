import Foundation
import Observation

/// Tətbiqin dəstəklədiyi dillər.
///
/// Yeni dil əlavə etmək üçün:
/// 1. aşağıdakı `supported` siyahısına bir sətir əlavə et;
/// 2. `Dermanchi/Resources/Localizable.xcstrings`-də hər açar üçün həmin dilin tərcüməsini yaz.
///
/// `LocalizationCatalogTests` hər iki addımın tam olmasını yoxlayır — tərcümə çatmayanda test düşür.
struct AppLanguage: Identifiable, Hashable {
    /// Dil kodu — kataloqdakı kodla eynidir (`en`, `az`, ...).
    let code: String
    /// Dilin öz adı. Ayarlarda həmişə bu şəkildə göstərilir, tərcümə olunmur.
    let nativeName: String

    var id: String { code }

    static let supported: [AppLanguage] = [
        AppLanguage(code: "en", nativeName: "English"),
        AppLanguage(code: "az", nativeName: "Azərbaycanca"),
    ]

    /// Sistem dili dəstəklənmədikdə istifadə olunan dil.
    static let fallback = supported[0]

    static func language(for code: String) -> AppLanguage? {
        supported.first { $0.code == code }
    }
}

/// İstifadəçinin seçdiyi dil. Seçim App Group-da saxlanılır ki, widget və Live Activity də oxuya bilsin.
///
/// `@Observable` olduğu üçün `tr(_:)` və tarix formatlayıcıları bu dəyəri oxuyan hər SwiftUI görünüşü
/// dil dəyişəndə avtomatik yenilənir.
@Observable
final class LanguageModel {
    static let shared = LanguageModel()

    /// "Sistem dili" seçimi.
    static let systemSelection = "system"
    private static let storageKey = "appLanguage"

    /// Tətbiq, widget və Live Activity-nin ortaq saxlanc yeri.
    static let sharedDefaults = UserDefaults(suiteName: AppModel.appGroupID) ?? .standard

    @ObservationIgnored private let defaults: UserDefaults

    /// `systemSelection` və ya `AppLanguage.code`.
    private(set) var selection: String

    init(defaults: UserDefaults = LanguageModel.sharedDefaults) {
        self.defaults = defaults
        self.selection = Self.storedSelection(in: defaults)
    }

    func select(_ value: String) {
        let normalized = AppLanguage.language(for: value) != nil ? value : Self.systemSelection
        guard normalized != selection else { return }
        defaults.set(normalized, forKey: Self.storageKey)
        selection = normalized
    }

    /// Yaddaşdan təzə seçimi oxuyur. Widget prosesi uzun yaşaya bildiyi üçün `selection`-a güvənmir.
    static func storedSelection(in defaults: UserDefaults = LanguageModel.sharedDefaults) -> String {
        guard let value = defaults.string(forKey: storageKey), AppLanguage.language(for: value) != nil else {
            return systemSelection
        }
        return value
    }
}

enum L10n {
    /// İndi istifadə olunan dil: seçim, yoxsa sistem dili, yoxsa ehtiyat dil (ingilis).
    static var language: AppLanguage {
        #if WIDGET_EXTENSION
        // Widget və Live Activity prosesi tətbiqdən ayrıdır və uzun yaşaya bilər: həmişə təzə dəyəri oxu.
        resolve(selection: LanguageModel.storedSelection())
        #else
        // `@Observable` oxunuşu: dil dəyişəndə bu dəyəri oxuyan SwiftUI görünüşləri yenilənir.
        resolve(selection: LanguageModel.shared.selection)
        #endif
    }

    /// Seçilmiş dil + cihazın regionu. Region vaxt formatını (12/24 saat) müəyyən edir.
    static var locale: Locale {
        locale(for: language)
    }

    /// Seçilmiş dilin `.lproj` qovluğu. Tapılmasa, əsas bundle.
    static var bundle: Bundle {
        bundles[language.code] ?? .main
    }

    static func resolve(selection: String, preferredLanguages: [String] = Locale.preferredLanguages) -> AppLanguage {
        if let chosen = AppLanguage.language(for: selection) { return chosen }
        for identifier in preferredLanguages {
            if let code = Locale(identifier: identifier).language.languageCode?.identifier,
               let match = AppLanguage.language(for: code) {
                return match
            }
        }
        return .fallback
    }

    static func locale(for language: AppLanguage, region: Locale.Region? = Locale.current.region) -> Locale {
        var components = Locale.Components(
            languageCode: Locale.LanguageCode(language.code), script: nil, languageRegion: region)
        components.hourCycle = Locale.current.hourCycle
        return Locale(components: components)
    }

    static func bundle(for language: AppLanguage) -> Bundle? {
        bundles[language.code]
    }

    private static let bundles: [String: Bundle] = {
        var result: [String: Bundle] = [:]
        for language in AppLanguage.supported {
            if let path = Bundle.main.path(forResource: language.code, ofType: "lproj"), let bundle = Bundle(path: path) {
                result[language.code] = bundle
            }
        }
        return result
    }()
}

/// Seçilmiş dildə sətir qaytarır. SwiftUI `Text("...")` literalları mühitdəki dili özü tapır;
/// `String` qaytaran yerlərdə (bildiriş, widget, funksiyalar) bunu istifadə et.
///
///     tr("Next: \(name) at \(time)")   // kataloqda açar: "Next: %@ at %@"
func tr(_ value: String.LocalizationValue) -> String {
    // Dil bir dəfə götürülür ki, bir cümlənin bundle-ı ilə formatı müxtəlif dildə olmasın.
    let language = L10n.language
    return String(localized: value, bundle: L10n.bundle(for: language) ?? .main, locale: L10n.locale(for: language))
}
