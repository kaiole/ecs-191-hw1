import InstalogCore
import SwiftUI

/// Inspect and edit one logged entry. Edits apply to a copy and are saved together on Done;
/// closing without Done discards them. The originating saved meal never changes.
struct EntrySheet: View {
    let model: DiaryModel
    let original: LoggedEntry
    let close: () -> Void

    @State private var draft: LoggedEntry
    @State private var confirmingDelete = false
    @State private var confirmingDiscard = false
    @State private var savingAsMeal = false
    @State private var newMealName = ""
    @State private var isSaving = false

    init(model: DiaryModel, original: LoggedEntry, close: @escaping () -> Void) {
        self.model = model
        self.original = original
        self.close = close
        _draft = State(initialValue: original)
    }

    private var hasChanges: Bool { draft.foods != original.foods }

    var body: some View {
        let nutrition = NutritionCalculator.summarize(draft)
        VStack(alignment: .leading, spacing: 0) {
            SheetHeader(
                title: draft.name,
                subtitle: "Logged \(Format.time(draft.recordedAt)) · \(model.destinationName(for: draft))",
                close: requestClose
            ) {
                moveMenu
            }
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(NumberFormatting.energy(nutrition[.energy].known)).font(Typeface.mono(26, .semibold))
                    Text(" kcal").font(Typeface.mono(12)).foregroundStyle(Palette.tertiary)
                }
                MacroLine(nutrition: nutrition)
            }
            .padding(.horizontal, 4)
            .padding(.top, 14)
            Label(note, systemImage: "info.circle")
                .font(Typeface.sans(13, relativeTo: .footnote))
                .foregroundStyle(Color(hex: 0xC3CAD0))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.control, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(.top, 12)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(draft.foods.enumerated()), id: \.element.id) { index, food in
                        DraftItemRow(
                            item: draftItem(food), defaultWord: "saved",
                            setQuantity: { draft.foods[index].quantity = $0 })
                    }
                }
                .padding(.leading, 4)
                if draft.isOneOff {
                    Button("Save as a meal…") {
                        newMealName = draft.name
                        savingAsMeal = true
                    }
                    .font(Typeface.sans(14, .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: 44)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
            }
            .padding(.top, 6)
            if confirmingDelete {
                deleteConfirmation
            } else {
                HStack(spacing: 10) {
                    Button {
                        withAnimation { confirmingDelete = true }
                    } label: {
                        Label("Delete…", systemImage: "trash")
                            .font(Typeface.sans(15, .semibold))
                            .foregroundStyle(Palette.dangerText)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(Palette.control, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button(action: save) {
                        Text(hasChanges ? "Save changes" : "Done")
                            .font(Typeface.sans(16, .semibold))
                            .foregroundStyle(Palette.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Palette.text, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving)
                }
                .padding(.top, 14)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .foregroundStyle(Palette.text)
        .interactiveDismissDisabled(hasChanges)
        .confirmationDialog("Discard changes to this entry?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("Discard changes", role: .destructive, action: close)
            Button("Keep editing", role: .cancel) {}
        }
        .alert("Save as a meal", isPresented: $savingAsMeal) {
            TextField("Meal name", text: $newMealName)
            Button("Save") { Task { await saveAsMeal() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Creates a saved meal from these foods and amounts. This entry stays as logged.")
        }
    }

    private var note: String {
        if let id = draft.mealTemplateID, let meal = model.meal(id: id) {
            return "Changes apply to this entry only. Your saved “\(meal.name)” stays as it is."
        }
        return draft.isOneOff
            ? "One-off entry. It isn’t a saved meal unless you choose to save it."
            : "Changes apply to this entry only."
    }

    private var moveMenu: some View {
        Menu {
            Section("Move to") {
                ForEach(model.activeSections.filter { $0.id != draft.sectionID }) { section in
                    Button(section.name) { Task { await move(to: Destination(section: section)) } }
                }
                if draft.sectionID != nil {
                    Button("Unsectioned") { Task { await move(to: Destination(section: nil)) } }
                }
            }
        } label: {
            Image(systemName: "arrow.left.arrow.right").font(.system(size: 15, weight: .semibold))
                .frame(width: 44, height: 44)
                .foregroundStyle(Palette.secondary)
                .background(Palette.control, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityLabel("Move to another section")
        .disabled(!model.hasSections)
    }

    private var deleteConfirmation: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Delete “\(draft.name)” from \(model.destinationName(for: draft))?")
                .font(Typeface.sans(15, .semibold))
            Text("Only this entry is removed. Your saved meal stays, and you can undo right after.")
                .font(Typeface.sans(13))
                .foregroundStyle(Color(hex: 0xD9B3AE))
            HStack(spacing: 10) {
                Button("Keep") { withAnimation { confirmingDelete = false } }
                    .font(Typeface.sans(15, .semibold))
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Color(hex: 0x3A2220), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                Button("Delete entry") {
                    Task {
                        await model.deleteEntry(original)
                        close()
                    }
                }
                .font(Typeface.sans(15, .semibold))
                .foregroundStyle(Color(hex: 0x1A0503))
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Color(hex: 0xFF6B5E), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .padding(14)
        .background(Palette.dangerSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(hex: 0x4A2420)))
        .padding(.top, 14)
        .accessibilityElement(children: .contain)
    }

    private func draftItem(_ food: LoggedFoodSnapshot) -> DraftItem {
        DraftItem(
            id: food.id, food: food.asFoodDefinition, quantity: food.quantity, unit: food.unit,
            templateQuantity: draft.mealTemplateID == nil ? nil : food.templateQuantity)
    }

    private func requestClose() {
        if hasChanges { confirmingDiscard = true } else { close() }
    }

    private func save() {
        guard hasChanges else { return close() }
        isSaving = true
        Task {
            do {
                try await model.updateEntry(draft)
                close()
            } catch {
                model.errorMessage = error is EntryValidationError
                    ? "An entry needs at least one food with an amount above zero. To remove it, delete the entry."
                    : "Couldn’t save changes. \(error.localizedDescription)"
            }
            isSaving = false
        }
    }

    private func move(to destination: Destination) async {
        do {
            try await model.moveEntry(original, to: destination)
            close()
        } catch {
            model.errorMessage = "Couldn’t move the entry. \(error.localizedDescription)"
        }
    }

    private func saveAsMeal() async {
        let foods = draft.foods.filter { $0.quantity > 0 }
        let definitions = foods.map(\.asFoodDefinition)
        let meal = MealTemplate(
            name: newMealName,
            items: zip(foods, definitions).map { snapshot, food in
                MealTemplateItem(foodID: food.id, defaultQuantity: snapshot.quantity, unit: snapshot.unit)
            },
            sortOrder: 0)
        do {
            try await model.saveMeal(meal, foods: definitions.filter { model.foods[$0.id] == nil })
            model.toast = Toast(message: "Saved “\(meal.name)” as a meal", undo: nil)
        } catch {
            model.errorMessage = "Couldn’t save the meal. Give it a name and at least one food."
        }
    }
}

extension LoggedFoodSnapshot {
    /// A food definition carrying this snapshot's data, reusing the original food ID when known.
    var asFoodDefinition: FoodDefinition {
        FoodDefinition(
            id: foodID ?? id, source: source, sourceFoodID: sourceFoodID, name: name, brand: brand,
            preparation: preparation, sourceDataType: sourceDataType, sourceVersion: sourceVersion,
            nutrition: nutrition)
    }
}
