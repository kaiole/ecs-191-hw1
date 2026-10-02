import InstalogCore
import SwiftUI

/// Search custom foods and the bundled USDA catalog. A catalog failure is shown as such and
/// never hides custom foods or the custom-food entry path.
struct FoodSearchView: View {
    let model: DiaryModel
    let onPick: (FoodDefinition) -> Void
    @State private var query = ""
    @State private var outcome: FoodSearchOutcome?
    @State private var isSearching = false
    @State private var creatingCustom = false
    @State private var loadingID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Palette.secondary)
                TextField("Search foods", text: $query)
                    .font(Typeface.sans(16))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .foregroundStyle(Palette.tertiary)
                        .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .background(Palette.control, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            List {
                if let error = outcome?.catalogError {
                    Label("USDA search unavailable: \(error). Your foods and custom entry still work.", systemImage: "exclamationmark.triangle")
                        .font(Typeface.sans(13))
                        .foregroundStyle(Palette.dangerText)
                        .listRowBackground(Color.clear)
                }
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    if !model.customFoods.isEmpty {
                        SwiftUI.Section { ForEach(model.customFoods) { customRow($0) } } header: { Caption("Your foods") }
                    }
                } else if let outcome {
                    if !outcome.personalFoods.isEmpty {
                        SwiftUI.Section { ForEach(outcome.personalFoods) { customRow($0) } } header: { Caption("Your foods") }
                    }
                    if !outcome.catalogFoods.isEmpty {
                        SwiftUI.Section {
                            ForEach(outcome.catalogFoods) { catalogRow($0) }
                        } header: {
                            Caption(model.catalog?.sourceDescription ?? "USDA")
                        }
                    }
                    if outcome.personalFoods.isEmpty, outcome.catalogFoods.isEmpty, outcome.catalogError == nil, !isSearching {
                        Text("No matches for “\(query)”. Try fewer words, or create a custom food.")
                            .font(Typeface.sans(14))
                            .foregroundStyle(Palette.secondary)
                            .listRowBackground(Color.clear)
                    }
                }
                Button("Create a custom food…") { creatingCustom = true }
                    .font(Typeface.sans(14, .semibold))
                    .foregroundStyle(Palette.accent)
                    .listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
        .task(id: query) {
            let text = query
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
                outcome = nil
                return
            }
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            isSearching = true
            let result = await model.searchFoods(text)
            if !Task.isCancelled { outcome = result }
            isSearching = false
        }
        .sheet(isPresented: $creatingCustom) {
            NavigationStack {
                CustomFoodForm(model: model, initialName: query) { food in
                    creatingCustom = false
                    onPick(food)
                }
            }
            .presentationBackground(Palette.sheet)
        }
    }

    private func customRow(_ food: FoodDefinition) -> some View {
        Button { onPick(food) } label: {
            resultLabel(
                name: food.name, detail: [food.brand, "Custom", food.nutrition.basis.label].compactMap { $0 }.joined(separator: " · "),
                energy: food.nutrition.nutrients[.energy], loading: false)
        }
        .listRowBackground(Color.clear)
    }

    private func catalogRow(_ summary: CatalogFoodSummary) -> some View {
        Button {
            Task {
                loadingID = summary.id
                defer { loadingID = nil }
                do {
                    onPick(try await model.food(forCatalogID: summary.id))
                } catch {
                    model.errorMessage = "Couldn’t open that food. \(error.localizedDescription)"
                }
            }
        } label: {
            resultLabel(
                name: summary.name,
                detail: [summary.sourceLabel, summary.category].compactMap { $0 }.joined(separator: " · "),
                energy: summary.energyPer100Grams, loading: loadingID == summary.id, per100g: true,
                preparation: summary.preparation)
        }
        .listRowBackground(Color.clear)
    }

    private func resultLabel(
        name: String, detail: String, energy: Double?, loading: Bool, per100g: Bool = false, preparation: String? = nil
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(Typeface.sans(15, .medium)).foregroundStyle(Palette.text)
                HStack(spacing: 6) {
                    if let preparation {
                        Text(preparation)
                            .font(Typeface.sans(11, .semibold))
                            .foregroundStyle(Palette.text)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1)
                            .background(Palette.control, in: Capsule())
                    }
                    Text(detail).font(Typeface.mono(11)).foregroundStyle(Palette.tertiary).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            if loading {
                ProgressView()
            } else {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(energy.map(NumberFormatting.energy) ?? "—").font(Typeface.mono(14)).foregroundStyle(Palette.secondary)
                    Text(per100g ? "kcal/100 g" : "kcal").font(Typeface.sans(10)).foregroundStyle(Palette.tertiary)
                }
            }
        }
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

/// Review a food's nutrition and portions, choose an amount, then add it.
struct FoodDetailView: View {
    let food: FoodDefinition
    let actionTitle: String
    let onAdd: (Double, MeasureUnit) -> Void
    @State private var quantity: Double
    @State private var unit: MeasureUnit
    @State private var showAll = false

    init(food: FoodDefinition, actionTitle: String, onAdd: @escaping (Double, MeasureUnit) -> Void) {
        self.food = food
        self.actionTitle = actionTitle
        self.onAdd = onAdd
        let initialUnit = Self.defaultUnit(for: food.nutrition)
        _unit = State(initialValue: initialUnit)
        _quantity = State(initialValue: initialUnit == .gram || initialUnit == .milliliter ? 100 : 1)
    }

    var body: some View {
        let nutrients = (try? food.nutrition.nutrients(quantity: quantity, unit: unit)) ?? NutrientProfile()
        let grams = food.nutrition.grams(quantity: quantity, unit: unit)
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(food.name).font(Typeface.sans(20, .semibold, relativeTo: .title3))
                    Text(identity).font(Typeface.mono(12)).foregroundStyle(Palette.tertiary)
                }
                HStack {
                    Text("Amount").font(Typeface.sans(15, .medium))
                    Spacer()
                    QuantityStepper(
                        name: food.name, quantity: quantity, unit: unit,
                        unitLabel: food.nutrition.label(for: unit, quantity: quantity),
                        units: food.nutrition.supportedUnits, unitLabelFor: { unitDescription($0) },
                        setQuantity: { quantity = $0 }, setUnit: { newUnit in
                            unit = newUnit
                            quantity = newUnit == .gram || newUnit == .milliliter ? 100 : 1
                        })
                }
                if let grams, unit != .gram {
                    Text("= \(NumberFormatting.quantity(grams)) g").font(Typeface.mono(12)).foregroundStyle(Palette.tertiary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(nutrients[.energy].map(NumberFormatting.energy) ?? "—").font(Typeface.mono(30, .semibold))
                    Text(" kcal").font(Typeface.mono(13)).foregroundStyle(Palette.tertiary)
                }
                VStack(spacing: 0) {
                    ForEach(rows, id: \.id) { definition in
                        HStack {
                            Text(definition.name).font(Typeface.sans(14))
                            Spacer()
                            if let value = nutrients[definition.id] {
                                Text(NumberFormatting.nutrient(value, unit: definition.unit)).font(Typeface.mono(13))
                            } else {
                                Text("not reported").font(Typeface.sans(12)).foregroundStyle(Palette.tertiary)
                            }
                        }
                        .frame(minHeight: 34)
                        .overlay(alignment: .bottom) { Rectangle().fill(Palette.border).frame(height: 1) }
                        .accessibilityElement(children: .combine)
                    }
                }
                Button(showAll ? "Show fewer nutrients" : "Show all reported nutrients") { showAll.toggle() }
                    .font(Typeface.sans(14, .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: 44)
                Text("Nutrition \(food.nutrition.basis.label). Missing values are unknown, not zero.")
                    .font(Typeface.sans(12))
                    .foregroundStyle(Palette.tertiary)
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            Button("\(actionTitle) · \(nutrients[.energy].map(NumberFormatting.energy) ?? "—") kcal") {
                onAdd(quantity, unit)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(quantity <= 0)
            .padding(16)
            .background(Palette.sheet)
        }
        .background(Palette.sheet)
        .foregroundStyle(Palette.text)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A recognizable single serving when the source has one, otherwise the basis unit.
    private static func defaultUnit(for nutrition: FoodNutrition) -> MeasureUnit {
        if nutrition.basis.dimension == .serving { return .serving }
        for keyword in ["medium", "serving", "large", "slice", "piece"] {
            if let portion = nutrition.portions.first(where: { $0.name.lowercased().contains(keyword) }) {
                return .portion(id: portion.id)
            }
        }
        return nutrition.basis.dimension == .volume ? .milliliter : .gram
    }

    private var identity: String {
        [food.sourceLabel, food.category, food.preparation, food.brand].compactMap { $0 }.joined(separator: " · ")
    }

    private var rows: [NutrientDefinition] {
        let summaryIDs: [NutrientID] = [
            .protein, .carbohydrate, .fat, .fiber, .sugars, .saturatedFat, .sodium, .cholesterol,
        ]
        if !showAll { return summaryIDs.compactMap(NutrientRegistry.definition(for:)) }
        return NutrientRegistry.all.filter { $0.id != .energy && food.nutrition.nutrients[$0.id] != nil }
    }

    private func unitDescription(_ unit: MeasureUnit) -> String {
        let label = food.nutrition.label(for: unit)
        if case .portion(let id) = unit, let grams = food.nutrition.portion(id: id)?.grams {
            return "\(label) (\(NumberFormatting.quantity(grams)) g)"
        }
        return label
    }
}
