import InstalogCore
import SwiftUI

struct MealLibraryView: View {
    let model: DiaryModel
    @State private var removing: MealTemplate?

    var body: some View {
        List {
            SwiftUI.Section {
                ForEach(model.activeMeals) { meal in
                    NavigationLink {
                        MealEditorView(model: model, meal: meal, onDone: nil)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(meal.name).font(Typeface.sans(15, .semibold))
                            Text(detail(meal)).font(Typeface.sans(12)).foregroundStyle(Palette.tertiary)
                        }
                        .frame(minHeight: 44)
                    }
                    .listRowBackground(Palette.row)
                    .swipeActions {
                        Button("Remove", role: .destructive) { removing = meal }
                    }
                }
                NavigationLink {
                    MealEditorView(model: model, meal: nil, onDone: nil)
                } label: {
                    Label("New saved meal", systemImage: "plus").font(Typeface.sans(15, .semibold)).foregroundStyle(Palette.accent)
                }
                .listRowBackground(Palette.row)
            } footer: {
                Text("Library order is creation order. Each section can show its own order.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet)
        .navigationTitle("Saved meals")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove \(removing?.name ?? "meal")?", isPresented: Binding(get: { removing != nil }, set: { if !$0 { removing = nil } }),
            titleVisibility: .visible
        ) {
            Button("Remove meal", role: .destructive) {
                if let id = removing?.id {
                    Task {
                        do { try await model.archiveMeal(id: id) } catch { model.errorMessage = "Couldn’t remove the meal." }
                    }
                }
            }
        } message: {
            Text("It leaves every section and future choices. Entries you already logged keep their foods and nutrition.")
        }
        .foregroundStyle(Palette.text)
    }

    private func detail(_ meal: MealTemplate) -> String {
        let items = DraftItem.items(for: meal, foods: model.foods)
        let energy = (try? NutritionCalculator.summarize(items.map(\.calculatorItem)))?[.energy].known ?? 0
        let sections = model.sections(containing: meal.id).map(\.name)
        return (["\(meal.items.count) foods", "\(NumberFormatting.energy(energy)) kcal"] + sections).joined(separator: " · ")
    }
}

/// Create or edit a saved meal's name, foods, amounts and units. Saving changes future defaults only.
struct MealEditorView: View {
    let model: DiaryModel
    let meal: MealTemplate?
    let onDone: (() -> Void)?

    @State private var name = ""
    @State private var items: [DraftItem] = []
    @State private var pickingFood = false
    @State private var newFoods: [UUID: FoodDefinition] = [:]
    @State private var error: String?
    @State private var loaded = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let nutrition = (try? NutritionCalculator.summarize(items.map(\.calculatorItem))) ?? NutritionSummary()
        List {
            SwiftUI.Section {
                TextField("Meal name, e.g. Oats + yogurt", text: $name).font(Typeface.sans(17, .semibold))
                    .listRowBackground(Palette.row)
            } header: {
                Caption("Name")
            }
            SwiftUI.Section {
                ForEach($items) { $item in
                    DraftItemRow(
                        item: item, defaultWord: "default", setQuantity: { item.quantity = $0 },
                        units: item.food.nutrition.supportedUnits, setUnit: { unit in
                            item.unit = unit
                            item.quantity = unit == .gram || unit == .milliliter ? 100 : 1
                        })
                    .listRowBackground(Palette.row)
                }
                .onMove { items = items.moving(fromOffsets: $0, toOffset: $1) }
                .onDelete { items.remove(atOffsets: $0) }
                Button {
                    pickingFood = true
                } label: {
                    Label("Add food", systemImage: "plus").font(Typeface.sans(14, .semibold))
                }
                .foregroundStyle(Palette.accent)
                .listRowBackground(Palette.row)
            } header: {
                HStack {
                    Caption("Foods")
                    Spacer()
                    Caption("\(NumberFormatting.energy(nutrition[.energy].known)) kcal")
                }
            } footer: {
                Text(meal == nil
                    ? "Default amounts can be adjusted each time you log, without changing the saved meal."
                    : "Changes apply to future logs only. Entries you already logged stay as they were.")
            }
            if let error {
                Text(error).foregroundStyle(Palette.dangerText).listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet)
        .environment(\.editMode, .constant(.active))
        .navigationTitle(meal == nil ? "New saved meal" : "Edit meal")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let onDone {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onDone) }
            }
            ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).fontWeight(.semibold) }
        }
        .sheet(isPresented: $pickingFood) {
            NavigationStack {
                FoodPickerFlow(model: model) { food, quantity, unit in
                    if model.foods[food.id] == nil { newFoods[food.id] = food }
                    items.append(DraftItem(food: food, quantity: quantity, unit: unit))
                    pickingFood = false
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { pickingFood = false } }
                }
            }
            .presentationBackground(Palette.sheet)
        }
        .onAppear {
            guard !loaded, let meal else { return }
            loaded = true
            name = meal.name
            items = DraftItem.items(for: meal, foods: model.foods).map {
                var item = $0
                item.templateQuantity = nil
                return item
            }
        }
        .foregroundStyle(Palette.text)
    }

    private func save() {
        var updated = meal ?? MealTemplate(name: "", items: [], sortOrder: 0)
        updated.name = name
        updated.items = items.map { MealTemplateItem(id: $0.id, foodID: $0.food.id, defaultQuantity: $0.quantity, unit: $0.unit) }
        Task {
            do {
                try await model.saveMeal(updated, foods: Array(newFoods.values))
                if let onDone { onDone() } else { dismiss() }
            } catch let validation as MealValidationError {
                error = switch validation {
                case .blankName: "Give the meal a name."
                case .noFoods: "Add at least one food."
                case .invalidQuantity: "Every food needs an amount above zero."
                case .missingFood: "A food in this meal is no longer available."
                case .unsupportedUnit: "One of the units can’t be converted for that food."
                }
            } catch {
                self.error = "Couldn’t save the meal. \(error.localizedDescription)"
            }
        }
    }
}

/// Search, review, then return a food with an amount.
struct FoodPickerFlow: View {
    let model: DiaryModel
    let onPick: (FoodDefinition, Double, MeasureUnit) -> Void
    @State private var path: [FoodDefinition] = []

    var body: some View {
        FoodSearchView(model: model) { food in path.append(food) }
            .padding(16)
            .background(Palette.sheet)
            .navigationTitle("Add food")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: FoodDefinition.self) { food in
                FoodDetailView(food: food, actionTitle: "Add to meal") { quantity, unit in
                    onPick(food, quantity, unit)
                }
            }
            .errorAlert(model)
    }
}
