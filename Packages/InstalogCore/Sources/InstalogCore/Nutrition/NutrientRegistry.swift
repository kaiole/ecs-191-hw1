import Foundation

/// Canonical nutrient definitions and their USDA FoodData Central mappings.
///
/// USDA nutrient numbers and units come from the FDC `nutrient` table. When a food reports several
/// expressions of one nutrient, the first mapping present wins; values are never summed across
/// mappings.
public enum NutrientRegistry {
    public static let all: [NutrientDefinition] = [
        NutrientDefinition(
            id: .energy, name: "Energy", shortName: "Calories", group: .energyAndMacros, unit: .kilocalorie,
            usda: [
                USDAMapping(1008, "KCAL"),
                USDAMapping(2048, "KCAL", note: "Atwater specific factors"),
                USDAMapping(2047, "KCAL", note: "Atwater general factors"),
                USDAMapping(1062, "kJ", factor: 1 / 4.184, note: "1 kcal = 4.184 kJ"),
            ]),
        NutrientDefinition(
            id: .protein, name: "Protein", group: .energyAndMacros, unit: .gram, usda: [USDAMapping(1003, "G")]),
        NutrientDefinition(
            id: .carbohydrate, name: "Total carbohydrate", shortName: "Carbs", group: .energyAndMacros, unit: .gram,
            usda: [USDAMapping(1005, "G", note: "by difference"), USDAMapping(1050, "G", note: "by summation")]),
        NutrientDefinition(
            id: .fat, name: "Total fat", shortName: "Fat", group: .energyAndMacros, unit: .gram,
            usda: [USDAMapping(1004, "G"), USDAMapping(1085, "G", note: "NLEA")]),

        NutrientDefinition(
            id: .fiber, name: "Dietary fiber", shortName: "Fiber", group: .composition, unit: .gram,
            usda: [USDAMapping(1079, "G")]),
        NutrientDefinition(
            id: .sugars, name: "Total sugars", shortName: "Sugars", group: .composition, unit: .gram,
            usda: [USDAMapping(2000, "G"), USDAMapping(1063, "G", note: "NLEA")]),
        NutrientDefinition(
            id: .addedSugars, name: "Added sugars", group: .composition, unit: .gram, usda: [USDAMapping(1235, "G")]),
        NutrientDefinition(
            id: .saturatedFat, name: "Saturated fat", shortName: "Sat. fat", group: .composition, unit: .gram,
            usda: [USDAMapping(1258, "G")]),
        NutrientDefinition(
            id: .transFat, name: "Trans fat", group: .composition, unit: .gram, usda: [USDAMapping(1257, "G")]),
        NutrientDefinition(
            id: .monounsaturatedFat, name: "Monounsaturated fat", shortName: "Mono. fat", group: .composition,
            unit: .gram, usda: [USDAMapping(1292, "G")]),
        NutrientDefinition(
            id: .polyunsaturatedFat, name: "Polyunsaturated fat", shortName: "Poly. fat", group: .composition,
            unit: .gram, usda: [USDAMapping(1293, "G")]),
        NutrientDefinition(
            id: .cholesterol, name: "Cholesterol", group: .composition, unit: .milligram,
            usda: [USDAMapping(1253, "MG")]),
        NutrientDefinition(
            id: .water, name: "Water", group: .composition, unit: .gram, usda: [USDAMapping(1051, "G")]),
        NutrientDefinition(
            id: .alcohol, name: "Alcohol", group: .composition, unit: .gram, usda: [USDAMapping(1018, "G")]),
        NutrientDefinition(
            id: .caffeine, name: "Caffeine", group: .composition, unit: .milligram, usda: [USDAMapping(1057, "MG")]),

        NutrientDefinition(
            id: .vitaminA, name: "Vitamin A", group: .vitamins, unit: .microgram, form: "RAE",
            usda: [USDAMapping(1106, "UG")]),
        NutrientDefinition(
            id: .vitaminAIU, name: "Vitamin A (IU)", group: .vitamins, unit: .internationalUnit, form: "IU",
            usda: [USDAMapping(1104, "IU")]),
        NutrientDefinition(
            id: .vitaminC, name: "Vitamin C", group: .vitamins, unit: .milligram, usda: [USDAMapping(1162, "MG")]),
        NutrientDefinition(
            id: .vitaminD, name: "Vitamin D", group: .vitamins, unit: .microgram,
            usda: [
                USDAMapping(1114, "UG"),
                USDAMapping(1110, "IU", factor: 0.025, note: "Vitamin D: 1 IU = 0.025 µg (FDA)"),
            ]),
        NutrientDefinition(
            id: .vitaminE, name: "Vitamin E", group: .vitamins, unit: .milligram, form: "alpha-tocopherol",
            usda: [USDAMapping(1109, "MG")]),
        NutrientDefinition(
            id: .vitaminK, name: "Vitamin K", group: .vitamins, unit: .microgram, usda: [USDAMapping(1185, "UG")]),
        NutrientDefinition(
            id: .thiamin, name: "Thiamin (B1)", shortName: "Thiamin", group: .vitamins, unit: .milligram,
            usda: [USDAMapping(1165, "MG")]),
        NutrientDefinition(
            id: .riboflavin, name: "Riboflavin (B2)", shortName: "Riboflavin", group: .vitamins, unit: .milligram,
            usda: [USDAMapping(1166, "MG")]),
        NutrientDefinition(
            id: .niacin, name: "Niacin (B3)", shortName: "Niacin", group: .vitamins, unit: .milligram,
            form: "preformed niacin", usda: [USDAMapping(1167, "MG")]),
        NutrientDefinition(
            id: .vitaminB6, name: "Vitamin B6", group: .vitamins, unit: .milligram, usda: [USDAMapping(1175, "MG")]),
        NutrientDefinition(
            id: .folate, name: "Folate (DFE)", shortName: "Folate", group: .vitamins, unit: .microgram, form: "DFE",
            usda: [USDAMapping(1190, "UG")]),
        NutrientDefinition(
            id: .folateTotal, name: "Folate, total", group: .vitamins, unit: .microgram, form: "folate mass",
            usda: [USDAMapping(1177, "UG")]),
        NutrientDefinition(
            id: .folicAcid, name: "Folic acid", group: .vitamins, unit: .microgram, usda: [USDAMapping(1186, "UG")]),
        NutrientDefinition(
            id: .vitaminB12, name: "Vitamin B12", group: .vitamins, unit: .microgram, usda: [USDAMapping(1178, "UG")]),
        NutrientDefinition(
            id: .pantothenicAcid, name: "Pantothenic acid (B5)", shortName: "Pantothenic acid", group: .vitamins,
            unit: .milligram, usda: [USDAMapping(1170, "MG")]),
        NutrientDefinition(
            id: .biotin, name: "Biotin (B7)", shortName: "Biotin", group: .vitamins, unit: .microgram,
            usda: [USDAMapping(1176, "UG")]),
        NutrientDefinition(
            id: .choline, name: "Choline", group: .vitamins, unit: .milligram, usda: [USDAMapping(1180, "MG")]),

        NutrientDefinition(
            id: .calcium, name: "Calcium", group: .minerals, unit: .milligram, usda: [USDAMapping(1087, "MG")]),
        NutrientDefinition(id: .iron, name: "Iron", group: .minerals, unit: .milligram, usda: [USDAMapping(1089, "MG")]),
        NutrientDefinition(
            id: .magnesium, name: "Magnesium", group: .minerals, unit: .milligram, usda: [USDAMapping(1090, "MG")]),
        NutrientDefinition(
            id: .phosphorus, name: "Phosphorus", group: .minerals, unit: .milligram, usda: [USDAMapping(1091, "MG")]),
        NutrientDefinition(
            id: .potassium, name: "Potassium", group: .minerals, unit: .milligram, usda: [USDAMapping(1092, "MG")]),
        NutrientDefinition(
            id: .sodium, name: "Sodium", group: .minerals, unit: .milligram, usda: [USDAMapping(1093, "MG")]),
        NutrientDefinition(id: .zinc, name: "Zinc", group: .minerals, unit: .milligram, usda: [USDAMapping(1095, "MG")]),
        NutrientDefinition(
            id: .copper, name: "Copper", group: .minerals, unit: .milligram, usda: [USDAMapping(1098, "MG")]),
        NutrientDefinition(
            id: .manganese, name: "Manganese", group: .minerals, unit: .milligram, usda: [USDAMapping(1101, "MG")]),
        NutrientDefinition(
            id: .selenium, name: "Selenium", group: .minerals, unit: .microgram, usda: [USDAMapping(1103, "UG")]),
        NutrientDefinition(
            id: .iodine, name: "Iodine", group: .minerals, unit: .microgram, usda: [USDAMapping(1100, "UG")]),
        NutrientDefinition(
            id: .fluoride, name: "Fluoride", group: .minerals, unit: .microgram, usda: [USDAMapping(1099, "UG")]),

        NutrientDefinition(
            id: "betaCarotene", name: "Beta-carotene", group: .carotenoids, unit: .microgram,
            usda: [USDAMapping(1107, "UG")]),
        NutrientDefinition(
            id: "lycopene", name: "Lycopene", group: .carotenoids, unit: .microgram, usda: [USDAMapping(1122, "UG")]),
        NutrientDefinition(
            id: "luteinZeaxanthin", name: "Lutein + zeaxanthin", group: .carotenoids, unit: .microgram,
            usda: [USDAMapping(1123, "UG")]),

        NutrientDefinition(
            id: "pufa18_2", name: "Linoleic acid (18:2, total)", shortName: "18:2", group: .fattyAcids, unit: .gram,
            usda: [USDAMapping(1269, "G")]),
        NutrientDefinition(
            id: "pufa18_3", name: "Linolenic acid (18:3, total)", shortName: "18:3", group: .fattyAcids, unit: .gram,
            usda: [USDAMapping(1270, "G")]),
        NutrientDefinition(
            id: "ala", name: "ALA (18:3 n-3)", shortName: "ALA", group: .fattyAcids, unit: .gram,
            usda: [USDAMapping(1404, "G")]),
        NutrientDefinition(
            id: "epa", name: "EPA (20:5 n-3)", shortName: "EPA", group: .fattyAcids, unit: .gram,
            usda: [USDAMapping(1278, "G")]),
        NutrientDefinition(
            id: "dpa", name: "DPA (22:5 n-3)", shortName: "DPA", group: .fattyAcids, unit: .gram,
            usda: [USDAMapping(1280, "G")]),
        NutrientDefinition(
            id: "dha", name: "DHA (22:6 n-3)", shortName: "DHA", group: .fattyAcids, unit: .gram,
            usda: [USDAMapping(1272, "G")]),
    ] + aminoAcids

    private static let aminoAcids: [NutrientDefinition] = [
        ("tryptophan", "Tryptophan", 1210), ("threonine", "Threonine", 1211), ("isoleucine", "Isoleucine", 1212),
        ("leucine", "Leucine", 1213), ("lysine", "Lysine", 1214), ("methionine", "Methionine", 1215),
        ("cystine", "Cystine", 1216), ("phenylalanine", "Phenylalanine", 1217), ("tyrosine", "Tyrosine", 1218),
        ("valine", "Valine", 1219), ("arginine", "Arginine", 1220), ("histidine", "Histidine", 1221),
        ("alanine", "Alanine", 1222), ("asparticAcid", "Aspartic acid", 1223),
        ("glutamicAcid", "Glutamic acid", 1224), ("glycine", "Glycine", 1225), ("proline", "Proline", 1226),
        ("serine", "Serine", 1227),
    ].map { id, name, number in
        NutrientDefinition(
            id: NutrientID(id), name: name, group: .aminoAcids, unit: .gram, usda: [USDAMapping(number, "G")])
    }

    private static let byID: [NutrientID: NutrientDefinition] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func definition(for id: NutrientID) -> NutrientDefinition? { byID[id] }

    public static func definitions(in group: NutrientGroup) -> [NutrientDefinition] {
        all.filter { $0.group == group }
    }

    /// Every USDA nutrient number referenced by any mapping.
    public static var usdaNutrientNumbers: Set<Int> {
        Set(all.flatMap { $0.usdaMappings.map(\.nutrientNumber) })
    }

    /// Maps raw USDA amounts (keyed by FDC nutrient number) onto canonical nutrients.
    ///
    /// A mapping is skipped when the source unit differs from the one it documents, so an
    /// unexpected unit is dropped rather than guessed. Missing values stay missing.
    public static func normalizeUSDA(_ values: [Int: (amount: Double, unit: String)]) -> NutrientProfile {
        NutrientProfile(selectUSDA(values).mapValues(\.amount))
    }

    /// Like `normalizeUSDA`, also reporting which USDA nutrient number supplied each value.
    public static func selectUSDA(
        _ values: [Int: (amount: Double, unit: String)]
    ) -> [NutrientID: (amount: Double, nutrientNumber: Int)] {
        var selected: [NutrientID: (amount: Double, nutrientNumber: Int)] = [:]
        for definition in all {
            for mapping in definition.usdaMappings {
                guard let value = values[mapping.nutrientNumber],
                    value.unit.caseInsensitiveCompare(mapping.sourceUnit) == .orderedSame,
                    value.amount.isFinite, value.amount >= 0
                else { continue }
                selected[definition.id] = (value.amount * mapping.factor, mapping.nutrientNumber)
                break
            }
        }
        return selected
    }
}
