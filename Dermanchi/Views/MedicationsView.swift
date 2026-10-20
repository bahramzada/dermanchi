import SwiftUI

struct MedicationsView: View {
    @State private var editing: Medication?
    @State private var adding = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(Medication.all) { med in
                    Section {
                        Button { editing = med } label: {
                            MedicationDetail(medication: med, now: .now)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                Section {
                    Text("One drop in each eye every time. Wait at least 5 minutes between drops.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(tr("Medications"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("New medication")
                }
            }
            .sheet(item: $editing) { MedicationEditor(medication: $0) }
            .sheet(isPresented: $adding) { MedicationEditor(medication: nil) }
        }
    }
}

private struct MedicationDetail: View {
    let medication: Medication
    let now: Date

    var body: some View {
        let total = medication.totalDays
        let day = medication.dayNumber(on: now)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Circle().fill(medication.color).frame(width: 14, height: 14)
                Text(medication.name).font(.title3.bold())
                Spacer()
                if day > total {
                    Text("Done ✅").font(.subheadline)
                } else {
                    Text("Day \(max(day, 0))/\(total)")
                        .font(.subheadline.monospacedDigit())
                }
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            ProgressView(value: Double(min(max(day, 0), total)), total: Double(max(total, 1)))
                .tint(medication.color)
            Text(medication.scheduleDescription(on: now))
                .font(.subheadline)
            Text(verbatim: "\(medication.startDate.shortDay) – \(medication.lastDay().shortDay)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if medication.phases.count > 1 {
                let current = medication.phaseIndex(on: now)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(medication.phases.indices, id: \.self) { index in
                        let range = medication.range(ofPhase: index)
                        HStack {
                            Text(verbatim: "\(range.from.shortDay) – \(range.to.shortDay)")
                            Spacer()
                            if let drops = medication.phases[index].drops {
                                Text("\(drops) times a day")
                            } else {
                                Text("until bedtime")
                            }
                        }
                        .font(.caption.weight(index == current ? .bold : .regular))
                        .foregroundStyle(index == current ? medication.color : .secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
