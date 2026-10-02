import Foundation
import Testing
@testable import InstalogCore

@MainActor
@Suite("Routine logging (acceptance)")
struct DiaryModelTests {
    let clock = TestClock()

    private func seeded() async throws -> (DiaryModel, Routine, SQLitePersonalStore) {
        let store = try SQLitePersonalStore(url: nil)
        let routine = try await Scenario.seedRoutine(into: store)
        return (await Scenario.model(store: store, clock: clock), routine, store)
    }

    @Test("AT-01: no sections and no meals is a usable empty state")
    func emptyState() async throws {
        let model = await Scenario.model(store: try SQLitePersonalStore(url: nil), clock: clock)
        #expect(model.isLoaded)
        #expect(!model.hasSections)
        #expect(model.currentDestination.isUnsectioned)
        #expect(model.selectedMeal == nil)
        #expect(model.dayNutrition.isEmpty)
    }

    @Test("AT-02: meals without sections log unsectioned with no progression")
    func mealsWithoutSections() async throws {
        let store = try SQLitePersonalStore(url: nil)
        let meal = Fixtures.meal("Oats", [(Fixtures.oats, 60)], order: 0)
        let other = Fixtures.meal("B", [(Fixtures.foodB, 100)], order: 1)
        try await store.apply(Fixtures.allFoods.map(StoreOperation.putFood) + [.putMeal(meal), .putMeal(other)])
        let model = await Scenario.model(store: store, clock: clock)
        try await model.setAutoProgression(true)

        #expect(model.currentMeals.map(\.name) == ["Oats", "B"])
        #expect(await model.logSelectedMeal())
        #expect(model.entries.count == 1)
        #expect(model.entries[0].sectionID == nil)
        #expect(model.currentDestination.isUnsectioned)
        #expect(model.selectedMeal?.id == meal.id, "Logging does not imply selecting the next meal")
    }

    @Test("AT-03: new-day start and progression follow the persisted section order")
    func sectionOrder() async throws {
        let (model, routine, store) = try await seeded()
        try await model.moveSections(from: [3], to: 0)
        #expect(model.activeSections.map(\.name) == ["Dinner", "Breakfast", "Lunch", "Snack"])

        clock.advance(seconds: 86_400)
        let reopened = await Scenario.model(store: store, clock: clock)
        #expect(reopened.currentDestination.section?.id == routine.dinner.id)
        try await reopened.setAutoProgression(true)
        await reopened.logSelectedMeal()
        #expect(reopened.currentDestination.section?.id == routine.breakfast.id)
    }

    @Test("AT-04: configured meals appear in order; the first is the default")
    func configuredMeals() async throws {
        let (model, routine, _) = try await seeded()
        #expect(model.currentMeals.map(\.id) == [routine.oatsMeal.id, routine.yogurtMeal.id, routine.shakeMeal.id])
        #expect(model.selectedMeal?.id == routine.oatsMeal.id)
    }

    @Test("AT-05: an unconfigured section offers all active meals in library order")
    func fallback() async throws {
        let (model, routine, _) = try await seeded()
        model.selectDestination(id: SectionKey.key(for: routine.dinner.id))
        #expect(model.currentUsesAllMeals)
        #expect(model.currentMeals.map(\.name) == ["Oats + milk", "Yogurt", "Protein shake", "Lunch bowl"])
    }

    @Test("AT-06: browsing sections and meals changes nothing that counts")
    func browsingHasNoSideEffects() async throws {
        let (model, _, store) = try await seeded()
        model.browseMeals(by: 1)
        model.browseDestinations(by: 1)
        model.browseDestinations(by: -2)
        model.browseMeals(by: 1)
        model.setDraftQuantity(999, for: model.draftItems[0].id)
        #expect(model.entries.isEmpty)
        #expect(model.dayNutrition.isEmpty)
        #expect(try await store.allEntries().isEmpty)
        let meals = try await store.loadConfiguration().meals
        #expect(meals.allSatisfy { meal in meal.items.allSatisfy { $0.defaultQuantity != 999 } })
    }

    @Test("AT-07: logging with auto-progression off stays in the section")
    func logStays() async throws {
        let (model, routine, store) = try await seeded()
        #expect(await model.logSelectedMeal())
        #expect(model.entries.count == 1)
        #expect(model.entries[0].sectionID == routine.breakfast.id)
        #expect(model.entries[0].path == .normal)
        #expect(model.currentDestination.section?.id == routine.breakfast.id)
        #expect(try await store.allEntries().count == 1)
        #expect(model.dayNutrition[.energy].known > 0)
    }

    @Test("AT-08: auto-progression saves first, then moves to the next section only")
    func autoProgression() async throws {
        let (model, routine, _) = try await seeded()
        try await model.setAutoProgression(true)
        model.selectMeal(id: routine.yogurtMeal.id)
        await model.logSelectedMeal()
        #expect(model.entries.last?.sectionID == routine.breakfast.id)
        #expect(model.currentDestination.section?.id == routine.lunch.id)
        model.selectDestination(id: SectionKey.key(for: routine.breakfast.id))
        #expect(model.selectedMeal?.id == routine.yogurtMeal.id, "No queue advancement inside the section")
    }

    @Test("AT-09: Add food never advances, even with auto-progression on")
    func addFoodNoProgression() async throws {
        let (model, routine, _) = try await seeded()
        try await model.setAutoProgression(true)
        let items = [DraftItem(food: Fixtures.foodB, quantity: 100, unit: .gram)]
        let entry = try await model.logAdditional(
            name: "Food B", items: items, mealTemplateID: nil, destination: model.currentDestination,
            date: model.viewedDate)
        #expect(entry.path == .additional)
        #expect(entry.sectionID == routine.breakfast.id)
        #expect(model.currentDestination.section?.id == routine.breakfast.id)
    }

    @Test("AT-10 / AT-30: several meals and repeats are independent entries")
    func independentEntries() async throws {
        let (model, routine, _) = try await seeded()
        await model.logSelectedMeal()
        model.selectMeal(id: routine.shakeMeal.id)
        await model.logSelectedMeal()
        await model.logSelectedMeal()
        #expect(model.currentEntries.count == 3)
        #expect(model.currentEntries.filter { $0.mealTemplateID == routine.shakeMeal.id }.count == 2)
        #expect(model.previousLogOfSelectedMeal != nil)
        let shake = try #require(model.currentEntries.first { $0.mealTemplateID == routine.shakeMeal.id })
        let oatsEntry = try #require(model.currentEntries.first { $0.mealTemplateID == routine.oatsMeal.id })
        let single = NutritionCalculator.summarize(shake)[.energy].known
        let day = model.dayNutrition[.energy].known
        let oats = NutritionCalculator.summarize(oatsEntry)[.energy].known
        #expect(day.isClose(to: oats + 2 * single))
    }

    @Test("AT-11: today's quantity change leaves the saved meal alone")
    func draftQuantity() async throws {
        let (model, routine, store) = try await seeded()
        let oatsItem = try #require(model.draftItems.first { $0.food.id == Fixtures.oats.id })
        model.setDraftQuantity(80, for: oatsItem.id)
        #expect(model.isDraftAdjusted)
        await model.logSelectedMeal()

        let logged = try #require(model.entries.first?.foods.first { $0.foodID == Fixtures.oats.id })
        #expect(logged.quantity == 80)
        #expect(logged.templateQuantity == 60)
        #expect(model.entries[0].isAdjusted)
        let saved = try await store.loadConfiguration().meals.first { $0.id == routine.oatsMeal.id }
        #expect(saved?.items.first { $0.foodID == Fixtures.oats.id }?.defaultQuantity == 60)
        #expect(model.draftItems.first { $0.food.id == Fixtures.oats.id }?.quantity == 60, "D-01: draft resets")
        #expect(!model.isDraftAdjusted)
    }

    @Test("Zero-quantity draft items are omitted from the entry but kept in the template")
    func zeroQuantityOmitted() async throws {
        let (model, routine, _) = try await seeded()
        let milk = try #require(model.draftItems.first { $0.food.id == Fixtures.milk.id })
        model.setDraftQuantity(0, for: milk.id)
        await model.logSelectedMeal()
        #expect(model.entries[0].foods.map(\.foodID) == [Fixtures.oats.id])
        #expect(model.meal(id: routine.oatsMeal.id)?.items.count == 2)
    }

    @Test("A draft with every quantity at zero is not logged")
    func allZeroNotLogged() async throws {
        let (model, _, _) = try await seeded()
        for item in model.draftItems { model.setDraftQuantity(0, for: item.id) }
        #expect(!(await model.logSelectedMeal()))
        #expect(model.entries.isEmpty)
        #expect(model.errorMessage != nil)
    }

    @Test("D-06: edits stay with their own meal while browsing")
    func draftsDoNotLeak() async throws {
        let (model, routine, _) = try await seeded()
        model.setDraftQuantity(90, for: model.draftItems[0].id)
        model.selectMeal(id: routine.yogurtMeal.id)
        #expect(!model.isDraftAdjusted)
        #expect(model.hasUnsavedDraftEdits)
        model.selectMeal(id: routine.oatsMeal.id)
        #expect(model.draftItems[0].quantity == 90)
    }

    @Test("AT-12: editing a logged entry changes only that entry and the totals")
    func editEntry() async throws {
        let (model, routine, store) = try await seeded()
        await model.logSelectedMeal()
        await model.logSelectedMeal()
        let before = model.dayNutrition[.energy].known
        var edited = model.entries[0]
        edited.foods[0].quantity = 120
        try await model.updateEntry(edited)

        #expect(model.entries[0].foods[0].quantity == 120)
        #expect(model.entries[1].foods[0].quantity == 60)
        #expect(model.dayNutrition[.energy].known.isClose(to: before + 3.79 * 60))
        #expect(model.meal(id: routine.oatsMeal.id)?.items[0].defaultQuantity == 60)
        #expect(try await store.allEntries().first { $0.id == edited.id }?.foods[0].quantity == 120)
    }

    @Test("AT-13 / AT-29: editing or removing a template keeps history intact")
    func templateChangesKeepHistory() async throws {
        let (model, routine, _) = try await seeded()
        await model.logSelectedMeal()
        let snapshot = model.entries[0]
        let energyBefore = model.dayNutrition[.energy].known

        var meal = routine.oatsMeal
        meal.name = "Renamed"
        meal.items[0].defaultQuantity = 10
        try await model.saveMeal(meal, foods: [])
        try await model.archiveMeal(id: meal.id)

        #expect(model.entries[0] == snapshot)
        #expect(model.entries[0].name == "Oats + milk")
        #expect(model.dayNutrition[.energy].known == energyBefore)
        #expect(!model.currentMeals.contains { $0.id == meal.id }, "MEAL-05: removed from selection")
        #expect(!model.activeSections.contains { $0.mealIDs.contains(meal.id) })
    }

    @Test("AT-14: removing a section keeps its entries reachable and labelled")
    func removeSection() async throws {
        let (model, routine, store) = try await seeded()
        await model.logSelectedMeal()
        try await model.removeSection(id: routine.breakfast.id)

        #expect(!model.activeSections.contains { $0.id == routine.breakfast.id })
        #expect(model.unsectionedEntries.count == 1)
        #expect(model.destinations.last?.isUnsectioned == true)
        #expect(model.destinationName(for: model.entries[0]) == "Breakfast (removed)")
        #expect(model.entries[0].sectionID == routine.breakfast.id, "Not silently moved")
        #expect(try await store.allEntries().count == 1)
    }

    @Test("AT-15 / D-14: delete then undo subtracts and restores exactly")
    func deleteUndo() async throws {
        let (model, _, _) = try await seeded()
        await model.logSelectedMeal()
        let entry = model.entries[0]
        let total = model.dayNutrition[.energy].known
        await model.deleteEntry(entry)
        #expect(model.dayNutrition.isEmpty)
        let toast = try #require(model.toast)
        await model.undo(toast)
        #expect(model.entries == [entry])
        #expect(model.dayNutrition[.energy].known == total)
    }

    @Test("Undoing a log removes only that entry and restores section and draft")
    func undoLog() async throws {
        let (model, routine, _) = try await seeded()
        try await model.setAutoProgression(true)
        model.setDraftQuantity(75, for: model.draftItems[0].id)
        await model.logSelectedMeal()
        #expect(model.currentDestination.section?.id == routine.lunch.id)
        await model.undo(try #require(model.toast))
        #expect(model.entries.isEmpty)
        #expect(model.currentDestination.section?.id == routine.breakfast.id)
        #expect(model.draftItems[0].quantity == 75)
        #expect(model.meal(id: routine.oatsMeal.id) == routine.oatsMeal)
    }

    @Test("AT-16: repeated activation while saving produces one entry")
    func duplicateProtection() async throws {
        let store = ControllableStore(inner: try SQLitePersonalStore(url: nil))
        try await Scenario.seedRoutine(into: store)
        let model = await Scenario.model(store: store, clock: clock)
        await store.setDelay(50_000_000)

        async let first = model.logSelectedMeal()
        async let second = model.logSelectedMeal()
        let results = await [first, second]
        #expect(results.filter { $0 }.count == 1)
        #expect(model.entries.count == 1)

        #expect(await model.logSelectedMeal(), "An intentional later log is allowed")
        #expect(model.entries.count == 2)
    }

    @Test("AT-19: a new day has no entries and resets to the first section and meal")
    func newDay() async throws {
        let (model, routine, store) = try await seeded()
        model.selectDestination(id: SectionKey.key(for: routine.lunch.id))
        model.selectMeal(id: routine.lunchMeal.id)
        await model.logSelectedMeal()
        model.selectDestination(id: SectionKey.key(for: routine.breakfast.id))
        model.selectMeal(id: routine.shakeMeal.id)
        try await Task.sleep(nanoseconds: 50_000_000)

        let sameDay = await Scenario.model(store: store, clock: clock)
        #expect(sameDay.currentDestination.section?.id == routine.breakfast.id, "D-04: restore last section")
        #expect(sameDay.selectedMeal?.id == routine.shakeMeal.id, "D-03: restore last meal")

        clock.advance(seconds: 86_400)
        await model.refreshForCurrentDate(isIdle: true)
        #expect(model.entries.isEmpty)
        #expect(model.currentDestination.section?.id == routine.breakfast.id)
        #expect(model.selectedMeal?.id == routine.oatsMeal.id)

        let nextDay = await Scenario.model(store: store, clock: clock)
        #expect(nextDay.entries.isEmpty)
        #expect(nextDay.selectedMeal?.id == routine.oatsMeal.id)
    }

    @Test("D-13: unsaved edits at midnight keep the draft's original day")
    func midnightWithDraft() async throws {
        let (model, _, _) = try await seeded()
        let originalDay = model.viewedDate
        model.setDraftQuantity(70, for: model.draftItems[0].id)
        clock.advance(seconds: 86_400)
        await model.refreshForCurrentDate(isIdle: true)
        #expect(model.viewedDate == originalDay)
        await model.logSelectedMeal()
        #expect(model.entries[0].logDate == originalDay)
    }

    @Test("AT-20 / AT-21: manual browsing wraps; auto-progression stops at the end")
    func wrapAndStop() async throws {
        let (model, routine, _) = try await seeded()
        model.browseDestinations(by: -1)
        #expect(model.currentDestination.section?.id == routine.dinner.id)
        model.browseDestinations(by: 1)
        #expect(model.currentDestination.section?.id == routine.breakfast.id)

        try await model.setAutoProgression(true)
        model.selectDestination(id: SectionKey.key(for: routine.dinner.id))
        await model.logSelectedMeal()
        #expect(model.currentDestination.section?.id == routine.dinner.id)
        #expect(model.toast?.message.contains("last section") == true)
    }

    @Test("AT-22: logging, editing and deleting work with no catalog or network")
    func offline() async throws {
        let (model, _, _) = try await seeded()
        #expect(model.catalog == nil)
        await model.logSelectedMeal()
        var entry = model.entries[0]
        entry.foods[1].quantity = 100
        try await model.updateEntry(entry)
        await model.deleteEntry(model.entries[0])
        #expect(model.entries.isEmpty)
        let search = await model.searchFoods("oats")
        #expect(search.catalogError != nil, "Catalog failure is reported, not shown as no results")
    }

    @Test("AT-33: a one-off composition creates no saved meal unless asked")
    func oneOff() async throws {
        let (model, routine, store) = try await seeded()
        let items = [
            DraftItem(food: Fixtures.foodA, quantity: 50, unit: .gram),
            DraftItem(food: Fixtures.foodB, quantity: 100, unit: .gram),
        ]
        let entry = try await model.logAdditional(
            name: "Snack plate", items: items, mealTemplateID: nil, destination: model.currentDestination,
            date: model.viewedDate)
        #expect(entry.isOneOff)
        #expect(try await store.loadConfiguration().meals.count == 4)
        #expect(model.activeSections.first { $0.id == routine.breakfast.id }?.mealIDs.count == 3)

        let saved = try await model.logAdditional(
            name: "Snack plate", items: items, mealTemplateID: nil, destination: model.currentDestination,
            date: model.viewedDate, saveAsMealNamed: "Snack plate")
        #expect(try await store.loadConfiguration().meals.count == 5)
        #expect(saved.mealTemplateID != nil)
        #expect(model.activeSections.first { $0.id == routine.breakfast.id }?.mealIDs.count == 3)
    }

    @Test("AT-36: a failed save preserves the draft and shows no success")
    func failedSave() async throws {
        let store = ControllableStore(inner: try SQLitePersonalStore(url: nil))
        let routine = try await Scenario.seedRoutine(into: store)
        let model = await Scenario.model(store: store, clock: clock)
        try await model.setAutoProgression(true)
        model.setDraftQuantity(85, for: model.draftItems[0].id)
        await store.setFailApplies(true)

        #expect(!(await model.logSelectedMeal()))
        #expect(model.entries.isEmpty)
        #expect(model.dayNutrition.isEmpty)
        #expect(model.toast == nil)
        #expect(model.errorMessage != nil)
        #expect(model.draftItems[0].quantity == 85)
        #expect(model.currentDestination.section?.id == routine.breakfast.id)
    }

    @Test("AT-37: hiding a summary nutrient keeps its data")
    func hideNutrient() async throws {
        let (model, _, _) = try await seeded()
        await model.logSelectedMeal()
        let protein = model.dayNutrition[.protein]
        try await model.setSummaryNutrients([.fiber, .fat])
        #expect(model.preferences.summaryNutrients == [.fiber, .fat])
        #expect(model.dayNutrition[.protein] == protein)
    }

    @Test("D-07: removing every meal from a section falls back to the library")
    func emptySelectionFallback() async throws {
        let (model, routine, _) = try await seeded()
        model.selectDestination(id: SectionKey.key(for: routine.lunch.id))
        try await model.setMeals([], forSection: routine.lunch.id)
        #expect(model.currentUsesAllMeals)
        #expect(model.currentMeals.count == 4)
    }

    @Test("D-09: moving an entry keeps its nutrition and time")
    func moveEntry() async throws {
        let (model, routine, _) = try await seeded()
        await model.logSelectedMeal()
        let entry = model.entries[0]
        let lunch = try #require(model.destinations.first { $0.section?.id == routine.lunch.id })
        try await model.moveEntry(entry, to: lunch)
        #expect(model.entries[0].sectionID == routine.lunch.id)
        #expect(model.entries[0].recordedAt == entry.recordedAt)
        #expect(model.entries[0].foods == entry.foods)
        #expect(model.entries(in: lunch).count == 1)
    }

    @Test("D-10: entries within a section are ordered by recorded time")
    func entryOrder() async throws {
        let (model, routine, _) = try await seeded()
        await model.logSelectedMeal()
        clock.advance(seconds: 60)
        model.selectMeal(id: routine.shakeMeal.id)
        await model.logSelectedMeal()
        var first = model.entries[0]
        first.foods[0].quantity = 10
        try await model.updateEntry(first)
        #expect(model.currentEntries.map(\.name) == ["Oats + milk", "Protein shake"])
    }

    @Test("D-11: past days can be inspected and corrected without moving today's navigation")
    func pastDays() async throws {
        let (model, routine, _) = try await seeded()
        model.selectDestination(id: SectionKey.key(for: routine.snack.id))
        let yesterday = model.today.adding(days: -1)
        await model.changeDate(to: yesterday)
        #expect(!model.isViewingToday)
        #expect(model.currentDestination.section?.id == routine.breakfast.id)
        try await model.setAutoProgression(true)
        await model.logSelectedMeal()
        #expect(model.entries[0].logDate == yesterday)
        await model.changeDate(to: model.today)
        #expect(model.entries.isEmpty)
        #expect(model.currentDestination.section?.id == routine.snack.id)
    }

    @Test("Targets set today don't rewrite earlier days; first targets apply everywhere")
    func targetHistory() async throws {
        let (model, _, _) = try await seeded()
        try await model.setTarget(.energy, amount: 2200, kind: .target)
        clock.advance(seconds: 86_400)
        await model.refreshForCurrentDate(isIdle: true)
        try await model.setTarget(.energy, amount: 1800, kind: .target)
        #expect(model.effectiveTargets[.energy]?.amount == 1800)
        await model.changeDate(to: model.today.adding(days: -1))
        #expect(model.effectiveTargets[.energy]?.amount == 2200)
        await model.changeDate(to: model.today.adding(days: -30))
        #expect(model.effectiveTargets[.energy]?.amount == 2200)
    }

    @Test("Disabling a reference and restoring it")
    func referenceToggle() async throws {
        let (model, _, _) = try await seeded()
        #expect(model.effectiveTargets[.magnesium]?.isReference == true)
        try await model.disableTarget(.magnesium)
        #expect(model.effectiveTargets[.magnesium] == nil)
        try await model.useReferenceValue(.magnesium)
        #expect(model.effectiveTargets[.magnesium]?.amount == 420)
    }

    @Test("Import replaces data atomically and writes a recovery export")
    func importReplaces() async throws {
        let (model, _, _) = try await seeded()
        await model.logSelectedMeal()
        let exported = try await model.exportData()
        let otherModel = await Scenario.model(store: try SQLitePersonalStore(url: nil), clock: clock)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("recovery-\(UUID().uuidString)")
        let recovery = try await otherModel.replaceAllData(with: try ExportService.decode(exported), recoveryDirectory: directory)
        #expect(FileManager.default.fileExists(atPath: recovery.path))
        #expect(otherModel.entries.count == 1)
        #expect(otherModel.activeSections.count == 4)
    }

    @Test("A failed import leaves the existing store usable and unchanged")
    func failedImport() async throws {
        let store = ControllableStore(inner: try SQLitePersonalStore(url: nil))
        try await Scenario.seedRoutine(into: store)
        let model = await Scenario.model(store: store, clock: clock)
        await model.logSelectedMeal()
        await store.setFailApplies(true)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("recovery-\(UUID().uuidString)")
        await #expect(throws: (any Error).self) {
            try await model.replaceAllData(with: PersonalDataSet(), recoveryDirectory: directory)
        }
        #expect(try await store.allEntries().count == 1)
    }
}
