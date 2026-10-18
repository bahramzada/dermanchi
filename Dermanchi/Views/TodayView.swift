import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<DaySession> { $0.endedAt == nil }, sort: \DaySession.startedAt, order: .reverse)
    private var openSessions: [DaySession]

    @State private var choosingFirst = false
    @State private var confirmingSleep = false
    @State private var editingStart: DaySession?

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                if let session = openSessions.first {
                    activeDay(session, now: timeline.date)
                } else {
                    notStarted(now: timeline.date)
                }
            }
            .navigationTitle("Dərmanchı")
        }
    }

    // MARK: - Gün başlamayıb

    private func notStarted(now: Date) -> some View {
        let meds = Medication.active(on: now)
        return List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(now.dayTitle.capitalized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("İlk damcını vurduqdan sonra bas — günün qalan saatları avtomatik qurulacaq.")
                        .font(.callout)
                    Button {
                        choosingFirst = true
                    } label: {
                        Label("Günə başla", systemImage: "sunrise.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(meds.isEmpty)
                }
                .padding(.vertical, 6)
            }

            Section("Bu günün planı") {
                if meds.isEmpty {
                    Text("Bu gün heç bir damcı yoxdur 🎉")
                }
                ForEach(meds) { med in
                    MedicationSummaryRow(medication: med, date: now)
                }
            }
        }
        .sheet(isPresented: $choosingFirst) {
            StartDaySheet()
        }
    }

    // MARK: - Aktiv gün

    private func activeDay(_ session: DaySession, now: Date) -> some View {
        let doses = session.sortedDoses
        let next = doses.first { $0.takenAt == nil && $0.status(at: now) != .missed }
        let missed = doses.filter { $0.status(at: now) == .missed }

        return List {
            Section {
                if let next {
                    NextDoseCard(dose: next, now: now) {
                        DayActions.markTaken(next, context: context)
                    }
                } else {
                    Text("Gözləyən damcı yoxdur.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                ProgressStrip(doses: doses, now: now)
            }

            if !missed.isEmpty {
                Section {
                    ForEach(missed) { dose in
                        DoseRow(dose: dose, now: now)
                    }
                } header: {
                    Label("Buraxılan dozalar (\(missed.count))", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section("Günün cədvəli · \(session.startedAt.hm)-dən") {
                ForEach(doses) { dose in
                    DoseRow(dose: dose, now: now)
                }
            }

        }
        .sheet(item: $editingStart) { session in
            StartDaySheet(replacing: session)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Başlanğıc vaxtını düzəlt", systemImage: "clock.arrow.circlepath") {
                        editingStart = session
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    confirmingSleep = true
                } label: {
                    Label("Yatıram", systemImage: "moon.zzz.fill")
                        .labelStyle(.titleAndIcon)
                }
                .tint(.indigo)
            }
        }
        .alert("Günü bitirək?", isPresented: $confirmingSleep) {
            Button("Ləğv et", role: .cancel) {}
            Button("Yatıram", role: .destructive) {
                DayActions.endDay(session, context: context)
            }
        } message: {
            Text("Qalan bütün bildirişlər ləğv olunacaq. Sabah ilk damcını vuranda yenidən “Günə başla” bas.")
        }
    }
}

// MARK: - Komponentlər

struct NextDoseCard: View {
    let dose: Dose
    let now: Date
    let onTaken: () -> Void

    var body: some View {
        let med = dose.medication
        let isDue = dose.status(at: now) == .due
        VStack(alignment: .leading, spacing: 10) {
            Text(isDue ? "İNDİ VUR" : "NÖVBƏTİ DAMCI")
                .font(.caption.bold())
                .foregroundStyle(isDue ? .red : .secondary)
            HStack(alignment: .firstTextBaseline) {
                Circle().fill(med?.color ?? .gray).frame(width: 14, height: 14)
                Text(med?.name ?? dose.medicationID)
                    .font(.title.bold())
                Spacer()
                Text(dose.scheduledAt.hm)
                    .font(.title2.monospacedDigit())
            }
            Text(isDue
                 ? "\(durationText(now.timeIntervalSince(dose.scheduledAt))) gecikir"
                 : "\(durationText(dose.scheduledAt.timeIntervalSince(now))) sonra")
                .font(.subheadline)
                .foregroundStyle(isDue ? .red : .secondary)
            Button(action: onTaken) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.headline.weight(.heavy))
                    Text("Vurdum")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [(med?.color ?? .accentColor), (med?.color ?? .accentColor).opacity(0.8)],
                        startPoint: .top, endPoint: .bottom),
                    in: Capsule()
                )
                .shadow(color: (med?.color ?? .accentColor).opacity(0.35), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }
}

struct ProgressStrip: View {
    let doses: [Dose]
    let now: Date

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Medication.all.filter { id in doses.contains { $0.medicationID == id.id } }) { med in
                let mine = doses.filter { $0.medicationID == med.id }
                let taken = mine.filter { $0.takenAt != nil }.count
                let totalText: String = med.dailyDoses(on: now) == .untilSleep ? "" : "/\(mine.count)"
                VStack(spacing: 2) {
                    Text("\(taken)\(totalText)")
                        .font(.title3.bold().monospacedDigit())
                    Text(med.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(med.color.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }
}

struct DoseRow: View {
    @Environment(\.modelContext) private var context
    let dose: Dose
    let now: Date

    var body: some View {
        let status = dose.status(at: now)
        HStack(spacing: 12) {
            statusIcon(status)
            VStack(alignment: .leading, spacing: 2) {
                Text(dose.medication?.name ?? dose.medicationID)
                    .font(.body.weight(.medium))
                    .strikethrough(status == .missed, color: .red)
                Text(subtitle(status))
                    .font(.caption)
                    .foregroundStyle(status == .missed ? .red : .secondary)
            }
            Spacer()
            Text(dose.scheduledAt.hm)
                .font(.body.monospacedDigit())
                .foregroundStyle(status == .taken ? .secondary : .primary)
            if status != .taken {
                Button("Vurdum") { DayActions.markTaken(dose, context: context) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(dose.medication?.color ?? .accentColor)
            }
        }
        .swipeActions {
            if status == .taken {
                Button("Geri al") { DayActions.undo(dose, context: context) }
                    .tint(.gray)
            }
        }
    }

    private func subtitle(_ status: DoseStatus) -> String {
        switch status {
        case .taken: return "Vuruldu \(dose.takenAt?.hm ?? "")"
        case .missed: return "Buraxıldı"
        case .due: return "Gecikir"
        case .upcoming: return "Gözləyir"
        }
    }

    @ViewBuilder
    private func statusIcon(_ status: DoseStatus) -> some View {
        let color = dose.medication?.color ?? .gray
        switch status {
        case .taken: Image(systemName: "checkmark.circle.fill").foregroundStyle(color)
        case .missed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .due: Image(systemName: "bell.circle.fill").foregroundStyle(.orange)
        case .upcoming: Image(systemName: "circle").foregroundStyle(color)
        }
    }
}

struct MedicationSummaryRow: View {
    let medication: Medication
    let date: Date

    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(medication.color).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(medication.name).font(.body.weight(.medium))
                Text(medication.scheduleDescription(on: date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("Gün \(medication.dayNumber(on: date))/\(medication.totalDays())")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
