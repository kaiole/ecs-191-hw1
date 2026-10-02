import InstalogCore
import SwiftUI

/// Entries logged in the current section, collapsed to one line until expanded.
struct LoggedEntriesGroup: View {
    let model: DiaryModel
    let entries: [LoggedEntry]
    let emptyText: String
    @Binding var isExpanded: Bool
    @Binding var revealedEntryID: UUID?
    let open: (LoggedEntry) -> Void

    var body: some View {
        if entries.isEmpty {
            Text(emptyText)
                .font(Typeface.sans(13, relativeTo: .footnote))
                .foregroundStyle(Palette.tertiary)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Palette.outline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        } else {
            VStack(spacing: 0) {
                summaryButton
                if isExpanded {
                    Divider().overlay(Palette.divider)
                    ForEach(entries) { entry in
                        LoggedEntryRow(
                            model: model, entry: entry, isRevealed: revealedEntryID == entry.id,
                            reveal: { revealedEntryID = $0 ? entry.id : nil },
                            open: {
                                if revealedEntryID != nil {
                                    revealedEntryID = nil
                                } else {
                                    open(entry)
                                }
                            })
                    }
                }
            }
            .background(Palette.raised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var summaryButton: some View {
        let energy = NutritionCalculator.summarize(entries: entries)[.energy]
        return Button {
            withAnimation(.snappy) {
                isExpanded.toggle()
                revealedEntryID = nil
            }
        } label: {
            HStack(spacing: 12) {
                Text("\(entries.count)")
                    .font(Typeface.mono(13, .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 28, height: 28)
                    .background(Color(hex: 0x262C31), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 0) {
                        Text("Logged here · ")
                        Text(NumberFormatting.energy(energy.known)).font(Typeface.mono(14, .semibold))
                        Text(" kcal")
                    }
                    .font(Typeface.sans(14, .semibold, relativeTo: .subheadline))
                    Text(entries.map(\.name).joined(separator: ", "))
                        .font(Typeface.sans(13, relativeTo: .footnote))
                        .foregroundStyle(Palette.tertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.secondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(entries.count) logged here, \(NumberFormatting.energy(energy.known)) calories")
        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
        .accessibilityHint(isExpanded ? "Hides entries" : "Shows entries")
    }
}

/// One logged entry. Swiping right only reveals Delete; deleting takes a tap.
struct LoggedEntryRow: View {
    let model: DiaryModel
    let entry: LoggedEntry
    let isRevealed: Bool
    let reveal: (Bool) -> Void
    let open: () -> Void

    @GestureState private var dragOffset: CGFloat = 0
    private let actionWidth: CGFloat = 88

    var body: some View {
        let energy = NutritionCalculator.summarize(entry)[.energy]
        let offset = max(0, min(actionWidth + 28, (isRevealed ? actionWidth : 0) + dragOffset))

        ZStack(alignment: .leading) {
            if offset > 0 {
                Button(role: .destructive) {
                    Task { await model.deleteEntry(entry) }
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "trash")
                        Text("Delete").font(Typeface.sans(12, .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background(Palette.danger)
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
            Button(action: open) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(entry.name).font(Typeface.sans(15, .medium, relativeTo: .body))
                        Text(subtitle)
                            .font(Typeface.sans(12, relativeTo: .caption))
                            .foregroundStyle(Palette.tertiary)
                    }
                    Spacer(minLength: 0)
                    Text(NumberFormatting.energy(energy.known))
                        .font(Typeface.mono(14))
                        .foregroundStyle(Palette.secondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.tertiary)
                }
                .padding(.leading, 54)
                .padding(.trailing, 14)
                .padding(.vertical, 8)
                .frame(minHeight: 54)
                .background(Palette.raised)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .offset(x: offset)
            .animation(.easeOut(duration: 0.2), value: isRevealed)
        }
        .clipped()
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.border).frame(height: 1) }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12)
                .updating($dragOffset) { value, state, _ in
                    if abs(value.translation.width) > abs(value.translation.height) {
                        state = value.translation.width
                    }
                }
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let final = (isRevealed ? actionWidth : 0) + value.translation.width
                    reveal(final > actionWidth / 2)
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.name), logged \(Format.time(entry.recordedAt)), \(NumberFormatting.energy(energy.known)) calories")
        .accessibilityHint("Opens the entry")
        .accessibilityAction(named: "Delete") { Task { await model.deleteEntry(entry) } }
    }

    private var subtitle: String {
        var parts = [Format.time(entry.recordedAt)]
        if entry.isOneOff {
            parts.append("one-off")
        } else if entry.isAdjusted {
            parts.append("adjusted")
        }
        if model.currentDestination.isUnsectioned, model.hasSections, entry.sectionID != nil {
            parts.append("from \(model.destinationName(for: entry))")
        }
        return parts.joined(separator: " · ")
    }
}
