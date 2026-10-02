import Foundation

public struct NutrientID: RawRepresentable, Hashable, Codable, Sendable, Comparable, CodingKeyRepresentable,
    ExpressibleByStringLiteral, CustomStringConvertible
{
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var codingKey: CodingKey { AnyCodingKey(stringValue: rawValue) }

    public init?<T: CodingKey>(codingKey: T) { rawValue = codingKey.stringValue }

    public static func < (lhs: NutrientID, rhs: NutrientID) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String { rawValue }
}

struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

public extension NutrientID {
    static let energy: NutrientID = "energy"
    static let protein: NutrientID = "protein"
    static let carbohydrate: NutrientID = "carbohydrate"
    static let fat: NutrientID = "fat"
    static let fiber: NutrientID = "fiber"
    static let sugars: NutrientID = "sugars"
    static let addedSugars: NutrientID = "addedSugars"
    static let saturatedFat: NutrientID = "saturatedFat"
    static let transFat: NutrientID = "transFat"
    static let monounsaturatedFat: NutrientID = "monounsaturatedFat"
    static let polyunsaturatedFat: NutrientID = "polyunsaturatedFat"
    static let cholesterol: NutrientID = "cholesterol"
    static let water: NutrientID = "water"
    static let alcohol: NutrientID = "alcohol"
    static let caffeine: NutrientID = "caffeine"

    static let vitaminA: NutrientID = "vitaminA"
    static let vitaminAIU: NutrientID = "vitaminAIU"
    static let vitaminC: NutrientID = "vitaminC"
    static let vitaminD: NutrientID = "vitaminD"
    static let vitaminE: NutrientID = "vitaminE"
    static let vitaminK: NutrientID = "vitaminK"
    static let thiamin: NutrientID = "thiamin"
    static let riboflavin: NutrientID = "riboflavin"
    static let niacin: NutrientID = "niacin"
    static let vitaminB6: NutrientID = "vitaminB6"
    static let folate: NutrientID = "folate"
    static let folateTotal: NutrientID = "folateTotal"
    static let folicAcid: NutrientID = "folicAcid"
    static let vitaminB12: NutrientID = "vitaminB12"
    static let pantothenicAcid: NutrientID = "pantothenicAcid"
    static let biotin: NutrientID = "biotin"
    static let choline: NutrientID = "choline"

    static let calcium: NutrientID = "calcium"
    static let iron: NutrientID = "iron"
    static let magnesium: NutrientID = "magnesium"
    static let phosphorus: NutrientID = "phosphorus"
    static let potassium: NutrientID = "potassium"
    static let sodium: NutrientID = "sodium"
    static let zinc: NutrientID = "zinc"
    static let copper: NutrientID = "copper"
    static let manganese: NutrientID = "manganese"
    static let selenium: NutrientID = "selenium"
    static let iodine: NutrientID = "iodine"
    static let fluoride: NutrientID = "fluoride"
}

public enum NutrientUnit: String, Codable, Sendable, CaseIterable {
    case kilocalorie = "kcal"
    case gram = "g"
    case milligram = "mg"
    case microgram = "µg"
    case internationalUnit = "IU"

    var gramsPerUnit: Double? {
        switch self {
        case .gram: 1
        case .milligram: 0.001
        case .microgram: 0.000_001
        case .kilocalorie, .internationalUnit: nil
        }
    }

    /// Converts between identical units or straightforward mass units. Anything else
    /// (IU to mass, energy to mass) needs a nutrient-specific documented conversion and is rejected.
    public func convert(_ value: Double, to target: NutrientUnit) -> Double? {
        if self == target { return value }
        guard let from = gramsPerUnit, let to = target.gramsPerUnit else { return nil }
        return value * from / to
    }
}

public enum NutrientGroup: String, Codable, Sendable, CaseIterable {
    case energyAndMacros
    case composition
    case vitamins
    case minerals
    case carotenoids
    case fattyAcids
    case aminoAcids

    public var title: String {
        switch self {
        case .energyAndMacros: "Energy & macros"
        case .composition: "Composition"
        case .vitamins: "Vitamins"
        case .minerals: "Minerals"
        case .carotenoids: "Carotenoids"
        case .fattyAcids: "Fatty acids"
        case .aminoAcids: "Amino acids"
        }
    }
}

/// How one USDA FoodData Central nutrient maps onto a canonical nutrient.
public struct USDAMapping: Hashable, Sendable {
    public let nutrientNumber: Int
    /// Unit name exactly as USDA publishes it (`KCAL`, `kJ`, `G`, `MG`, `UG`, `IU`).
    public let sourceUnit: String
    /// Multiplier from the source amount to the canonical unit and form.
    public let factor: Double
    public let note: String?

    public init(_ nutrientNumber: Int, _ sourceUnit: String, factor: Double = 1, note: String? = nil) {
        self.nutrientNumber = nutrientNumber
        self.sourceUnit = sourceUnit
        self.factor = factor
        self.note = note
    }
}

public struct NutrientDefinition: Hashable, Sendable, Identifiable {
    public let id: NutrientID
    public let name: String
    public let shortName: String
    public let group: NutrientGroup
    public let unit: NutrientUnit
    /// Chemical or equivalent form, when it matters for comparisons (e.g. "RAE", "DFE").
    public let form: String?
    /// Source mappings in priority order. Only the first one present is used, so alternative
    /// expressions of the same nutrient (e.g. several energy fields) are never summed.
    public let usdaMappings: [USDAMapping]

    public init(
        id: NutrientID, name: String, shortName: String? = nil, group: NutrientGroup, unit: NutrientUnit,
        form: String? = nil, usda: [USDAMapping]
    ) {
        self.id = id
        self.name = name
        self.shortName = shortName ?? name
        self.group = group
        self.unit = unit
        self.form = form
        self.usdaMappings = usda
    }
}
