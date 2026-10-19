import SwiftData
import SwiftUI

/// Ayarlar paneli. Yeni ayar əlavə etmək üçün `Form`-a yeni bir `Section` əlavə et.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// Aktiv gün yoxdursa `nil` — "Başlanğıc vaxtını düzəlt" bu halda söndürülür.
    let activeSession: DaySession?

    @State private var editingStart: DaySession?
    @AppStorage(AppSettings.liveActivityKey, store: LanguageModel.sharedDefaults) private var liveActivityEnabled = true
    private let language = LanguageModel.shared

    var body: some View {
        NavigationStack {
            Form {
                languageSection
                liveActivitySection
                daySection
                BackupSection()
                aboutSection
            }
            // Açılanda dərhal başlayır (tətbiq önplandadır), söndürəndə dərhal bağlanır.
            .onChange(of: liveActivityEnabled) { _, _ in
                LiveActivityManager.sync(context: context)
            }
            .navigationTitle(tr("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .bold()
                }
            }
            .sheet(item: $editingStart) { session in
                StartDaySheet(replacing: session)
            }
        }
    }

    // MARK: - Dil

    /// Seçim dəyişəndə bildirişlər, widget və Live Activity də yeni dildə yenidən qurulur.
    private var languageSelection: Binding<String> {
        Binding(
            get: { language.selection },
            set: { newValue in
                language.select(newValue)
                DayActions.refreshSurfaces(context: context)
            })
    }

    private var languageSection: some View {
        Section {
            Picker("Language", selection: languageSelection) {
                Text("System default").tag(LanguageModel.systemSelection)
                ForEach(AppLanguage.supported) { language in
                    Text(verbatim: language.nativeName).tag(language.code)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("Language")
        } footer: {
            Text("“System default” follows your iPhone language. If it isn't supported, English is used.")
        }
    }

    // MARK: - Live Activity

    private var liveActivitySection: some View {
        Section {
            Toggle("Show in Dynamic Island and on Lock Screen", isOn: $liveActivityEnabled)
        } header: {
            Text("Live Activity")
        } footer: {
            Text("Counts down to the next drop. Turning it off removes it right away. You can also manage Live Activities for Dərmanchı in the iPhone's Settings.")
        }
    }

    // MARK: - Bu gün

    private var daySection: some View {
        Section {
            Button {
                editingStart = activeSession
            } label: {
                Label("Edit start time", systemImage: "clock.arrow.circlepath")
            }
            .disabled(activeSession == nil)
        } header: {
            Text("Today")
        } footer: {
            if activeSession == nil {
                Text("Available once the day has started.")
            } else {
                Text("Move the time you took your first drop today. The rest of the day is rebuilt.")
            }
        }
    }

    // MARK: - Haqqında

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)
        } header: {
            Text("About")
        } footer: {
            Text("Dərmanchı is a personal tracker, not a medical device. Always follow your doctor's instructions.")
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
