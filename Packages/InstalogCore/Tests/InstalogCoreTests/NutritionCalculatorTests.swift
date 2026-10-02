import Foundation
import Testing
@testable import InstalogCore

@Suite("Nutrition engine")
struct NutritionCalculatorTests {
    private func item(_ food: FoodDefinition, _ quantity: Double, _ unit: MeasureUnit = .gram) -> NutritionCalculator.Item {
        NutritionCalculator.Item(nutrition: food.nutrition, quantity: quantity, unit: unit)
    }

    @Test("Spec fixture: 50 g Food A + 100 g Food B")
    func specFixture() throws {
        let summary = try NutritionCalculator.summarize([item(Fixtures.foodA, 50), item(Fixtures.foodB, 100)])

        #expect(summary[.energy].known.isClose(to: 200))
        #expect(summary[.energy].completeness == .complete)
        #expect(summary[.protein].known.isClose(to: 7))
        #expect(summary[.protein].completeness == .complete)
        #expect(summary[.magnesium].known.isClose(to: 20))
        #expect(summary[.magnesium].completeness == .partial)
    }

    @Test("AT-23: known subtotal with a missing food is partial, not complete")
    func partialTotal() throws {
        let total = try NutritionCalculator.summarize([item(Fixtures.foodA, 50), item(Fixtures.foodB, 100)])[.magnesium]
        #expect(total.reportingFoods == 1)
        #expect(total.missingFoods == 1)
        #expect(total.displayAmount == 20)
    }

    @Test("AT-24: explicit zeros are known and complete")
    func explicitZero() throws {
        let zeroA = FoodDefinition(
            source: .custom, name: "Zero A",
            nutrition: FoodNutrition(basis: .per100Grams, nutrients: NutrientProfile([.caffeine: 0])))
        let zeroB = FoodDefinition(
            source: .custom, name: "Zero B",
            nutrition: FoodNutrition(basis: .per100Grams, nutrients: NutrientProfile([.caffeine: 0])))
        let total = try NutritionCalculator.summarize([item(zeroA, 100), item(zeroB, 50)])[.caffeine]
        #expect(total.completeness == .complete)
        #expect(total.displayAmount == 0)
    }

    @Test("AT-25: a nutrient no food supplies is unknown, not zero")
    func unknownNutrient() throws {
        let total = try NutritionCalculator.summarize([item(Fixtures.foodA, 50), item(Fixtures.foodB, 100)])[.vitaminC]
        #expect(total.completeness == .unknown)
        #expect(total.displayAmount == nil)
    }

    @Test("Empty context is distinct from unknown")
    func emptyContext() throws {
        let summary = try NutritionCalculator.summarize([])
        #expect(summary[.energy].completeness == .empty)
        #expect(summary[.energy].displayAmount == nil)
    }

    @Test("A known zero subtotal with a missing food stays incomplete")
    func zeroSubtotalWithMissing() throws {
        let zero = FoodDefinition(
            source: .custom, name: "Zero",
            nutrition: FoodNutrition(basis: .per100Grams, nutrients: NutrientProfile([.iron: 0])))
        let total = try NutritionCalculator.summarize([item(zero, 100), item(Fixtures.foodB, 100)])[.iron]
        #expect(total.completeness == .partial)
        #expect(total.known == 0)
    }

    @Test("AT-26: 1.5 portions of a 30 g portion scale using 45 g")
    func decimalPortion() throws {
        let nutrients = try Fixtures.foodA.nutrition.nutrients(quantity: 1.5, unit: .portion(id: "scoop"))
        #expect(nutrients[.energy]!.isClose(to: 90))
        #expect(nutrients[.protein]!.isClose(to: 4.5))
        #expect(Fixtures.foodA.nutrition.grams(quantity: 1.5, unit: .portion(id: "scoop"))!.isClose(to: 45))
    }

    @Test("AT-27: volume without a density or portion mapping is rejected")
    func volumeWithoutDensity() {
        #expect(throws: MeasureError.unsupportedConversion(from: .volume, to: .mass)) {
            try Fixtures.foodA.nutrition.basisMultiple(quantity: 100, unit: .milliliter)
        }
        #expect(!Fixtures.foodA.nutrition.supportedUnits.contains(.milliliter))
    }

    @Test("Volume converts when a density is documented")
    func volumeWithDensity() throws {
        var nutrition = Fixtures.foodB.nutrition
        nutrition.density = 1.03
        let nutrients = try nutrition.nutrients(quantity: 100, unit: .milliliter)
        #expect(nutrients[.energy]!.isClose(to: 103))
    }

    @Test("Ounces convert to grams exactly")
    func ounces() throws {
        let nutrients = try Fixtures.foodB.nutrition.nutrients(quantity: 1, unit: .ounce)
        #expect(nutrients[.energy]!.isClose(to: 28.349_523_125))
    }

    @Test("Serving-based foods accept grams only with a serving weight")
    func servingBasis() throws {
        let bar = FoodNutrition(
            basis: NutritionBasis(amount: 1, dimension: .serving, servingName: "bar", servingGrams: 40),
            nutrients: NutrientProfile([.energy: 200]))
        #expect(try bar.nutrients(quantity: 2, unit: .serving)[.energy]!.isClose(to: 400))
        #expect(try bar.nutrients(quantity: 20, unit: .gram)[.energy]!.isClose(to: 100))

        let unknownWeight = FoodNutrition(
            basis: NutritionBasis(amount: 1, dimension: .serving, servingName: "bar"),
            nutrients: NutrientProfile([.energy: 200]))
        #expect(throws: MeasureError.self) { try unknownWeight.basisMultiple(quantity: 20, unit: .gram) }
    }

    @Test("Zero-quantity items contribute nothing and are not counted as foods")
    func zeroQuantity() throws {
        let summary = try NutritionCalculator.summarize([item(Fixtures.foodA, 0), item(Fixtures.foodB, 100)])
        #expect(summary.foodCount == 1)
        #expect(summary[.magnesium].completeness == .unknown)
    }

    @Test("Negative and non-finite quantities are rejected")
    func invalidQuantities() {
        #expect(throws: MeasureError.invalidQuantity) {
            try Fixtures.foodA.nutrition.basisMultiple(quantity: -1, unit: .gram)
        }
        #expect(throws: MeasureError.invalidQuantity) {
            try Fixtures.foodA.nutrition.basisMultiple(quantity: .infinity, unit: .gram)
        }
    }

    @Test("Ingredients are not rounded before summing")
    func noIntermediateRounding() throws {
        let tiny = FoodDefinition(
            source: .custom, name: "Tiny",
            nutrition: FoodNutrition(basis: .per100Grams, nutrients: NutrientProfile([.protein: 0.4])))
        let summary = try NutritionCalculator.summarize(Array(repeating: item(tiny, 100), count: 3))
        #expect(summary[.protein].known.isClose(to: 1.2))
    }

    @Test("Calculations are deterministic for identical snapshots")
    func deterministic() throws {
        let items = [item(Fixtures.foodA, 37.3), item(Fixtures.foodB, 12.9), item(Fixtures.milk, 1.25, .portion(id: "cup"))]
        #expect(try NutritionCalculator.summarize(items) == NutritionCalculator.summarize(items))
    }
}

@Suite("Nutrient registry")
struct NutrientRegistryTests {
    @Test("AT-28: one energy value is chosen; alternatives are never summed")
    func singleEnergy() {
        let profile = NutrientRegistry.normalizeUSDA([
            1008: (89, "KCAL"), 2047: (91, "KCAL"), 2048: (88, "KCAL"), 1062: (371, "kJ"),
        ])
        #expect(profile[.energy] == 89)
    }

    @Test("Energy falls back through documented expressions, converting kJ")
    func energyFallback() {
        #expect(NutrientRegistry.normalizeUSDA([2048: (88, "KCAL"), 2047: (91, "KCAL")])[.energy] == 88)
        let fromKJ = NutrientRegistry.normalizeUSDA([1062: (418.4, "kJ")])[.energy]!
        #expect(fromKJ.isClose(to: 100))
    }

    @Test("Vitamin D IU uses the documented 0.025 µg/IU conversion only as a fallback")
    func vitaminD() {
        #expect(NutrientRegistry.normalizeUSDA([1110: (400, "IU")])[.vitaminD]!.isClose(to: 10))
        #expect(NutrientRegistry.normalizeUSDA([1110: (400, "IU"), 1114: (2, "UG")])[.vitaminD] == 2)
    }

    @Test("Vitamin A IU and RAE stay separate nutrients")
    func vitaminAForms() {
        let profile = NutrientRegistry.normalizeUSDA([1104: (500, "IU"), 1106: (25, "UG")])
        #expect(profile[.vitaminA] == 25)
        #expect(profile[.vitaminAIU] == 500)
    }

    @Test("An unexpected source unit is dropped rather than guessed")
    func unexpectedUnit() {
        #expect(NutrientRegistry.normalizeUSDA([1090: (27, "UG")])[.magnesium] == nil)
    }

    @Test("Mass units normalize; IU and energy do not convert to mass")
    func massConversion() {
        #expect(NutrientUnit.milligram.convert(1500, to: .gram)!.isClose(to: 1.5))
        #expect(NutrientUnit.microgram.convert(2500, to: .milligram)!.isClose(to: 2.5))
        #expect(NutrientUnit.internationalUnit.convert(100, to: .microgram) == nil)
        #expect(NutrientUnit.kilocalorie.convert(100, to: .gram) == nil)
    }

    @Test("Registry IDs are unique and every FDA reference maps to a nutrient")
    func registryIntegrity() {
        #expect(Set(NutrientRegistry.all.map(\.id)).count == NutrientRegistry.all.count)
        for reference in FDADailyValues.table {
            #expect(NutrientRegistry.definition(for: reference.nutrientID) != nil)
        }
    }

    @Test("Profiles encode as a keyed JSON object")
    func profileCoding() throws {
        let profile = NutrientProfile([.protein: 5, .magnesium: 0])
        let json = String(data: try JSONEncoder().encode(profile), encoding: .utf8)!
        #expect(json.contains("\"protein\":5"))
        #expect(try JSONDecoder().decode(NutrientProfile.self, from: Data(json.utf8)) == profile)
    }
}

@Suite("Quantity steps")
struct QuantityStepTests {
    @Test func gramSteps() {
        #expect(QuantityStep.increase(60, unit: .gram) == 65)
        #expect(QuantityStep.decrease(62, unit: .gram) == 60)
        #expect(QuantityStep.increase(180, unit: .gram) == 190)
        #expect(QuantityStep.decrease(1, unit: .gram) == 0)
        #expect(QuantityStep.decrease(0, unit: .gram) == 0)
    }

    @Test func portionSteps() {
        #expect(QuantityStep.increase(1, unit: .serving) == 1.5)
        #expect(QuantityStep.decrease(1, unit: .portion(id: "x")) == 0.75)
        #expect(QuantityStep.decrease(0.25, unit: .portion(id: "x")) == 0)
    }

    @Test func arrayMove() {
        #expect([1, 2, 3, 4].moving(fromOffsets: [0], toOffset: 3) == [2, 3, 1, 4])
        #expect([1, 2, 3, 4].moving(fromOffsets: [3], toOffset: 0) == [4, 1, 2, 3])
        #expect([1, 2, 3, 4].moving(fromOffsets: [1], toOffset: 4) == [1, 3, 4, 2])
    }
}
