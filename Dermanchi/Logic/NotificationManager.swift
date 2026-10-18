import Foundation
import SwiftData
import UserNotifications

@MainActor
enum NotificationManager {
    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Aktiv günün bütün gələcək dozaları üçün bildirişləri yenidən qurur.
    static func sync(context: ModelContext, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let open = (try? context.fetch(FetchDescriptor<DaySession>(predicate: #Predicate { $0.endedAt == nil }))) ?? []
        guard let session = open.first else { return }

        let upcoming = session.sortedDoses.filter { $0.takenAt == nil && $0.scheduledAt > now }
        // iOS eyni anda maksimum 64 gözləyən bildiriş saxlayır.
        for (index, dose) in upcoming.prefix(60).enumerated() {
            guard let med = dose.medication else { continue }

            let content = UNMutableNotificationContent()
            content.title = "💧 \(med.name)"
            var body = "Hər iki gözə 1 damcı vurmaq vaxtıdır."
            if index + 1 < upcoming.count {
                let next = upcoming[index + 1]
                let minutes = Int(next.scheduledAt.timeIntervalSince(dose.scheduledAt) / 60)
                if minutes <= 15, let nextMed = next.medication {
                    body += " Sonra: \(nextMed.name) (\(minutes) dəq sonra)."
                }
            }
            content.body = body
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: dose.scheduledAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: dose.id.uuidString, content: content, trigger: trigger))
        }
    }
}

/// Tətbiq açıq olanda da bildirişləri göstərir.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}
