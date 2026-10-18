import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \DaySession.startedAt, order: .reverse) private var sessions: [DaySession]

    var body: some View {
        NavigationStack {
            List {
                if sessions.isEmpty {
                    ContentUnavailableView("Hələ tarixçə yoxdur", systemImage: "calendar",
                                           description: Text("“Günə başla” basandan sonra günlər burada görünəcək."))
                }
                ForEach(sessions) { session in
                    NavigationLink {
                        SessionDetailView(session: session)
                    } label: {
                        SessionRow(session: session)
                    }
                }
            }
            .navigationTitle("Tarixçə")
        }
    }
}

struct SessionRow: View {
    let session: DaySession

    var body: some View {
        let now = Date.now
        let taken = session.doses.filter { $0.takenAt != nil }.count
        let missed = session.doses.filter { $0.status(at: now) == .missed }.count
        VStack(alignment: .leading, spacing: 4) {
            Text(session.startedAt.dayTitle.capitalized)
                .font(.body.weight(.medium))
            HStack(spacing: 12) {
                Text("\(session.startedAt.hm) – \(session.endedAt?.hm ?? "davam edir")")
                    .foregroundStyle(.secondary)
                Label("\(taken)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if missed > 0 {
                    Label("\(missed)", systemImage: "xmark.circle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
        }
    }
}

struct SessionDetailView: View {
    let session: DaySession

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            List {
                Section { ProgressStrip(doses: session.doses, now: session.startedAt) }
                Section {
                    ForEach(session.sortedDoses) { dose in
                        DoseRow(dose: dose, now: timeline.date)
                    }
                }
            }
        }
        .navigationTitle(session.startedAt.shortDay)
    }
}
