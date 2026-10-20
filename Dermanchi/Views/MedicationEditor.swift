import SwiftData
import SwiftUI

/// Adds a medication or edits an existing one: name, colour, interval, first day and the course as phases.
/// Example: "5 more days at 5 drops" means making the current phase 5 days longer.
struct MedicationEditor: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private let isNew: Bool
    @State private var draft: Medication
    @State private var confirmingDelete = false

    /// `nil` — yeni dərman.
    init(medication: Medication?) {
        isNew = medication == nil
        let unused = MedicationColor.allCases.first { color in !Medication.all.contains { $0.palette == color } }
        _draft = State(initialValue: medication ?? Medication(
            id: UUID().uuidString, name: "", palette: unused ?? .blue, intervalHours: 3,
            startDate: Calendar.current.startOfDay(for: .now), phases: [.init(days: 7, drops: 4)]))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $draft.name)
                        .textInputAutocapitalization(.words)
                }
                Section("Color") { colorPicker }
                Section("Schedule") {
                    Stepper(value: $draft.intervalHours, in: 1...12) {
                        Text("Every \(draft.intervalHours) hours")
                    }
                    DatePicker("First day", selection: $draft.startDate, displayedComponents: .date)
                }
                coursSection
                if !isNew {
                    Section {
                        Button("Delete medication", role: .destructive) { confirmingDelete = true }
                    }
                }
            }
            .navigationTitle(isNew ? tr("New medication") : tr("Edit medication"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .bold()
                        .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete this medication?", isPresented: $confirmingDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: delete)
            } message: {
                Text("It is removed from today's plan. Past days keep their history.")
            }
        }
    }

    private var colorPicker: some View {
        HStack(spacing: 12) {
            ForEach(MedicationColor.allCases, id: \.self) { option in
                Circle()
                    .fill(option.color)
                    .frame(width: 28, height: 28)
                    .overlay {
                        if option == draft.palette {
                            Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                        }
                    }
                    .onTapGesture { draft.palette = option }
            }
        }
        .padding(.vertical, 4)
    }

    private var coursSection: some View {
        Section {
            ForEach(draft.phases.indices, id: \.self) { index in
                PhaseRow(phase: binding(for: index), range: rangeText(index))
            }
            .onDelete { draft.phases.remove(atOffsets: $0) }
            .deleteDisabled(draft.phases.count == 1)
            Button {
                draft.phases.append(.init(days: 5, drops: draft.phases.last?.drops ?? 3))
            } label: {
                Label("Add phase", systemImage: "plus.circle")
                    .labelStyle(.titleAndIcon)
            }
        } header: {
            Text("Course")
        } footer: {
            Text("Last day: \(draft.lastDay().shortDay)")
        }
    }

    /// Qatı silinəndə SwiftUI köhnə indekslə bir daha oxuya bilər, ona görə sərhəd yoxlanılır.
    private func binding(for index: Int) -> Binding<Medication.Phase> {
        Binding(
            get: { index < draft.phases.count ? draft.phases[index] : .init(days: 1, drops: 1) },
            set: { if index < draft.phases.count { draft.phases[index] = $0 } })
    }

    private func rangeText(_ index: Int) -> String {
        guard index < draft.phases.count else { return "" }
        let range = draft.range(ofPhase: index)
        return "\(range.from.shortDay) – \(range.to.shortDay)"
    }

    private func save() {
        draft.name = draft.name.trimmingCharacters(in: .whitespaces)
        draft.startDate = Calendar.current.startOfDay(for: draft.startDate)
        var medications = MedicationStore.current
        if let index = medications.firstIndex(where: { $0.id == draft.id }) {
            medications[index] = draft
        } else {
            medications.append(draft)
        }
        commit(medications)
    }

    /// Silinən dərman arxivlənir: bu gündən çıxır, keçmiş günlərin adı və rəngi qalır.
    private func delete() {
        var medications = MedicationStore.current
        guard let index = medications.firstIndex(where: { $0.id == draft.id }) else { return }
        medications[index].isArchived = true
        commit(medications)
    }

    private func commit(_ medications: [Medication]) {
        MedicationStore.save(medications)
        DayActions.applyMedicationChanges(context: context)
        dismiss()
    }
}

private struct PhaseRow: View {
    @Binding var phase: Medication.Phase
    let range: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: range)
                .font(.caption)
                .foregroundStyle(.secondary)
            Stepper(value: $phase.days, in: 1...365) {
                Text("\(phase.days) days")
            }
            Picker("Per day", selection: $phase.drops) {
                Text("Until bedtime").tag(Int?.none)
                ForEach(1...12, id: \.self) { count in
                    Text("\(count) times a day").tag(Int?.some(count))
                }
            }
        }
        .padding(.vertical, 2)
    }
}
