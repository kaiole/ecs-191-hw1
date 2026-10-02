import Foundation

public struct MealTemplateItem: Hashable, Sendable, Codable, Identifiable {
    public var id: UUID
    public var foodID: UUID
    public var defaultQuantity: Double
    public var unit: MeasureUnit

    public init(id: UUID = UUID(), foodID: UUID, defaultQuantity: Double, unit: MeasureUnit) {
        self.id = id
        self.foodID = foodID
        self.defaultQuantity = defaultQuantity
        self.unit = unit
    }
}

/// A named collection of foods with default quantities. Editing it changes future defaults only;
/// logged entries keep their own snapshots.
public struct MealTemplate: Hashable, Sendable, Codable, Identifiable {
    public var id: UUID
    public var name: String
    /// Ordered ingredients. Order is independent of any section order.
    public var items: [MealTemplateItem]
    /// Stable library position; creation order unless the user reorders the library.
    public var sortOrder: Int
    public var createdAt: Date
    public var updatedAt: Date
    public var archivedAt: Date?

    public init(
        id: UUID = UUID(), name: String, items: [MealTemplateItem], sortOrder: Int, createdAt: Date = Date(),
        updatedAt: Date? = nil, archivedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.items = items
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.archivedAt = archivedAt
    }

    public var isArchived: Bool { archivedAt != nil }
}

public enum MealValidationError: Error, Equatable, Sendable {
    case blankName
    case noFoods
    case invalidQuantity
    case missingFood
    case unsupportedUnit
}

public extension MealTemplate {
    /// A saved meal needs a name and at least one food with a positive quantity in a supported unit.
    func validate(foods: [UUID: FoodDefinition]) throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw MealValidationError.blankName }
        if items.isEmpty { throw MealValidationError.noFoods }
        for item in items {
            guard item.defaultQuantity.isFinite, item.defaultQuantity > 0 else {
                throw MealValidationError.invalidQuantity
            }
            guard let food = foods[item.foodID] else { throw MealValidationError.missingFood }
            guard (try? food.nutrition.basisMultiple(quantity: 1, unit: item.unit)) != nil else {
                throw MealValidationError.unsupportedUnit
            }
        }
    }
}
