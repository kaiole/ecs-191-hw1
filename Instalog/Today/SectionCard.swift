import InstalogCore
import SwiftUI

/// The current section: its logged entries first, then the meal chooser and the selected meal.
struct SectionCard: View {
    @Bindable var model: DiaryModel
    @Binding var sheet: ActiveSheet?
    @State private var loggedExpanded = false
    @State private var revealedEntryID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 14) {
                    LoggedEntriesGroup(
                        model: model, entries: model.currentEntries, emptyText: emptyText,
                        isExpanded: $loggedExpanded, revealedEntryID: $revealedEntryID,
                        open: { sheet = .entry($0.id) })
                    if model.selectedMeal != nil {
                        MealChooser(model: model)
                        MealCard(model: model)
                    } else {
                        NoMealsCard(
                            destinationName: model.currentDestination.name,
                            canLoadDemo: model.catalog != nil && model.activeMeals.isEmpty,
                            createMeal: { sheet = .newMeal },
                            loadDemo: { Task { await loadDemo() } })
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 14)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(Palette.surface, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(Palette.border))
        .onChange(of: model.currentDestination.id) {
            loggedExpanded = false
            revealedEntryID = nil
        }
    }

    private var emptyText: String {
        let destination = model.currentDestination
        if !model.hasSections { return "Nothing logged today yet." }
        return destination.isUnsectioned ? "No unsectioned entries." : "Nothing logged in \(destination.name) yet."
    }

    private func loadDemo() async {
        do {
            try await model.loadDemoRoutine()
        } catch {
            model.errorMessage = "Couldn’t load the demo routine. \(error.localizedDescription)"
        }
    }

    private var header: some View {
        let destinations = model.destinations
        let index = model.currentDestinationIndex
        let destination = model.currentDestination
        let canBrowse = destinations.count > 1

        return HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Caption(positionText(destination: destination, index: index, count: destinations.count))
                    if model.hasSections {
                        HStack(spacing: 3) {
                            ForEach(destinations.indices, id: \.self) { i in
                                Capsule()
                                    .fill(i == index ? Palette.accent : Palette.outline)
                                    .frame(width: i == index ? 16 : 6, height: 4)
                            }
                        }
                        .accessibilityHidden(true)
                    }
                }
                .frame(height: 16)
                if model.hasSections {
                    Button { sheet = .sections } label: {
                        HStack(spacing: 6) {
                            Text(destination.isUnsectioned ? "Unsectioned" : destination.name)
                                .font(Typeface.sans(28, .semibold, relativeTo: .largeTitle))
                                .tracking(-0.5)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Palette.secondary)
                        }
                        .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(destination.name), section \(index + 1) of \(destinations.count)")
                    .accessibilityHint("Shows all sections")
                } else {
                    Text("Daily log")
                        .font(Typeface.sans(28, .semibold, relativeTo: .largeTitle))
                        .tracking(-0.5)
                        .frame(minHeight: 44)
                        .accessibilityAddTraits(.isHeader)
                }
            }
            Spacer(minLength: 0)
            if canBrowse {
                HStack(spacing: 6) {
                    Button { withAnimation(.snappy) { model.browseDestinations(by: -1) } } label: {
                        Image(systemName: "chevron.up").font(.system(size: 17, weight: .semibold))
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Previous section: \(destinations[(index - 1 + destinations.count) % destinations.count].name)")
                    Button { withAnimation(.snappy) { model.browseDestinations(by: 1) } } label: {
                        Image(systemName: "chevron.down").font(.system(size: 17, weight: .semibold))
                    }
                    .buttonStyle(IconButtonStyle())
                    .accessibilityLabel("Next section: \(destinations[(index + 1) % destinations.count].name)")
                }
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                guard canBrowse, abs(value.translation.height) > 36,
                    abs(value.translation.height) > abs(value.translation.width)
                else { return }
                withAnimation(.snappy) { model.browseDestinations(by: value.translation.height < 0 ? 1 : -1) }
            }
        )
    }

    private func positionText(destination: Destination, index: Int, count: Int) -> String {
        if !model.hasSections { return "No sections" }
        if destination.isUnsectioned { return "Other entries" }
        return "Section \(index + 1) of \(count)"
    }
}

struct MealChooser: View {
    @Bindable var model: DiaryModel

    var body: some View {
        let meals = model.currentMeals
        let selected = model.selectedMeal?.id
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Caption(label)
                Spacer()
                if let index = model.selectedMealIndex {
                    Text("\(index + 1) of \(meals.count)")
                        .font(Typeface.mono(11, relativeTo: .caption2))
                        .foregroundStyle(Palette.tertiary)
                }
            }
            .padding(.horizontal, 4)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(meals) { meal in
                            Button(meal.name) { model.selectMeal(id: meal.id) }
                                .buttonStyle(ChipButtonStyle(isSelected: meal.id == selected))
                                .accessibilityAddTraits(meal.id == selected ? .isSelected : [])
                                .id(meal.id)
                        }
                    }
                    .padding(.horizontal, 10)
                }
                .padding(.horizontal, -10)
                .onChange(of: selected) { _, id in
                    withAnimation { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }

    private var label: String {
        let destination = model.currentDestination
        if destination.isUnsectioned || !model.hasSections { return "All saved meals" }
        return model.currentUsesAllMeals ? "All saved meals · none assigned" : "Usual for \(destination.name)"
    }
}

struct NoMealsCard: View {
    let destinationName: String
    let canLoadDemo: Bool
    let createMeal: () -> Void
    let loadDemo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caption("No saved meals yet")
            Text("Save the meals you eat most, and they’ll be waiting here, ready to log.")
                .font(Typeface.sans(20, .semibold, relativeTo: .title3))
            Text("Until then, Add food logs anything into \(destinationName == "Daily log" ? "today" : destinationName). You can save a meal from any entry later.")
                .font(Typeface.sans(14, relativeTo: .subheadline))
                .foregroundStyle(Palette.secondary)
            HStack(spacing: 8) {
                Button("Create a saved meal", action: createMeal)
                    .font(Typeface.sans(14, .semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: 44)
                    .background(Color(hex: 0x262C31), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                if canLoadDemo {
                    Button("Load demo routine", action: loadDemo)
                        .font(Typeface.sans(14, .semibold))
                        .foregroundStyle(Palette.accent)
                        .padding(.horizontal, 10)
                        .frame(minHeight: 44)
                }
            }
            .padding(.top, 6)
        }
        .foregroundStyle(Palette.text)
        .padding(.horizontal, 18)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardBackground()
    }
}
