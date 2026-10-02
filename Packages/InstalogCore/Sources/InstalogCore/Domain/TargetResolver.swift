import Foundation

public struct EffectiveTarget: Hashable, Sendable {
    public var nutrientID: NutrientID
    public var kind: TargetKind
    public var amount: Double
    public var unit: NutrientUnit
    public var form: String?
    public var source: TargetSource
    public var note: String?

    public var isReference: Bool {
        if case .referenceTable = source { return true }
        return false
    }
}

public struct TargetComparison: Sendable {
    public var total: NutrientTotal
    public var target: EffectiveTarget?
    /// Consumed amount in the target's terms divided by the target; nil when not comparable.
    public var fraction: Double?
    /// False when units or nutrient forms differ, e.g. preformed niacin versus niacin equivalents.
    public var isComparable: Bool
    /// True when the consumed total is incomplete, so any progress must be read as a lower bound.
    public var isQualified: Bool { total.completeness == .partial }
}

public enum TargetResolver {
    /// Targets in effect on `date`. The latest user record effective on or before the date wins;
    /// a disabled record removes the target. Without a user record, an FDA reference applies
    /// when references are shown.
    public static func effectiveTargets(
        on date: LogDate, targets: [NutritionTarget], showReferences: Bool
    ) -> [NutrientID: EffectiveTarget] {
        var result: [NutrientID: EffectiveTarget] = [:]
        let latest = Dictionary(grouping: targets.filter { $0.effectiveDate <= date }, by: \.nutrientID)
            .compactMapValues { $0.max { $0.effectiveDate < $1.effectiveDate } }
        if showReferences {
            for reference in FDADailyValues.table where latest[reference.nutrientID] == nil {
                result[reference.nutrientID] = EffectiveTarget(
                    nutrientID: reference.nutrientID, kind: reference.kind, amount: reference.amount,
                    unit: reference.unit, form: reference.form,
                    source: .referenceTable(name: FDADailyValues.sourceName, version: FDADailyValues.version),
                    note: reference.note)
            }
        }
        for (id, target) in latest where target.enabled && target.isValid {
            result[id] = EffectiveTarget(
                nutrientID: id, kind: target.kind, amount: target.amount, unit: target.unit, form: target.form,
                source: target.source, note: nil)
        }
        return result
    }

    public static func compare(_ total: NutrientTotal, with target: EffectiveTarget?) -> TargetComparison {
        guard let target, let definition = NutrientRegistry.definition(for: target.nutrientID) else {
            return TargetComparison(total: total, target: target, fraction: nil, isComparable: target == nil)
        }
        let formsMatch = (target.form ?? definition.form) == definition.form
        guard formsMatch, let consumed = definition.unit.convert(total.known, to: target.unit) else {
            return TargetComparison(total: total, target: target, fraction: nil, isComparable: false)
        }
        let fraction: Double? = switch total.completeness {
        case .complete, .partial: target.amount > 0 ? consumed / target.amount : nil
        case .unknown, .empty: nil
        }
        return TargetComparison(total: total, target: target, fraction: fraction, isComparable: true)
    }
}
