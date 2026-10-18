import SwiftData
import SwiftUI
import UserNotifications

@main
struct DermanchiApp: App {
    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationManager.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.locale, Locale(identifier: "az_AZ"))
        }
        .modelContainer(AppModel.container)
    }
}

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Bu gün", systemImage: "drop.fill") { TodayView() }
            Tab("Tarixçə", systemImage: "calendar") { HistoryView() }
            Tab("Dərmanlar", systemImage: "cross.vial.fill") { MedicationsView() }
        }
        .task {
            #if DEBUG
            DemoData.seedIfRequested(context: context)
            #endif
            await NotificationManager.requestAuthorization()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { NotificationManager.sync(context: context) }
        }
    }
}
