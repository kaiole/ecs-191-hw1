import Foundation

public struct AppPreferences: Hashable, Sendable, Codable {
    public static let maxSummaryNutrients = 3

    public var autoProgression: Bool
    public var summaryNutrients: [NutrientID]
    /// Show FDA reference values for nutrients without a personal target.
    public var showReferenceValues: Bool

    public init(
        autoProgression: Bool = false, summaryNutrients: [NutrientID] = [.protein, .carbohydrate, .fat],
        showReferenceValues: Bool = true
    ) {
        self.autoProgression = autoProgression
        self.summaryNutrients = summaryNutrients
        self.showReferenceValues = showReferenceValues
    }
}

/// Same-day navigation memory: which section was last viewed and which meal each section had
/// selected. Ignored on a new day.
public struct NavigationMemory: Hashable, Sendable, Codable {
    public var date: LogDate
    public var sectionID: UUID?
    /// Keyed by section ID string, or `SectionKey.unsectioned`.
    public var mealSelections: [String: UUID]

    public init(date: LogDate, sectionID: UUID? = nil, mealSelections: [String: UUID] = [:]) {
        self.date = date
        self.sectionID = sectionID
        self.mealSelections = mealSelections
    }
}

public enum SectionKey {
    public static let unsectioned = "unsectioned"

    public static func key(for sectionID: UUID?) -> String {
        sectionID?.uuidString ?? unsectioned
    }
}
