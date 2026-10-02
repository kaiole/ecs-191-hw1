import InstalogCore
import SwiftUI

/// Create a food from known nutrition information. Blank fields stay unknown; an entered 0 is known.
struct CustomFoodForm: View {
    let model: DiaryModel
    let onSave: (FoodDefinition) -> Void

    @State private var name: String
    @State private var brand = ""
    @State private var basisAmount = "100"
    @State private var dimension: MeasureDimension = .mass
    @State private var servingName = "serving"
    @State private var servingGrams = ""
    @State private var values: [NutrientID: String] = [:]
    @State private var showMore = false
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss

    private static let primary: [NutrientID] = [
        .energy, .protein, .carbohydrate, .fat, .fiber, .sugars, .saturatedFat, .sodium,
    ]

    init(model: DiaryModel, initialName: String = "", onSave: @escaping (FoodDefinition) -> Void) {
        self.model = model
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        Form {
            SwiftUI.Section("Food") {
                TextField("Name", text: $name)
                TextField("Brand (optional)", text: $brand)
            }
            SwiftUI.Section {
                Picker("Values are per", selection: $dimension) {
                    Text("grams").tag(MeasureDimension.mass)
                    Text("milliliters").tag(MeasureDimension.volume)
                    Text("serving").tag(MeasureDimension.serving)
                }
                HStack {
                    Text("Amount")
                    TextField("100", text: $basisAmount).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    Text(dimension == .mass ? "g" : dimension == .volume ? "mL" : servingName).foregroundStyle(Palette.secondary)
                }
                if dimension == .serving {
                    TextField("Serving name (e.g. bar, scoop)", text: $servingName)
                    HStack {
                        Text("Serving weight")
                        TextField("optional", text: $servingGrams).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        Text("g").foregroundStyle(Palette.secondary)
                    }
                }
            } header: {
                Text("Nutrition basis")
            } footer: {
                Text("Use the label’s serving or a 100 g / 100 mL basis.")
            }
            SwiftUI.Section {
                ForEach(Self.primary.compactMap(NutrientRegistry.definition(for:))) { field($0) }
                DisclosureGroup("More nutrients", isExpanded: $showMore) {
                    ForEach(NutrientRegistry.all.filter { !Self.primary.contains($0.id) }) { field($0) }
                }
            } header: {
                Text("Nutrients")
            } footer: {
                Text("Leave a field blank if the label doesn’t list it. Blank means unknown; 0 means none.")
            }
            if let error {
                Text(error).foregroundStyle(Palette.dangerText)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet)
        .navigationTitle("Custom food")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
        }
    }

    private func field(_ definition: NutrientDefinition) -> some View {
        HStack {
            Text(definition.name)
            TextField("—", text: Binding(get: { values[definition.id] ?? "" }, set: { values[definition.id] = $0 }))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .accessibilityLabel("\(definition.name) in \(definition.unit.rawValue)")
            Text(definition.unit.rawValue).foregroundStyle(Palette.secondary).frame(minWidth: 32, alignment: .leading)
        }
    }

    private func number(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    private func save() {
        var profile = NutrientProfile()
        for (id, text) in values {
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            guard let value = number(text), value.isFinite, value >= 0 else {
                error = "\(NutrientRegistry.definition(for: id)?.name ?? id.rawValue) must be a number of zero or more."
                return
            }
            profile[id] = value
        }
        guard let amount = number(basisAmount) else {
            error = "Enter the amount the nutrition values refer to."
            return
        }
        let servingWeight = dimension == .serving ? number(servingGrams) : nil
        let basis = NutritionBasis(
            amount: amount, dimension: dimension,
            servingName: dimension == .serving ? servingName.trimmingCharacters(in: .whitespaces) : nil,
            servingGrams: servingWeight)
        let food = FoodDefinition(
            source: .custom, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            brand: brand.trimmingCharacters(in: .whitespaces).isEmpty ? nil : brand.trimmingCharacters(in: .whitespaces),
            nutrition: FoodNutrition(basis: basis, nutrients: profile))
        Task {
            do {
                try await model.saveCustomFood(food)
                onSave(food)
            } catch let validation as FoodValidationError {
                error = switch validation {
                case .blankName: "Give the food a name."
                case .invalidBasis: "The basis amount must be above zero."
                case .noNutrients: "Enter at least one nutrient value."
                case .invalidNutrientValue: "Nutrient values must be zero or more."
                case .invalidPortion: "Serving weight must be above zero."
                }
            } catch {
                self.error = "Couldn’t save the food. \(error.localizedDescription)"
            }
        }
    }
}
