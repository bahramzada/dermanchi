import SwiftData
import SwiftUI

/// Günü başladan pəncərə: ilk damcının vaxtı və hansı damcı olduğu.
/// `replacing` verilərsə, mövcud günün başlanğıcı düzəldilir.
struct StartDaySheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var replacing: DaySession?

    @State private var start = Date.now
    @State private var firstID = Medication.active(on: .now).first?.id ?? ""
    @State private var markPast = true

    var body: some View {
        let now = Date.now
        let meds = Medication.active(on: start)
        let isPast = now.timeIntervalSince(start) > 10 * 60
        let pastCount = isPast ? pastDoseCount(now: now) : 0

        NavigationStack {
            Form {
                Section {
                    DatePicker("First drop time", selection: $start,
                               in: Calendar.current.startOfDay(for: now)...now,
                               displayedComponents: .hourAndMinute)
                    Button("Now") { start = .now }
                } footer: {
                    Text("The rest of the day will be scheduled from this time.")
                }

                Section("Which drop did you take first?") {
                    Picker("First drop", selection: $firstID) {
                        ForEach(meds) { med in
                            Text(med.name).tag(med.id)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if isPast {
                    Section {
                        Toggle("Count past drops as taken", isOn: $markPast)
                    } footer: {
                        Text(markPast
                             ? tr("From \(start.hm) until now, \(pastCount) drops will be logged as taken at their scheduled times.")
                             : tr("You'll log past drops yourself, one by one."))
                    }
                }
            }
            .navigationTitle(replacing == nil ? tr("Start the day") : tr("Edit start time"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        DayActions.startDay(
                            firstMedicationID: firstID,
                            start: start,
                            markPastAsTaken: isPast && markPast,
                            replacing: replacing,
                            context: context)
                        dismiss()
                    }
                    .bold()
                    .disabled(meds.isEmpty)
                }
            }
        }
        .onAppear {
            if let replacing {
                start = replacing.startedAt
                if let first = replacing.doses.min(by: { ($0.plannedAt, $0.priority) < ($1.plannedAt, $1.priority) }) {
                    firstID = first.medicationID
                }
            }
        }
    }

    private func pastDoseCount(now: Date) -> Int {
        let planned = DoseScheduler.plan(start: start, firstMedicationID: firstID)
        let times = DoseScheduler.stagger(planned.map(\.plannedAt), after: nil)
        return times.filter { $0 <= now }.count
    }
}
