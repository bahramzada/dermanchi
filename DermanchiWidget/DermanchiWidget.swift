import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

struct DoseProvider: TimelineProvider {
    /// Geri sayım dəqiqəbədəqiqə dəyişsin deyə bu qədər irəli hər dəqiqə üçün entry hazırlanır.
    private static let horizonMinutes = 180

    func placeholder(in context: Context) -> DoseEntry {
        DoseEntry(date: .now, state: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (DoseEntry) -> Void) {
        if context.isPreview {
            completion(DoseEntry(date: .now, state: .preview))
            return
        }
        Task { @MainActor in
            let session = Self.latestSession(in: ModelContext(AppModel.container))
            completion(DoseEntry(date: .now, state: WidgetState.make(session: session, at: .now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> Void) {
        Task { @MainActor in
            let start = Calendar.current.date(bySetting: .second, value: 0, of: .now) ?? .now
            // Hər yeniləmədə təzə kontekst: uzun yaşayan paylaşılan kontekst tətbiqin yazdıqlarını gec görə bilər.
            let modelContext = ModelContext(AppModel.container)
            let session = Self.latestSession(in: modelContext)
            let entries = (0..<Self.horizonMinutes).map { minute -> DoseEntry in
                let date = start.addingTimeInterval(TimeInterval(minute * 60))
                return DoseEntry(date: date, state: WidgetState.make(session: session, at: date))
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    @MainActor
    private static func latestSession(in context: ModelContext) -> DaySession? {
        var descriptor = FetchDescriptor<DaySession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}


// MARK: - Widget

struct DermanchiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DermanchiNextDose", provider: DoseProvider()) { entry in
            DermanchiWidgetView(entry: entry)
                .environment(\.locale, L10n.locale)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Next drop")
        .description("Next drop, time left and today's progress. Mark a drop as taken right from the widget.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct DermanchiWidgetBundle: WidgetBundle {
    var body: some Widget {
        DermanchiWidget()
        DoseLiveActivity()
    }
}

#Preview("A · Small", as: .systemSmall) {
    DermanchiWidget()
} timeline: {
    DoseEntry(date: .now, state: .preview)
}

#Preview("B · Medium", as: .systemMedium) {
    DermanchiWidget()
} timeline: {
    DoseEntry(date: .now, state: .preview)
}

#Preview("F · Lock Screen", as: .accessoryRectangular) {
    DermanchiWidget()
} timeline: {
    DoseEntry(date: .now, state: .preview)
}
