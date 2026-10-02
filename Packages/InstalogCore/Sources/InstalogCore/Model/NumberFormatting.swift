import Foundation

/// Presentation rounding. Calculations never round; only these display helpers do.
public enum NumberFormatting {
    public static func quantity(_ value: Double) -> String {
        if value.rounded() == value { return String(Int(value)) }
        let rounded = (value * 100).rounded() / 100
        return rounded.formatted(.number.precision(.fractionLength(0...2)))
    }

    public static func energy(_ value: Double) -> String {
        Int(value.rounded()).formatted(.number.grouping(.automatic))
    }

    /// Nutrient amounts: whole numbers at 10 and above, otherwise up to two significant decimals.
    public static func nutrient(_ value: Double) -> String {
        if value >= 10 { return Int(value.rounded()).formatted(.number.grouping(.automatic)) }
        if value >= 1 { return value.formatted(.number.precision(.fractionLength(0...1))) }
        if value == 0 { return "0" }
        return value.formatted(.number.precision(.significantDigits(1...2)))
    }

    public static func nutrient(_ value: Double, unit: NutrientUnit) -> String {
        unit == .kilocalorie ? "\(energy(value)) kcal" : "\(nutrient(value)) \(unit.rawValue)"
    }
}
