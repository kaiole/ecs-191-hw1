import InstalogCore
import SwiftUI

/// Consumed calories and the user's chosen summary nutrients. Drafts appear only as a preview.
struct SummaryHeader: View {
    let model: DiaryModel
    let openDetails: () -> Void

    var body: some View {
        let day = model.dayNutrition
        let energy = day[.energy]
        let target = model.effectiveTargets[.energy]
        let preview = model.selectedMeal == nil ? 0 : model.draftNutrition[.energy].known

        Button(action: openDetails) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Caption("Consumed")
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(NumberFormatting.energy(energy.known))
                                .font(Typeface.mono(34, .semibold, relativeTo: .largeTitle))
                                .tracking(-1)
                            if energy.completeness == .partial { IncompleteMark() }
                            Text(target.map { "/ \(NumberFormatting.energy($0.amount)) kcal" } ?? "kcal")
                                .font(Typeface.sans(14, relativeTo: .subheadline))
                                .foregroundStyle(Palette.secondary)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 3) {
                        if let target {
                            Text("\(NumberFormatting.energy(max(0, target.amount - energy.known))) left")
                                .font(Typeface.mono(14, .medium))
                        }
                        if preview > 0 {
                            Text("preview +\(NumberFormatting.energy(preview))")
                                .font(Typeface.mono(11, relativeTo: .caption2))
                                .foregroundStyle(Palette.tertiary)
                        }
                    }
                }
                EnergyBar(consumed: energy.known, preview: preview, target: target?.amount)
                    .padding(.top, 10)
                metrics(day)
                    .padding(.top, 12)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(energy: energy, target: target))
        .accessibilityHint("Shows all nutrients for the day")
    }

    private func metrics(_ day: NutritionSummary) -> some View {
        let nutrients = model.preferences.summaryNutrients
        return HStack(alignment: .top, spacing: 14) {
            ForEach(nutrients, id: \.self) { id in
                if let definition = NutrientRegistry.definition(for: id) {
                    MetricColumn(
                        definition: definition, comparison: TargetResolver.compare(day[id], with: model.effectiveTargets[id]))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private func accessibilityText(energy: NutrientTotal, target: EffectiveTarget?) -> String {
        var text = "Consumed \(NumberFormatting.energy(energy.known)) calories"
        if let target { text += " of \(NumberFormatting.energy(target.amount))" }
        if energy.completeness == .partial { text += ", incomplete" }
        return text
    }
}

private struct MetricColumn: View {
    let definition: NutrientDefinition
    let comparison: TargetComparison

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 2).fill(Palette.nutrientColor(definition.id)).frame(width: 8, height: 8)
                Text(definition.shortName)
                    .font(Typeface.sans(12, relativeTo: .caption))
                    .foregroundStyle(Palette.secondary)
                    .lineLimit(1)
            }
            HStack(spacing: 0) {
                Text(Format.amount(comparison.total, unit: definition.unit)).fontWeight(.semibold)
                Text(targetText).foregroundStyle(Palette.tertiary)
                if comparison.isQualified { IncompleteMark().padding(.leading, 3) }
            }
            .font(Typeface.mono(14, relativeTo: .subheadline))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Capsule()
                .fill(Palette.control)
                .frame(height: 3)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(Palette.nutrientColor(definition.id))
                            .frame(width: proxy.size.width * min(1, comparison.fraction ?? 0))
                    }
                }
                .padding(.top, 3)
                .opacity(comparison.fraction == nil ? 0.5 : 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var targetText: String {
        guard let target = comparison.target, comparison.isComparable else { return " \(definition.unit.rawValue)" }
        return " / \(NumberFormatting.nutrient(target.amount)) \(definition.unit.rawValue)"
    }

    private var accessibilityText: String {
        var text = "\(definition.name) \(Format.amount(comparison.total, unit: definition.unit)) \(definition.unit.rawValue)"
        if let target = comparison.target, comparison.isComparable {
            text += " of \(NumberFormatting.nutrient(target.amount))"
        }
        if let note = Format.completenessNote(comparison.total) { text += ". \(note)" }
        return text
    }
}

private struct EnergyBar: View {
    let consumed: Double
    let preview: Double
    let target: Double?

    var body: some View {
        GeometryReader { proxy in
            let scale = max(target ?? 0, consumed + preview, 1)
            let consumedWidth = proxy.size.width * min(1, consumed / scale)
            let previewWidth = min(proxy.size.width - consumedWidth, proxy.size.width * preview / scale)
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.control)
                HatchedFill()
                    .frame(width: max(0, previewWidth))
                    .offset(x: consumedWidth)
                Capsule().fill(Palette.accent).frame(width: consumedWidth)
            }
            .clipShape(Capsule())
        }
        .frame(height: 6)
        .accessibilityHidden(true)
    }
}

/// Diagonal stripes marking an uncounted preview.
private struct HatchedFill: View {
    var body: some View {
        Canvas { context, size in
            var x: CGFloat = -size.height
            while x < size.width {
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                context.stroke(path, with: .color(Palette.accent.opacity(0.55)), lineWidth: 2)
                x += 5
            }
        }
    }
}
