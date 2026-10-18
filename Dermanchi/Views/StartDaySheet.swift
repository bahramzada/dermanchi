import SwiftData
import SwiftUI

/// "Günə başla": ilk damcının vaxtı və hansı damcı olduğu.
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
                    DatePicker("İlk damcı vaxtı", selection: $start,
                               in: Calendar.current.startOfDay(for: now)...now,
                               displayedComponents: .hourAndMinute)
                    Button("İndi") { start = .now }
                } footer: {
                    Text("Günün qalan saatları bu vaxtdan hesablanacaq.")
                }

                Section("İlk hansı damcını vurdun?") {
                    Picker("İlk damcı", selection: $firstID) {
                        ForEach(meds) { med in
                            Text(med.name).tag(med.id)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if isPast {
                    Section {
                        Toggle("Keçmiş damcıları vurulmuş say", isOn: $markPast)
                    } footer: {
                        Text(markPast
                             ? "\(start.hm)-dan indiyə qədərki \(pastCount) doza öz vaxtında vurulmuş kimi qeyd olunacaq."
                             : "Keçmiş dozaları özün bir-bir qeyd edəcəksən.")
                    }
                }
            }
            .navigationTitle(replacing == nil ? "Günə başla" : "Başlanğıcı düzəlt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Ləğv et") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Başla") {
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
