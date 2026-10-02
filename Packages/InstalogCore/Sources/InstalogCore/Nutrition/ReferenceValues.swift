import Foundation

public enum TargetKind: String, Codable, Sendable, CaseIterable {
    /// A general reference amount, not a personal requirement.
    case reference
    /// A personal intake goal.
    case target
    /// A maximum to stay under.
    case limit
}

public struct ReferenceValue: Hashable, Sendable {
    public let nutrientID: NutrientID
    public let amount: Double
    public let unit: NutrientUnit
    public let form: String?
    public let kind: TargetKind
    public let note: String?
}

/// FDA Daily Values for adults and children 4 years and older.
///
/// Source: 21 CFR 101.9(c)(8)(iv) and (c)(9), as revised by the 2016 Nutrition Facts label final
/// rule. https://www.fda.gov/food/nutrition-facts-label/daily-value-nutrition-and-supplement-facts-labels
///
/// These are population reference values for labeling, not individual requirements. Calorie,
/// protein, carbohydrate and fat DVs are deliberately left out: those goals are user-entered.
public enum FDADailyValues {
    public static let sourceName = "FDA Daily Value"
    public static let version = "2016"

    public static let table: [ReferenceValue] = [
        dv(.fiber, 28, .gram, note: "Based on a 2,000 kcal diet"),
        dv(.saturatedFat, 20, .gram, kind: .limit, note: "Based on a 2,000 kcal diet"),
        dv(.addedSugars, 50, .gram, kind: .limit, note: "Based on a 2,000 kcal diet"),
        dv(.cholesterol, 300, .milligram, kind: .limit),
        dv(.sodium, 2300, .milligram, kind: .limit),
        dv(.vitaminA, 900, .microgram, form: "RAE"),
        dv(.vitaminC, 90, .milligram),
        dv(.vitaminD, 20, .microgram),
        dv(.vitaminE, 15, .milligram, form: "alpha-tocopherol"),
        dv(.vitaminK, 120, .microgram),
        dv(.thiamin, 1.2, .milligram),
        dv(.riboflavin, 1.3, .milligram),
        dv(.niacin, 16, .milligram, form: "NE", note: "Niacin equivalents; not comparable with preformed niacin data"),
        dv(.vitaminB6, 1.7, .milligram),
        dv(.folate, 400, .microgram, form: "DFE"),
        dv(.vitaminB12, 2.4, .microgram),
        dv(.biotin, 30, .microgram),
        dv(.pantothenicAcid, 5, .milligram),
        dv(.choline, 550, .milligram),
        dv(.calcium, 1300, .milligram),
        dv(.iron, 18, .milligram),
        dv(.phosphorus, 1250, .milligram),
        dv(.iodine, 150, .microgram),
        dv(.magnesium, 420, .milligram),
        dv(.zinc, 11, .milligram),
        dv(.selenium, 55, .microgram),
        dv(.copper, 0.9, .milligram),
        dv(.manganese, 2.3, .milligram),
        dv(.potassium, 4700, .milligram),
    ]

    public static func value(for id: NutrientID) -> ReferenceValue? {
        table.first { $0.nutrientID == id }
    }

    private static func dv(
        _ id: NutrientID, _ amount: Double, _ unit: NutrientUnit, form: String? = nil, kind: TargetKind = .reference,
        note: String? = nil
    ) -> ReferenceValue {
        ReferenceValue(nutrientID: id, amount: amount, unit: unit, form: form, kind: kind, note: note)
    }
}
