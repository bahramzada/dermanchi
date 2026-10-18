import AppIntents
import SwiftData
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct DoseEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
}

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
            completion(DoseEntry(date: .now, state: Self.state(at: .now)))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoseEntry>) -> Void) {
        Task { @MainActor in
            let start = Calendar.current.date(bySetting: .second, value: 0, of: .now) ?? .now
            let session = Self.latestSession()
            let entries = (0..<Self.horizonMinutes).map { minute -> DoseEntry in
                let date = start.addingTimeInterval(TimeInterval(minute * 60))
                return DoseEntry(date: date, state: WidgetState.make(session: session, at: date))
            }
            completion(Timeline(entries: entries, policy: .atEnd))
        }
    }

    @MainActor
    private static func state(at date: Date) -> WidgetState {
        WidgetState.make(session: latestSession(), at: date)
    }

    @MainActor
    private static func latestSession() -> DaySession? {
        guard AppModel.isStoreReady else { return nil }
        var descriptor = FetchDescriptor<DaySession>(sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? AppModel.container.mainContext.fetch(descriptor).first
    }
}

extension WidgetState {
    static var preview: WidgetState {
        let now = Date.now
        return WidgetState(
            phase: .active,
            next: NextDose(id: UUID(), medicationID: "xiloial", scheduledAt: now.addingTimeInterval(52 * 60), isDue: false),
            after: NextDose(id: UUID(), medicationID: "moxi-r", scheduledAt: now.addingTimeInterval(112 * 60), isDue: false),
            progress: [
                Progress(medicationID: "xiloial", taken: 4, total: nil, missed: 0),
                Progress(medicationID: "moxi-r", taken: 3, total: 5, missed: 0),
                Progress(medicationID: "maxidex", taken: 2, total: 5, missed: 1),
            ],
            missedCount: 1)
    }
}

// MARK: - Komponentlər

private struct NextDoseBlock: View {
    let next: WidgetState.NextDose
    let now: Date
    var titleSize: CGFloat = 15
    var timeSize: CGFloat = 30

    var body: some View {
        let color = next.medication?.color ?? .accentColor
        VStack(alignment: .leading, spacing: 2) {
            Text(next.isDue ? "İNDİ VUR" : "NÖVBƏTİ DAMCI")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(next.isDue ? .red : .secondary)
            HStack(spacing: 5) {
                Circle().fill(color).frame(width: 9, height: 9)
                Text(next.medication?.name ?? next.medicationID)
                    .font(.system(size: titleSize, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.top, 4)
            Text(next.scheduledAt.hm)
                .font(.system(size: timeSize, weight: .semibold).monospacedDigit())
                .minimumScaleFactor(0.7)
            Text(next.isDue
                 ? "\(durationText(now.timeIntervalSince(next.scheduledAt))) gecikir"
                 : "\(durationText(next.scheduledAt.timeIntervalSince(now))) sonra")
                .font(.system(size: 11))
                .foregroundStyle(next.isDue ? .red : .secondary)
        }
    }
}

private struct TakenButton: View {
    let next: WidgetState.NextDose

    var body: some View {
        Button(intent: MarkDoseTakenIntent(doseID: next.id)) {
            Label("Vurdum", systemImage: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .foregroundStyle(.white)
                .background(next.medication?.color ?? .accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct EmptyStateView: View {
    let phase: WidgetState.Phase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: phase == .finished ? "moon.zzz.fill" : "sunrise.fill")
                .font(.system(size: 22))
                .foregroundStyle(phase == .finished ? .indigo : .orange)
            Spacer(minLength: 0)
            Text(phase == .finished ? "Gün bitdi" : "Gün başlamayıb")
                .font(.system(size: 15, weight: .semibold))
            Text(phase == .finished ? "Yaxşı yuxular 🌙" : "İlk damcını vurub tətbiqdə “Günə başla” bas")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - A · Kiçik

private struct SmallView: View {
    let entry: DoseEntry

    var body: some View {
        if let next = entry.state.next {
            VStack(alignment: .leading, spacing: 0) {
                NextDoseBlock(next: next, now: entry.date)
                Spacer(minLength: 6)
                TakenButton(next: next)
            }
        } else {
            EmptyStateView(phase: entry.state.phase)
        }
    }
}

// MARK: - B · Orta

private struct MediumView: View {
    let entry: DoseEntry

    var body: some View {
        if let next = entry.state.next {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    NextDoseBlock(next: next, now: entry.date, timeSize: 28)
                    Spacer(minLength: 6)
                    TakenButton(next: next)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 9) {
                    ForEach(entry.state.progress) { item in
                        ProgressRow(item: item)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        } else {
            HStack(spacing: 16) {
                EmptyStateView(phase: entry.state.phase)
                if !entry.state.progress.isEmpty {
                    VStack(alignment: .leading, spacing: 9) {
                        ForEach(entry.state.progress) { ProgressRow(item: $0) }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

private struct ProgressRow: View {
    let item: WidgetState.Progress

    var body: some View {
        let color = item.medication?.color ?? .gray
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(item.medication?.name ?? item.medicationID)
                    .font(.system(size: 12, weight: .medium))
                if item.missed > 0 {
                    Circle().fill(.red).frame(width: 6, height: 6)
                }
                Spacer(minLength: 0)
                Text(item.total.map { "\(item.taken)/\($0)" } ?? "\(item.taken)")
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(color.opacity(0.18))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }

    /// "Yatana qədər" dərmanlar üçün gündə ~8 doza götürülür.
    private var fraction: CGFloat {
        let total = Double(item.total ?? 8)
        return CGFloat(min(1, Double(item.taken) / max(total, 1)))
    }
}

// MARK: - F · Kilid ekranı (düzbucaqlı)

private struct LockRectangularView: View {
    let entry: DoseEntry

    var body: some View {
        if let next = entry.state.next {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                    Text("\(next.medication?.name ?? next.medicationID) · \(next.scheduledAt.hm)")
                        .lineLimit(1)
                }
                .font(.headline)
                .widgetAccentable()
                Text(next.isDue
                     ? "İndi vur · \(durationText(entry.date.timeIntervalSince(next.scheduledAt))) gecikir"
                     : "\(durationText(next.scheduledAt.timeIntervalSince(entry.date))) sonra")
                    .font(.subheadline)
                if let after = entry.state.after {
                    Text("Sonra: \(after.medication?.name ?? after.medicationID) \(after.scheduledAt.hm)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Label(entry.state.phase == .finished ? "Gün bitdi" : "Gün başlamayıb",
                      systemImage: entry.state.phase == .finished ? "moon.zzz.fill" : "drop")
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.state.phase == .finished ? "Yaxşı yuxular" : "Tətbiqdə “Günə başla” bas")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Widget

struct DermanchiWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DoseEntry

    var body: some View {
        switch family {
        case .accessoryRectangular:
            LockRectangularView(entry: entry)
        case .systemMedium:
            MediumView(entry: entry)
        default:
            SmallView(entry: entry)
        }
    }
}

struct DermanchiWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "DermanchiNextDose", provider: DoseProvider()) { entry in
            DermanchiWidgetView(entry: entry)
                .environment(\.locale, Locale(identifier: "az_AZ"))
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName("Növbəti damcı")
        .description("Növbəti damcı, qalan vaxt və günün gedişatı. Damcını birbaşa buradan qeyd et.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct DermanchiWidgetBundle: WidgetBundle {
    var body: some Widget {
        DermanchiWidget()
    }
}

#Preview("A · Kiçik", as: .systemSmall) {
    DermanchiWidget()
} timeline: {
    DoseEntry(date: .now, state: .preview)
}

#Preview("B · Orta", as: .systemMedium) {
    DermanchiWidget()
} timeline: {
    DoseEntry(date: .now, state: .preview)
}

#Preview("F · Kilid ekranı", as: .accessoryRectangular) {
    DermanchiWidget()
} timeline: {
    DoseEntry(date: .now, state: .preview)
}
