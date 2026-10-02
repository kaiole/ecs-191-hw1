import Foundation

public enum MealSelection {
    /// Meals offered in a section: its configured meals in order, or every active meal in stable
    /// library order when nothing valid is configured (or there are no sections).
    public static func meals(for section: RoutineSection?, activeMeals: [MealTemplate]) -> [MealTemplate] {
        let library = activeMeals.filter { !$0.isArchived }.sorted(by: libraryOrder)
        guard let section else { return library }
        let byID = Dictionary(uniqueKeysWithValues: library.map { ($0.id, $0) })
        let configured = section.mealIDs.compactMap { byID[$0] }
        return configured.isEmpty ? library : configured
    }

    public static func libraryOrder(_ lhs: MealTemplate, _ rhs: MealTemplate) -> Bool {
        (lhs.sortOrder, lhs.createdAt) < (rhs.sortOrder, rhs.createdAt)
    }

    /// True when the section falls back to the whole library.
    public static func usesFallback(_ section: RoutineSection?, activeMeals: [MealTemplate]) -> Bool {
        guard let section else { return true }
        let active = Set(activeMeals.filter { !$0.isArchived }.map(\.id))
        return !section.mealIDs.contains { active.contains($0) }
    }
}

public enum ProgressionPolicy {
    /// Index of the section to show after a successful log.
    ///
    /// Only normal meal logging with auto-progression enabled moves forward, and it stops at the
    /// final section instead of wrapping.
    public static func sectionAfterLogging(
        currentIndex: Int?, sectionCount: Int, path: EntryPath, autoProgression: Bool
    ) -> Int? {
        guard let currentIndex else { return nil }
        guard autoProgression, path == .normal, sectionCount > 1 else { return currentIndex }
        return min(currentIndex + 1, sectionCount - 1)
    }

    /// Manual browsing wraps in both directions.
    public static func browse(from index: Int, by step: Int, sectionCount: Int) -> Int {
        guard sectionCount > 0 else { return 0 }
        return ((index + step) % sectionCount + sectionCount) % sectionCount
    }
}
