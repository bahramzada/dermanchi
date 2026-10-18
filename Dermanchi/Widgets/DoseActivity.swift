import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Model

/// Dynamic Island və kilid ekranındakı "Növbəti damcı" Live Activity-si.
struct DoseActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var doseID: String
        var medicationID: String
        var scheduledAt: Date
        /// Geri sayım zolağının başlanğıcı — son vurulan damcı.
        var intervalStart: Date
        var afterMedicationID: String?
        var afterScheduledAt: Date?

        var medication: Medication? { Medication.with(id: medicationID) }
        var afterMedication: Medication? { afterMedicationID.flatMap(Medication.with(id:)) }
        var color: Color { medication?.color ?? .accentColor }
        var name: String { medication?.name ?? medicationID }
        var progressRange: ClosedRange<Date> { intervalStart...scheduledAt }

        /// Aktiv gündən növbəti damcı. Gün bitibsə və ya damcı qalmayıbsa `nil`.
        @MainActor
        static func make(session: DaySession?, at now: Date) -> ContentState? {
            guard let session, session.endedAt == nil else { return nil }
            let upcoming = session.sortedDoses.filter { $0.takenAt == nil && $0.status(at: now) != .missed }
            guard let next = upcoming.first else { return nil }
            let after = upcoming.dropFirst().first
            let start = session.lastTakenAt ?? session.startedAt
            return ContentState(
                doseID: next.id.uuidString,
                medicationID: next.medicationID,
                scheduledAt: next.scheduledAt,
                // Zolağın uzunluğu ən azı 1 dəqiqə olsun.
                intervalStart: min(start, next.scheduledAt.addingTimeInterval(-60)),
                afterMedicationID: after?.medicationID,
                afterScheduledAt: after?.scheduledAt)
        }
    }

    /// iOS bir activity-ni ~8 saat saxlayır; tətbiq bundan əvvəl yenisini başladır.
    var startedAt: Date
}

// MARK: - Görünüşlər (tətbiqdə də kompilyasiya olunur ki, README şəkilləri render oluna bilsin)

/// Live Activity-dəki "Vurdum" düyməsi.
struct ActivityTakenButton: View {
    let state: DoseActivityAttributes.ContentState
    var compact = false

    var body: some View {
        Button(intent: MarkDoseTakenIntent(doseID: UUID(uuidString: state.doseID) ?? UUID())) {
            Label("Vurdum", systemImage: "checkmark")
                .font(.system(size: compact ? 13 : 15, weight: .semibold))
                .frame(maxWidth: compact ? nil : .infinity)
                .padding(.vertical, compact ? 8 : 9)
                .padding(.horizontal, compact ? 14 : 0)
                .foregroundStyle(.white)
                .background(state.color, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// Saniyəbəsaniyə geri sayım. Vaxt keçəndə iOS özü irəli saymağa başlayır (gecikmə).
struct ActivityTimerText: View {
    let state: DoseActivityAttributes.ContentState
    let isStale: Bool
    var size: CGFloat

    var body: some View {
        Text(state.scheduledAt, style: .timer)
            .font(.system(size: size, weight: .semibold).monospacedDigit())
            .foregroundStyle(isStale ? .red : state.color)
            .contentTransition(.numericText(countsDown: true))
    }
}

struct ActivityProgressBar: View {
    let state: DoseActivityAttributes.ContentState

    var body: some View {
        ProgressView(timerInterval: state.progressRange, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .tint(state.color)
    }
}

struct ActivityAfterText: View {
    let state: DoseActivityAttributes.ContentState

    var body: some View {
        if let after = state.afterMedication, let time = state.afterScheduledAt {
            Text("Sonra: \(after.name) \(time.hm)")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }
}

/// Kilid ekranı paneli.
struct DoseActivityLockView: View {
    let state: DoseActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 5) {
                        Image(systemName: "drop.fill").foregroundStyle(state.color)
                        Text("\(state.name) · \(state.scheduledAt.hm)")
                        if isStale {
                            Text("İNDİ VUR")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.red)
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    ActivityTimerText(state: state, isStale: isStale, size: 34)
                }
                Spacer(minLength: 0)
                ActivityTakenButton(state: state, compact: true)
            }
            ActivityProgressBar(state: state)
            ActivityAfterText(state: state)
        }
        .padding(16)
    }
}

/// Dynamic Island genişlənmiş görünüşünün alt hissəsi.
struct DoseActivityExpandedBottom: View {
    let state: DoseActivityAttributes.ContentState
    let isStale: Bool

    /// Adanın hündürlüyü məhduddur, ona görə düymə geri sayımın yanındadır.
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 0) {
                ActivityTimerText(state: state, isStale: isStale, size: 34)
                ActivityAfterText(state: state)
            }
            Spacer(minLength: 0)
            ActivityTakenButton(state: state, compact: true)
        }
    }
}
