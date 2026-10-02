import InstalogCore
import SwiftUI

/// The selected saved meal as a draft. Quantity edits apply to this log only.
struct MealCard: View {
    @Bindable var model: DiaryModel

    var body: some View {
        let nutrition = model.draftNutrition
        let items = model.draftItems
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.selectedMeal?.name ?? "")
                        .font(Typeface.sans(20, .semibold, relativeTo: .title3))
                        .accessibilityAddTraits(.isHeader)
                    Text("Preview · not counted yet")
                        .font(Typeface.sans(12, relativeTo: .caption))
                        .foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Palette.handle, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 4) {
                    Text(NumberFormatting.energy(nutrition[.energy].known))
                        .font(Typeface.mono(26, .semibold, relativeTo: .title))
                    Text("kcal").font(Typeface.sans(12)).foregroundStyle(Palette.tertiary)
                }
            }
            .padding(.trailing, 4)
            MacroLine(nutrition: nutrition).padding(.top, 12)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    DraftItemRow(
                        item: item, defaultWord: "default",
                        setQuantity: { model.setDraftQuantity($0, for: item.id) })
                }
            }
            .overlay(alignment: .top) { Rectangle().fill(Palette.divider).frame(height: 1) }
            .padding(.top, 10)
            if model.isDraftAdjusted {
                HStack(spacing: 10) {
                    Text("Adjusted for this log only. Your saved meal won’t change.")
                        .font(Typeface.sans(12, relativeTo: .caption))
                        .foregroundStyle(Palette.secondary)
                    Spacer(minLength: 0)
                    Button("Reset") { model.resetDraft() }
                        .font(Typeface.sans(14, .semibold))
                        .foregroundStyle(Palette.accent)
                        .frame(minHeight: 44)
                        .padding(.horizontal, 6)
                }
                .padding(.vertical, 4)
            } else {
                Spacer().frame(height: 10)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 12)
        .padding(.top, 16)
        .padding(.bottom, 4)
        .cardBackground()
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                let dx = value.translation.width
                guard abs(dx) > 50, abs(dx) > abs(value.translation.height) * 1.5 else { return }
                withAnimation(.snappy) { model.browseMeals(by: dx < 0 ? 1 : -1) }
            }
        )
        .accessibilityElement(children: .contain)
        .accessibilityAction(named: "Next meal") { model.browseMeals(by: 1) }
        .accessibilityAction(named: "Previous meal") { model.browseMeals(by: -1) }
    }
}

struct MacroLine: View {
    let nutrition: NutritionSummary

    var body: some View {
        HStack(spacing: 14) {
            macro("P", .protein)
            macro("C", .carbohydrate)
            macro("F", .fat)
        }
        .font(Typeface.mono(12, relativeTo: .caption))
        .foregroundStyle(Palette.secondary)
    }

    private func macro(_ letter: String, _ id: NutrientID) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(Palette.nutrientColor(id)).frame(width: 7, height: 7)
            Text("\(letter) \(Format.amount(nutrition[id], unit: .gram))g")
            if nutrition[id].completeness == .partial { IncompleteMark() }
        }
        .accessibilityElement(children: .combine)
    }
}

/// One food with − / amount / + controls. Edited amounts are highlighted with their default.
struct DraftItemRow: View {
    let item: DraftItem
    let defaultWord: String
    let setQuantity: (Double) -> Void
    var units: [MeasureUnit] = []
    var setUnit: ((MeasureUnit) -> Void)?

    var body: some View {
        let energy = (try? item.food.nutrition.nutrients(quantity: item.quantity, unit: item.unit))?[.energy]
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.food.name)
                    .font(Typeface.sans(15, .medium))
                    .lineLimit(2)
                Group {
                    if item.isAdjusted, let template = item.templateQuantity {
                        Text("\(defaultWord) \(NumberFormatting.quantity(template)) \(item.food.nutrition.label(for: item.unit, quantity: template))")
                            .foregroundStyle(Palette.accent)
                    } else {
                        Text(energy.map { "\(NumberFormatting.energy($0)) kcal" } ?? "calories unknown")
                            .foregroundStyle(Palette.tertiary)
                    }
                }
                .font(Typeface.mono(12, relativeTo: .caption))
            }
            Spacer(minLength: 0)
            QuantityStepper(
                name: item.food.name, quantity: item.quantity, unit: item.unit, unitLabel: item.unitLabel,
                highlighted: item.isAdjusted, units: units, unitLabelFor: { item.food.nutrition.label(for: $0) },
                setQuantity: setQuantity, setUnit: setUnit)
        }
        .frame(minHeight: 60)
        .overlay(alignment: .bottom) { Rectangle().fill(Palette.border).frame(height: 1) }
    }
}

struct QuantityStepper: View {
    let name: String
    let quantity: Double
    let unit: MeasureUnit
    let unitLabel: String
    var highlighted = false
    var units: [MeasureUnit] = []
    var unitLabelFor: (MeasureUnit) -> String = { _ in "" }
    let setQuantity: (Double) -> Void
    var setUnit: ((MeasureUnit) -> Void)?

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 0) {
            Button { setQuantity(QuantityStep.decrease(quantity, unit: unit)) } label: {
                Image(systemName: "minus").frame(width: 40, height: 44)
            }
            .accessibilityLabel("Less \(name)")
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focused)
                    .frame(width: 44)
                    .font(Typeface.mono(15, .semibold))
                    .foregroundStyle(highlighted ? Palette.accent : Palette.text)
                    .accessibilityLabel("\(name), amount in \(unitLabel)")
                    .onSubmit(commit)
                    .onChange(of: focused) { _, isFocused in if !isFocused { commit() } }
                unitView
            }
            Button { setQuantity(QuantityStep.increase(quantity, unit: unit)) } label: {
                Image(systemName: "plus").frame(width: 40, height: 44)
            }
            .accessibilityLabel("More \(name)")
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(Palette.secondary)
        .buttonStyle(.plain)
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Palette.outline))
        .onAppear { text = NumberFormatting.quantity(quantity) }
        .onChange(of: quantity) { _, value in if !focused { text = NumberFormatting.quantity(value) } }
        .toolbar {
            if focused {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focused = false }
                }
            }
        }
    }

    @ViewBuilder
    private var unitView: some View {
        let label = Text(shortUnit(unitLabel))
            .font(Typeface.mono(12, .medium))
            .foregroundStyle(Palette.secondary)
            .frame(minWidth: 28, alignment: .leading)
            .lineLimit(1)
        if let setUnit, units.count > 1 {
            Menu {
                ForEach(units, id: \.self) { option in
                    Button(unitLabelFor(option)) { setUnit(option) }
                }
            } label: {
                HStack(spacing: 2) {
                    label
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 9))
                }
            }
            .accessibilityLabel("Unit, \(unitLabel)")
        } else {
            label
        }
    }

    private func shortUnit(_ label: String) -> String {
        let first = label.split(separator: ",").first.map(String.init) ?? label
        return first.count > 10 ? String(first.prefix(9)) + "…" : first
    }

    private func commit() {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        if let value = Double(normalized), value.isFinite, value >= 0 {
            setQuantity(value)
        } else {
            text = NumberFormatting.quantity(quantity)
        }
    }
}
