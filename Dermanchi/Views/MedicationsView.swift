import SwiftUI

struct MedicationsView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(Medication.all) { med in
                    Section {
                        MedicationDetail(medication: med, now: .now)
                    }
                }
                Section {
                    Text("One drop in each eye every time. Wait at least 5 minutes between drops.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(tr("Medications"))
        }
    }
}

private struct MedicationDetail: View {
    let medication: Medication
    let now: Date

    var body: some View {
        let total = medication.totalDays()
        let day = medication.dayNumber(on: now)
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: medication.endDate)!
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
            }
            ProgressView(value: Double(min(max(day, 0), total)), total: Double(total))
                .tint(medication.color)
            Text(medication.scheduleDescription(on: now))
                .font(.subheadline)
            Text(verbatim: "\(medication.startDate.shortDay) – \(lastDay.shortDay)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if case .taper(let start, let step) = medication.rule {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<start, id: \.self) { stage in
                        let from = Calendar.current.date(byAdding: .day, value: stage * step, to: medication.startDate)!
                        let to = Calendar.current.date(byAdding: .day, value: step - 1, to: from)!
                        let current = (day - 1) / step == stage
                        HStack {
                            Text(verbatim: "\(from.shortDay) – \(to.shortDay)")
                            Spacer()
                            Text("\(start - stage) times a day")
                        }
                        .font(.caption.weight(current ? .bold : .regular))
                        .foregroundStyle(current ? medication.color : .secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}
