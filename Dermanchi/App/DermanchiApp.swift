import SwiftData
import SwiftUI
import UserNotifications
import WidgetKit

@main
struct DermanchiApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationManager.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(AppModel.container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab(tr("Today"), systemImage: "drop.fill") { TodayView() }
            Tab(tr("History"), systemImage: "calendar") { HistoryView() }
            Tab(tr("Medications"), systemImage: "cross.vial.fill") { MedicationsView() }
        }
        // Seçilmiş dil dəyişəndə `Text("...")` literalları da yenilənsin.
        .environment(\.locale, L10n.locale)
        .task {
            #if DEBUG
            DemoData.seedIfRequested(context: context)
            #endif
            await NotificationManager.requestAuthorization()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationManager.sync(context: context)
                WidgetCenter.shared.reloadAllTimelines()
                LiveActivityManager.sync(context: context)
            }
        }
    }
}
