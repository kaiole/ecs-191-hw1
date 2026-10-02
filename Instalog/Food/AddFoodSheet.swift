import InstalogCore
import SwiftUI

/// Add food: log a saved meal, foods from search, or a custom food into the section it was
/// opened from. Never advances sections. Cancelling writes nothing.
struct AddFoodSheet: View {
    let model: DiaryModel
    let destination: Destination
    let date: LogDate
    let close: () -> Void

    private enum Tab: Hashable {
        case saved
        case foods
    }

    @State private var tab: Tab = .saved
    @State private var plate: [DraftItem] = []
    @State private var plateMealID: UUID?
    @State private var plateName = ""
    @State private var showingPlate = false
    @State private var saveAsMeal = false
    @State private var path: [FoodDefinition] = []
    @State private var confirmingDiscard = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 0) {
                SheetHeader(title: "Add food", subtitle: subtitle, close: requestClose)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                if showingPlate {
                    plateView
                } else {
                    browseView
                }
            }
            .background(Palette.sheet)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: FoodDefinition.self) { food in
                FoodDetailView(food: food, actionTitle: "Add to this entry") { quantity, unit in
                    plate.append(DraftItem(food: food, quantity: quantity, unit: unit))
                    if plate.count == 1, plateMealID == nil { plateName = food.name }
                    path.removeAll()
                    showingPlate = true
                }
            }
        }
        .foregroundStyle(Palette.text)
        .interactiveDismissDisabled(!plate.isEmpty)
        .onAppear { tab = model.activeMeals.isEmpty ? .foods : .saved }
        .confirmationDialog("Discard this food?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard", role: .destructive, action: close)
            Button("Keep editing", role: .cancel) {}
        } message: {
            Text("Nothing has been logged yet.")
        }
    }

    private var destinationLabel: String {
        destination.isUnsectioned && !model.hasSections ? "today" : destination.name
    }

    private var subtitle: String {
        var text = "Logs to \(destinationLabel). Your place in the day stays put."
        if date != model.today { text = "Logs to \(destinationLabel) on \(Format.dayStamp(date))." }
        return text
    }

    private func requestClose() {
        if plate.isEmpty { close() } else { confirmingDiscard = true }
    }

    // MARK: Browse

    private var browseView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Add from", selection: $tab) {
                Text("Saved meals").tag(Tab.saved)
                Text("Foods").tag(Tab.foods)
            }
            .pickerStyle(.segmented)
            .disabled(!plate.isEmpty && plateMealID != nil)
            switch tab {
            case .saved: savedMeals
            case .foods: FoodSearchView(model: model) { food in path.append(food) }
            }
            if !plate.isEmpty {
                Button {
                    showingPlate = true
                } label: {
                    HStack {
                        Text("\(plate.count) food\(plate.count == 1 ? "" : "s") ready")
                        Spacer()
                        Text("Review").fontWeight(.semibold)
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var savedMeals: some View {
        if model.activeMeals.isEmpty {
            Text("No saved meals yet. Switch to Foods to log something now, or create a saved meal from settings.")
                .font(Typeface.sans(14))
                .foregroundStyle(Palette.secondary)
                .padding(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Palette.outline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(model.activeMeals) { meal in
                        Button { pick(meal) } label: { savedMealRow(meal) }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func savedMealRow(_ meal: MealTemplate) -> some View {
        let items = DraftItem.items(for: meal, foods: model.foods)
        let energy = (try? NutritionCalculator.summarize(items.map(\.calculatorItem)))?[.energy].known ?? 0
        let sections = model.sections(containing: meal.id).map(\.name)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(meal.name).font(Typeface.sans(16, .semibold))
                Text((["\(meal.items.count) foods"] + sections).joined(separator: " · "))
                    .font(Typeface.sans(12))
                    .foregroundStyle(Palette.tertiary)
            }
            Spacer(minLength: 0)
            Text(NumberFormatting.energy(energy)).font(Typeface.mono(14)).foregroundStyle(Palette.secondary)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Palette.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minHeight: 60)
        .background(Palette.row, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
    }

    private func pick(_ meal: MealTemplate) {
        plate = DraftItem.items(for: meal, foods: model.foods)
        plateMealID = meal.id
        plateName = meal.name
        saveAsMeal = false
        showingPlate = true
    }

    // MARK: Plate

    private var plateView: some View {
        let nutrition = (try? NutritionCalculator.summarize(plate.map(\.calculatorItem))) ?? NutritionSummary()
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                showingPlate = false
                if plateMealID != nil {
                    plate = []
                    plateMealID = nil
                }
            } label: {
                Label(plateMealID != nil ? "All saved meals" : "Search more foods", systemImage: "chevron.left")
                    .font(Typeface.sans(14, .medium))
                    .foregroundStyle(Palette.secondary)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.plain)
            HStack(alignment: .firstTextBaseline) {
                if plateMealID != nil {
                    Text(plateName).font(Typeface.sans(20, .semibold))
                } else {
                    TextField("Entry name", text: $plateName)
                        .font(Typeface.sans(20, .semibold))
                        .accessibilityLabel("Entry name")
                }
                Spacer()
                Text(NumberFormatting.energy(nutrition[.energy].known)).font(Typeface.mono(22, .semibold))
                Text("kcal").font(Typeface.mono(12)).foregroundStyle(Palette.tertiary)
            }
            MacroLine(nutrition: nutrition).padding(.top, 6)
            List {
                ForEach($plate) { $item in
                    DraftItemRow(
                        item: item, defaultWord: "default", setQuantity: { item.quantity = $0 },
                        units: item.food.nutrition.supportedUnits, setUnit: { unit in
                            item.unit = unit
                            item.quantity = unit == .gram || unit == .milliliter ? 100 : 1
                        })
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onDelete { plate.remove(atOffsets: $0) }
                if plateMealID == nil {
                    Button {
                        showingPlate = false
                        tab = .foods
                    } label: {
                        Label("Add another food", systemImage: "plus")
                            .font(Typeface.sans(14, .semibold))
                            .foregroundStyle(Palette.accent)
                    }
                    .listRowBackground(Color.clear)
                    Toggle(isOn: $saveAsMeal) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Also save as a meal").font(Typeface.sans(14, .medium))
                            Text("Off by default. One-offs stay one-offs.").font(Typeface.sans(12)).foregroundStyle(Palette.tertiary)
                        }
                    }
                    .tint(Palette.accent)
                    .listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            Button {
                Task { await logPlate() }
            } label: {
                HStack {
                    Text("Log to \(destinationLabel)")
                    Spacer()
                    Text(NumberFormatting.energy(nutrition[.energy].known))
                        .font(Typeface.mono(14, .semibold))
                        .foregroundStyle(Palette.onAccentDim)
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(model.isLogging || !plate.contains { $0.quantity > 0 })
            .padding(.top, 12)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    private func logPlate() async {
        let name = plateName.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = plate.count == 1 ? plate[0].food.name : "\(plate[0].food.name) + \(plate.count - 1) more"
        let entryName = name.isEmpty ? fallback : name
        do {
            try await model.logAdditional(
                name: entryName, items: plate, mealTemplateID: plateMealID, destination: destination, date: date,
                saveAsMealNamed: saveAsMeal && plateMealID == nil ? entryName : nil)
            close()
        } catch {
            model.errorMessage = "Couldn’t log this. Nothing was saved. (\(error.localizedDescription))"
        }
    }
}
