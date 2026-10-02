import Foundation
import Testing
@testable import InstalogCore

@Suite("Targets and references")
struct TargetTests {
    private let day = LogDate(year: 2026, month: 10, day: 1)

    @Test("FDA references apply when shown and no personal record exists")
    func referencesShown() {
        let targets = TargetResolver.effectiveTargets(on: day, targets: [], showReferences: true)
        #expect(targets[.magnesium]?.amount == 420)
        #expect(targets[.magnesium]?.isReference == true)
        #expect(targets[.sodium]?.kind == .limit)
        #expect(targets[.energy] == nil, "Calorie goals are user-entered, never imported")
        #expect(targets[.protein] == nil)
        #expect(TargetResolver.effectiveTargets(on: day, targets: [], showReferences: false).isEmpty)
    }

    @Test("A disabled personal record hides the reference; it is not a target of zero")
    func disabledHidesReference() {
        let disabled = NutritionTarget(
            nutrientID: .magnesium, kind: .target, amount: 0, unit: .milligram, effectiveDate: .beginning, enabled: false)
        let targets = TargetResolver.effectiveTargets(on: day, targets: [disabled], showReferences: true)
        #expect(targets[.magnesium] == nil)
    }

    @Test("AT-34: historical days keep the target that was effective then")
    func effectiveDates() {
        let original = NutritionTarget(
            nutrientID: .energy, kind: .target, amount: 2200, unit: .kilocalorie, effectiveDate: .beginning)
        let changed = NutritionTarget(
            nutrientID: .energy, kind: .target, amount: 2000, unit: .kilocalorie, effectiveDate: day)
        let yesterday = day.adding(days: -1)
        #expect(TargetResolver.effectiveTargets(on: yesterday, targets: [original, changed], showReferences: false)[.energy]?.amount == 2200)
        #expect(TargetResolver.effectiveTargets(on: day, targets: [original, changed], showReferences: false)[.energy]?.amount == 2000)
    }

    @Test("Niacin equivalents are not compared with preformed niacin")
    func incompatibleForm() {
        let reference = TargetResolver.effectiveTargets(on: day, targets: [], showReferences: true)[.niacin]
        let comparison = TargetResolver.compare(NutrientTotal(known: 10, reportingFoods: 1, totalFoods: 1), with: reference)
        #expect(!comparison.isComparable)
        #expect(comparison.fraction == nil)
    }

    @Test("Compatible forms and mass units compare")
    func compatibleComparison() {
        let reference = TargetResolver.effectiveTargets(on: day, targets: [], showReferences: true)[.vitaminA]
        let comparison = TargetResolver.compare(NutrientTotal(known: 450, reportingFoods: 2, totalFoods: 2), with: reference)
        #expect(comparison.isComparable)
        #expect(comparison.fraction!.isClose(to: 0.5))
        #expect(!comparison.isQualified)
    }

    @Test("Partial totals stay qualified")
    func partialQualified() {
        let reference = TargetResolver.effectiveTargets(on: day, targets: [], showReferences: true)[.magnesium]
        let comparison = TargetResolver.compare(NutrientTotal(known: 20, reportingFoods: 1, totalFoods: 2), with: reference)
        #expect(comparison.isQualified)
        #expect(comparison.fraction != nil)
    }

    @Test("A zero target never divides by zero; unknown totals have no progress")
    func noDivisionByZero() {
        let zero = EffectiveTarget(
            nutrientID: .caffeine, kind: .limit, amount: 0, unit: .milligram, form: nil, source: .user, note: nil)
        #expect(TargetResolver.compare(NutrientTotal(known: 50, reportingFoods: 1, totalFoods: 1), with: zero).fraction == nil)
        let unknown = TargetResolver.compare(
            NutrientTotal(known: 0, reportingFoods: 0, totalFoods: 3),
            with: TargetResolver.effectiveTargets(on: day, targets: [], showReferences: true)[.magnesium])
        #expect(unknown.fraction == nil)
    }

    @Test("Invalid target values are rejected")
    func invalidValues() {
        #expect(!NutritionTarget(nutrientID: .protein, kind: .target, amount: -1, unit: .gram, effectiveDate: day).isValid)
        #expect(!NutritionTarget(nutrientID: .protein, kind: .target, amount: .nan, unit: .gram, effectiveDate: day).isValid)
    }
}
