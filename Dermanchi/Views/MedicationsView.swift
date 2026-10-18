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
                    Text("Hər vurmada hər iki gözə 1 damcı. Damcılar arası ən azı 5 dəqiqə gözlə.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Dərmanlar")
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
                    Text("Bitdi ✅").font(.subheadline)
                } else {
                    Text("Gün \(max(day, 0))/\(total)")
                        .font(.subheadline.monospacedDigit())
                }
            }
            ProgressView(value: Double(min(max(day, 0), total)), total: Double(total))
                .tint(medication.color)
            Text(medication.scheduleDescription(on: now))
                .font(.subheadline)
            Text("\(medication.startDate.shortDay) – \(lastDay.shortDay)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if case .taper(let start, let step) = medication.rule {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<start, id: \.self) { stage in
                        let from = Calendar.current.date(byAdding: .day, value: stage * step, to: medication.startDate)!
                        let to = Calendar.current.date(byAdding: .day, value: step - 1, to: from)!
                        let current = (day - 1) / step == stage
                        HStack {
                            Text("\(from.shortDay) – \(to.shortDay)")
                            Spacer()
                            Text("gündə \(start - stage) dəfə")
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
