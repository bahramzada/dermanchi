import Foundation
import SwiftData
import UserNotifications

@MainActor
enum NotificationManager {
    nonisolated static let doseCategory = "DOSE"
    nonisolated static let takenAction = "DOSE_TAKEN"
    nonisolated static let snoozeAction = "DOSE_SNOOZE"

    /// Bildirişi basıb saxlayanda (və ya kilid ekranında sola çəkəndə) çıxan düymələr.
    nonisolated static func registerCategories() {
        let taken = UNNotificationAction(
            identifier: takenAction, title: tr("Taken"),
            icon: UNNotificationActionIcon(systemImageName: "checkmark.circle.fill"))
        let snooze = UNNotificationAction(
            identifier: snoozeAction, title: tr("Remind in 10 min"),
            icon: UNNotificationActionIcon(systemImageName: "clock.arrow.circlepath"))
        let category = UNNotificationCategory(
            identifier: doseCategory, actions: [taken, snooze], intentIdentifiers: [])
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    static func requestAuthorization() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    /// Aktiv günün bütün gələcək dozaları üçün bildirişləri yenidən qurur.
    static func sync(context: ModelContext, now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        guard let session = DaySession.openSessions(in: context).first else {
            // Gün bitib: bildiriş mərkəzində qalan köhnə bildirişlərin düymələri də işləməsin.
            center.removeAllDeliveredNotifications()
            return
        }

        // Tətbiqdə vurulmuş qeyd edilən dozaların bildiriş mərkəzində qalan bildirişlərini təmizlə.
        let takenIDs = session.doses.filter { $0.takenAt != nil }.map(\.id.uuidString)
        center.removeDeliveredNotifications(withIdentifiers: takenIDs)

        let upcoming = session.sortedDoses.filter { $0.takenAt == nil && $0.scheduledAt > now }
        // iOS eyni anda maksimum 64 gözləyən bildiriş saxlayır.
        for (index, dose) in upcoming.prefix(60).enumerated() {
            guard let med = dose.medication else { continue }

            let content = UNMutableNotificationContent()
            content.title = "💧 \(med.name)"
            var body = tr("Time for 1 drop in each eye.")
            if index + 1 < upcoming.count {
                let next = upcoming[index + 1]
                let minutes = Int(next.scheduledAt.timeIntervalSince(dose.scheduledAt) / 60)
                if minutes <= 15, let nextMed = next.medication {
                    body += " " + tr("Next: \(nextMed.name) (in \(minutes) min).")
                }
            }
            content.body = body
            content.sound = .default
            content.categoryIdentifier = doseCategory
            content.userInfo = ["doseID": dose.id.uuidString]
            content.threadIdentifier = "doses"

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: dose.scheduledAt)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            center.add(UNNotificationRequest(identifier: dose.id.uuidString, content: content, trigger: trigger))
        }
    }
}

/// Tətbiq açıq olanda da bildirişləri göstərir və bildiriş düymələrini emal edir.
/// Completion handler versiyası istifadə olunur: `async` versiyada iOS cavabı əsas thread-dən
/// kənarda qaytarır və UIKit tətbiqi arxa planda dayandırır (SIGABRT).
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    // Vəziyyəti yoxdur.
    nonisolated(unsafe) static let shared = NotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// Bildirişdəki düymə basılanda (tətbiq bağlı olsa belə arxa planda işə düşür).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let raw = response.notification.request.content.userInfo["doseID"] as? String
        let actionID = response.actionIdentifier
        // Handler bir dəfə, əsas thread-də çağırılır.
        nonisolated(unsafe) let done = completionHandler
        DispatchQueue.main.async {
            if let raw, let doseID = UUID(uuidString: raw) {
                DayActions.handleNotificationAction(actionID, doseID: doseID, context: AppModel.container.mainContext)
            }
            done()
        }
    }
}
