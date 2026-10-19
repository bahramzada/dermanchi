import CoreTransferable
import Foundation
import SwiftData
import UniformTypeIdentifiers

/// The whole history as one JSON file, to move it to another iPhone.
enum DataBackup {
    static let version = 1

    struct File: Codable {
        var version: Int
        var exportedAt: Date
        var sessions: [SessionRecord]
        /// Missing in older files: the current medications are kept then.
        var medications: [Medication]?
    }

    struct SessionRecord: Codable {
        var startedAt: Date
        var endedAt: Date?
        var doses: [DoseRecord]
    }

    struct DoseRecord: Codable {
        var id: UUID
        var medicationID: String
        var priority: Int
        var plannedAt: Date
        var scheduledAt: Date
        var takenAt: Date?
        var snoozedUntil: Date?
    }

    struct UnsupportedVersion: Error {}

    @MainActor
    static func export(context: ModelContext, now: Date = .now) throws -> Data {
        let sessions = try context.fetch(FetchDescriptor<DaySession>(sortBy: [SortDescriptor(\.startedAt)]))
        let file = File(version: version, exportedAt: now, sessions: sessions.map { session in
            SessionRecord(startedAt: session.startedAt, endedAt: session.endedAt, doses: session.sortedDoses.map {
                DoseRecord(id: $0.id, medicationID: $0.medicationID, priority: $0.priority, plannedAt: $0.plannedAt,
                           scheduledAt: $0.scheduledAt, takenAt: $0.takenAt, snoozedUntil: $0.snoozedUntil)
            })
        }, medications: MedicationStore.current)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(file)
    }

    /// Replaces everything in the app with the file's contents and returns the number of days restored.
    /// A file that cannot be read throws before anything is deleted.
    @MainActor
    @discardableResult
    static func restore(_ data: Data, context: ModelContext) throws -> Int {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let file = try decoder.decode(File.self, from: data)
        guard file.version == version else { throw UnsupportedVersion() }

        if let medications = file.medications { MedicationStore.save(medications) }
        try context.delete(model: DaySession.self)
        for record in file.sessions {
            let session = DaySession(startedAt: record.startedAt)
            session.endedAt = record.endedAt
            context.insert(session)
            for item in record.doses {
                let dose = Dose(medicationID: item.medicationID, priority: item.priority, plannedAt: item.plannedAt)
                dose.id = item.id
                dose.scheduledAt = item.scheduledAt
                dose.takenAt = item.takenAt
                dose.snoozedUntil = item.snoozedUntil
                dose.session = session
                context.insert(dose)
            }
        }
        try context.save()
        DayActions.refreshSurfaces(context: context)
        return file.sessions.count
    }
}

/// What the share sheet sends: a `.json` file named after the export date.
struct BackupDocument: Transferable {
    let data: Data
    let fileName: String

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { document in
            let url = FileManager.default.temporaryDirectory.appending(path: document.fileName)
            try document.data.write(to: url)
            return SentTransferredFile(url)
        }
    }
}
