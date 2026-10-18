import SwiftUI
import WidgetKit

// Widget görünüşləri tətbiqdə də kompilyasiya olunur ki, testlər onları
// README üçün PNG-yə render edə bilsin (WidgetSnapshotTests).

// MARK: - Timeline

struct DoseEntry: TimelineEntry {
    let date: Date
    let state: WidgetState
}


extension WidgetState {
    static var preview: WidgetState { preview(at: .now) }

    /// Widget qalereyası və README şəkilləri üçün nümunə vəziyyət.
    static func preview(at now: Date) -> WidgetState {
        WidgetState(
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

struct NextDoseBlock: View {
    let next: WidgetState.NextDose
    let now: Date
    var titleSize: CGFloat = 15
    var timeSize: CGFloat = 30

    var body: some View {
        let color = next.medication?.color ?? .accentColor
        VStack(alignment: .leading, spacing: 2) {
            Text(next.isDue ? tr("TAKE NOW") : tr("NEXT DROP"))
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
                 ? tr("\(durationText(now.timeIntervalSince(next.scheduledAt))) late")
                 : tr("in \(durationText(next.scheduledAt.timeIntervalSince(now)))"))
                .font(.system(size: 11))
                .foregroundStyle(next.isDue ? .red : .secondary)
        }
    }
}

struct TakenButton: View {
    let next: WidgetState.NextDose

    var body: some View {
        Button(intent: MarkDoseTakenIntent(doseID: next.id)) {
            Label(tr("Taken"), systemImage: "checkmark")
                .font(.system(size: 13, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .foregroundStyle(.white)
                .background(next.medication?.color ?? .accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct EmptyStateView: View {
    let phase: WidgetState.Phase

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: phase == .finished ? "moon.zzz.fill" : "sunrise.fill")
                .font(.system(size: 22))
                .foregroundStyle(phase == .finished ? .indigo : .orange)
            Spacer(minLength: 0)
            Text(phase == .finished ? tr("Day finished") : tr("Day not started"))
                .font(.system(size: 15, weight: .semibold))
            Text(phase == .finished ? tr("Good night 🌙") : tr("Take your first drop, then tap “Start the day” in the app"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - A · Kiçik

struct SmallView: View {
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

struct MediumView: View {
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

struct ProgressRow: View {
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

struct LockRectangularView: View {
    let entry: DoseEntry

    var body: some View {
        if let next = entry.state.next {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "drop.fill")
                    Text(verbatim: "\(next.medication?.name ?? next.medicationID) · \(next.scheduledAt.hm)")
                        .lineLimit(1)
                }
                .font(.headline)
                .widgetAccentable()
                Text(next.isDue
                     ? tr("Take now · \(durationText(entry.date.timeIntervalSince(next.scheduledAt))) late")
                     : tr("in \(durationText(next.scheduledAt.timeIntervalSince(entry.date)))"))
                    .font(.subheadline)
                if let after = entry.state.after {
                    Text(tr("Next: \(after.medication?.name ?? after.medicationID) \(after.scheduledAt.hm)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 1) {
                Label(entry.state.phase == .finished ? tr("Day finished") : tr("Day not started"),
                      systemImage: entry.state.phase == .finished ? "moon.zzz.fill" : "drop")
                    .font(.headline)
                    .widgetAccentable()
                Text(entry.state.phase == .finished ? tr("Good night") : tr("Tap “Start the day” in the app"))
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
