import Foundation

public enum MealSelectionMode: String, Codable, Sendable {
    /// Offer every active saved meal.
    case all
    /// Offer the configured meals in order.
    case selected
}

/// An optional, user-named logging destination such as Breakfast. Never has a completed state.
public struct RoutineSection: Hashable, Sendable, Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var sortOrder: Int
    /// Ordered saved meals offered in this section. The first one is the new-day default.
    public var mealIDs: [UUID]
    public var createdAt: Date
    public var updatedAt: Date
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(), name: String, sortOrder: Int, mealIDs: [UUID] = [], createdAt: Date = Date(),
        updatedAt: Date? = nil, archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.sortOrder = sortOrder
        self.mealIDs = mealIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.archivedAt = archivedAt
    }

    public var mode: MealSelectionMode { mealIDs.isEmpty ? .all : .selected }
    public var isArchived: Bool { archivedAt != nil }
}
