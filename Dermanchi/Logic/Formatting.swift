import Foundation

/// Tarix və vaxt formatları seçilmiş dilə və cihazın regionuna görə sistemin öz formatlayıcıları ilə çıxarılır:
/// ayrıca dil üçün əl ilə yazılmış format yoxdur.
extension Date {
    /// "09:06" və ya "9:06 AM"
    var hm: String {
        formatted(.dateTime.hour().minute().locale(L10n.locale))
    }

    /// "18 Oktyabr, Bazar" və ya "Sunday, October 18"
    var dayTitle: String {
        formatted(.dateTime.weekday(.wide).day().month(.wide).locale(L10n.locale))
            .capitalized(with: L10n.locale)
    }

    /// "18 oktyabr" və ya "October 18"
    var shortDay: String {
        formatted(.dateTime.day().month(.wide).locale(L10n.locale))
    }
}

/// "45 dəq", "1 saat, 20 dəq" / "45 min", "1 hr, 20 min"
func durationText(_ interval: TimeInterval) -> String {
    let minutes = max(0, Int((interval / 60).rounded(.up)))
    let units: Set<Duration.UnitsFormatStyle.Unit> = minutes >= 60 ? [.hours, .minutes] : [.minutes]
    let style = Duration.UnitsFormatStyle(allowedUnits: units, width: .abbreviated).locale(L10n.locale)
    return Duration.seconds(minutes * 60).formatted(style)
}
