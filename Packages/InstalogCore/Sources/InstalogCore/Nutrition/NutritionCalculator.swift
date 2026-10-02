import Foundation

public enum NutrientCompleteness: String, Sendable, Equatable {
    /// Every contributing food supplies a value, including explicit zeros.
    case complete
    /// Some contributing foods supply values and others do not.
    case partial
    /// No contributing food supplies the nutrient.
    case unknown
    /// Nothing has been consumed in this context.
    case empty
}

/// A nutrient total across some set of foods, with how much of it is actually known.
public struct NutrientTotal: Equatable, Sendable {
    /// Sum of the values that were supplied. Unrounded.
    public var known: Double
    public var reportingFoods: Int
    public var totalFoods: Int

    public init(known: Double = 0, reportingFoods: Int = 0, totalFoods: Int = 0) {
        self.known = known
        self.reportingFoods = reportingFoods
        self.totalFoods = totalFoods
    }

    public var missingFoods: Int { totalFoods - reportingFoods }

    public var completeness: NutrientCompleteness {
        if totalFoods == 0 { return .empty }
        if reportingFoods == totalFoods { return .complete }
        if reportingFoods == 0 { return .unknown }
        return .partial
    }

    /// The amount to display, or nil when nothing is known.
    public var displayAmount: Double? {
        switch completeness {
        case .complete, .partial: known
        case .unknown, .empty: nil
        }
    }
}

/// Totals for a set of foods. Nutrients no food mentions are reported as unknown.
public struct NutritionSummary: Equatable, Sendable {
    public private(set) var foodCount: Int
    private var sums: [NutrientID: (known: Double, reporting: Int)]

    public init() {
        foodCount = 0
        sums = [:]
    }

    public static func == (lhs: NutritionSummary, rhs: NutritionSummary) -> Bool {
        lhs.foodCount == rhs.foodCount
            && lhs.sums.count == rhs.sums.count
            && lhs.sums.allSatisfy { key, value in
                rhs.sums[key].map { $0.known == value.known && $0.reporting == value.reporting } ?? false
            }
    }

    public subscript(id: NutrientID) -> NutrientTotal {
        let sum = sums[id]
        return NutrientTotal(known: sum?.known ?? 0, reportingFoods: sum?.reporting ?? 0, totalFoods: foodCount)
    }

    public var isEmpty: Bool { foodCount == 0 }

    /// Nutrients that at least one food reports.
    public var reportedNutrients: Set<NutrientID> { Set(sums.keys) }

    mutating func add(food nutrients: NutrientProfile) {
        foodCount += 1
        for (id, value) in nutrients.values {
            let current = sums[id] ?? (0, 0)
            sums[id] = (current.known + value, current.reporting + 1)
        }
    }

    public mutating func add(_ other: NutritionSummary) {
        foodCount += other.foodCount
        for (id, value) in other.sums {
            let current = sums[id] ?? (0, 0)
            sums[id] = (current.known + value.known, current.reporting + value.reporting)
        }
    }

    public static func + (lhs: NutritionSummary, rhs: NutritionSummary) -> NutritionSummary {
        var result = lhs
        result.add(rhs)
        return result
    }
}

/// Pure quantity conversion and nutrient aggregation. No rounding happens here.
public enum NutritionCalculator {
    public struct Item: Sendable {
        public var nutrition: FoodNutrition
        public var quantity: Double
        public var unit: MeasureUnit

        public init(nutrition: FoodNutrition, quantity: Double, unit: MeasureUnit) {
            self.nutrition = nutrition
            self.quantity = quantity
            self.unit = unit
        }
    }

    /// Sums items. Zero-quantity items are skipped, matching what logging records.
    public static func summarize(_ items: [Item]) throws -> NutritionSummary {
        var summary = NutritionSummary()
        for item in items where item.quantity > 0 {
            summary.add(food: try item.nutrition.nutrients(quantity: item.quantity, unit: item.unit))
        }
        return summary
    }

    public static func summarize(_ entry: LoggedEntry) -> NutritionSummary {
        (try? summarize(entry.foods.map(\.calculatorItem))) ?? NutritionSummary()
    }

    public static func summarize(entries: [LoggedEntry]) -> NutritionSummary {
        entries.reduce(into: NutritionSummary()) { $0.add(summarize($1)) }
    }
}
