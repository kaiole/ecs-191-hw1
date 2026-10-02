import InstalogCore
import SwiftUI

/// Jump to any section. Shows what was logged where; nothing is ever marked done.
struct SectionsSheet: View {
    let model: DiaryModel
    let close: () -> Void
    let editRoutine: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                SheetHeader(title: "Sections", close: close)
                Text("Jump anywhere. Sections stay open all day, and nothing gets checked off.")
                    .font(Typeface.sans(13, relativeTo: .footnote))
                    .foregroundStyle(Palette.secondary)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                ForEach(Array(model.destinations.enumerated()), id: \.element.id) { index, destination in
                    row(index: index, destination: destination)
                }
                Button(action: editRoutine) {
                    HStack {
                        Text("Edit sections & meals")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Palette.tertiary)
                    }
                    .font(Typeface.sans(15, .medium))
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Palette.outline))
                }
                .buttonStyle(.plain)
                .padding(.top, 12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .foregroundStyle(Palette.text)
    }

    private func row(index: Int, destination: Destination) -> some View {
        let entries = model.entries(in: destination)
        let energy = NutritionCalculator.summarize(entries: entries)[.energy].known
        let isCurrent = destination.id == model.currentDestination.id
        var detail = entries.isEmpty ? "Nothing logged" : "\(entries.count) logged · \(NumberFormatting.energy(energy)) kcal"
        if let section = destination.section, section.mode == .all { detail += " · shows all meals" }

        return Button {
            model.selectDestination(id: destination.id)
            close()
        } label: {
            HStack(spacing: 14) {
                Text(String(format: "%02d", index + 1))
                    .font(Typeface.mono(13))
                    .foregroundStyle(Palette.tertiary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(destination.isUnsectioned ? "Unsectioned" : destination.name)
                        .font(Typeface.sans(17, .semibold, relativeTo: .headline))
                    Text(detail).font(Typeface.sans(13, relativeTo: .footnote)).foregroundStyle(Palette.secondary)
                }
                Spacer(minLength: 0)
                if isCurrent {
                    Text("Here now")
                        .font(Typeface.sans(12, .semibold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Palette.accentBorder))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 64)
            .background(isCurrent ? Color(hex: 0x20262B) : .clear, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(destination.isUnsectioned ? "Unsectioned" : destination.name). \(detail)")
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
    }
}

struct DayPickerSheet: View {
    let model: DiaryModel
    let close: () -> Void
    @State private var date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SheetHeader(title: "Choose a day", subtitle: "Inspect or correct past logs.", close: close)
            DatePicker("Day", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(Palette.accent)
            HStack(spacing: 10) {
                Button("Today") {
                    Task {
                        await model.changeDate(to: model.today)
                        close()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
                Button("Show day") {
                    Task {
                        await model.changeDate(to: LogDate(date, calendar: model.calendar))
                        close()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .padding(.top, 8)
        .foregroundStyle(Palette.text)
        .onAppear { date = model.viewedDate.startOfDay(in: model.calendar) }
    }
}
