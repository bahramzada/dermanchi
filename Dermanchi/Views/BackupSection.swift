import SwiftData
import SwiftUI

/// Settings section to move the history to another iPhone (see `DataBackup`).
struct BackupSection: View {
    @Environment(\.modelContext) private var context

    @State private var confirmingImport = false
    @State private var choosingFile = false
    @State private var message: String?

    var body: some View {
        Section {
            if let backup {
                ShareLink(item: backup, preview: SharePreview(backup.fileName)) {
                    Label("Export data", systemImage: "square.and.arrow.up")
                }
            }
            Button {
                confirmingImport = true
            } label: {
                Label("Import data", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Save every day and drop to a file, or restore them from one. Use this to move to a new iPhone.")
        }
        .alert("Replace all data?", isPresented: $confirmingImport) {
            Button("Cancel", role: .cancel) {}
            Button("Choose file", role: .destructive) { choosingFile = true }
        } message: {
            Text("Everything in the app is replaced by the contents of the file you choose.")
        }
        .fileImporter(isPresented: $choosingFile, allowedContentTypes: [.json]) { result in
            restore(result)
        }
        .alert("Import data", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("Done", role: .cancel) {}
        } message: {
            Text(verbatim: message ?? "")
        }
    }

    private var backup: BackupDocument? {
        guard let data = try? DataBackup.export(context: context) else { return nil }
        let day = Date.now.formatted(.iso8601.year().month().day())
        return BackupDocument(data: data, fileName: "Dermanchi-\(day).json")
    }

    private func restore(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let days = try DataBackup.restore(try Data(contentsOf: url), context: context)
            message = tr("Days restored: \(days)")
        } catch let error as CocoaError where error.code == .userCancelled {
            return
        } catch {
            message = tr("Could not read this file.")
        }
    }
}
