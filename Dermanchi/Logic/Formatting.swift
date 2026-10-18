import Foundation

extension Date {
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "az_AZ")
        f.dateFormat = "HH:mm"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "az_AZ")
        f.dateFormat = "d MMMM, EEEE"
        return f
    }()

    private static let shortDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "az_AZ")
        f.dateFormat = "d MMMM"
        return f
    }()

    var hm: String { Self.timeFormatter.string(from: self) }
    var dayTitle: String { Self.dayFormatter.string(from: self) }
    var shortDay: String { Self.shortDayFormatter.string(from: self) }
}

/// "45 dəq", "1 saat 20 dəq"
func durationText(_ interval: TimeInterval) -> String {
    let total = max(0, Int((interval / 60).rounded(.up)))
    let h = total / 60, m = total % 60
    if h == 0 { return "\(m) dəq" }
    if m == 0 { return "\(h) saat" }
    return "\(h) saat \(m) dəq"
}
