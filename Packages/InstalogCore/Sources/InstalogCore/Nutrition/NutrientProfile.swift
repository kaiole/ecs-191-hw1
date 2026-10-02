import Foundation

/// Sparse nutrient amounts in canonical units. An absent nutrient is unknown, never zero.
public struct NutrientProfile: Hashable, Sendable, Codable {
    public private(set) var values: [NutrientID: Double]

    public init(_ values: [NutrientID: Double] = [:]) {
        self.values = values
    }

    public subscript(id: NutrientID) -> Double? {
        get { values[id] }
        set { values[id] = newValue }
    }

    public var isEmpty: Bool { values.isEmpty }
    public var nutrientIDs: Dictionary<NutrientID, Double>.Keys { values.keys }

    public init(from decoder: Decoder) throws {
        values = try decoder.singleValueContainer().decode([NutrientID: Double].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(values)
    }

    /// Every value must be finite and nonnegative.
    public var isValid: Bool {
        values.values.allSatisfy { $0.isFinite && $0 >= 0 }
    }

    func scaled(by factor: Double) -> NutrientProfile {
        NutrientProfile(values.mapValues { $0 * factor })
    }
}
