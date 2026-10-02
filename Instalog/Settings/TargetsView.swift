import InstalogCore
import SwiftUI

/// User-entered calorie and macro goals, plus optional nutrient targets and FDA references.
struct TargetsView: View {
    let model: DiaryModel
    @State private var editing: NutrientDefinition?

    private static let primary: [NutrientID] = [.energy, .protein, .carbohydrate, .fat]

    var body: some View {
        let targets = model.effectiveTargets
        List {
            SwiftUI.Section {
                ForEach(Self.primary.compactMap(NutrientRegistry.definition(for:))) { definition in
                    row(definition, target: targets[definition.id])
                }
            } header: {
                Caption("Calories & macros")
            } footer: {
                Text("You set these. The app never calculates or changes them for you.")
            }
            SwiftUI.Section {
                Toggle("Show FDA reference values", isOn: Binding(
                    get: { model.preferences.showReferenceValues },
                    set: { value in Task { try? await model.setShowReferenceValues(value) } }))
                    .tint(Palette.accent)
                    .listRowBackground(Palette.row)
            } footer: {
                Text("FDA Daily Values (2016, adults and children 4+) are general label references, not personal requirements. Override or turn off any of them.")
            }
            ForEach(NutrientGroup.allCases.filter { $0 != .energyAndMacros }, id: \.self) { group in
                SwiftUI.Section {
                    ForEach(NutrientRegistry.definitions(in: group)) { definition in
                        row(definition, target: targets[definition.id])
                    }
                } header: {
                    Caption(group.title)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Palette.sheet)
        .navigationTitle("Targets")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { definition in
            TargetEditor(model: model, definition: definition, close: { editing = nil })
                .presentationDetents([.medium])
                .presentationBackground(Palette.sheet)
        }
        .foregroundStyle(Palette.text)
    }

    private func row(_ definition: NutrientDefinition, target: EffectiveTarget?) -> some View {
        Button { editing = definition } label: {
            HStack {
                Text(definition.name).font(Typeface.sans(15))
                Spacer()
                Text(describe(target)).font(Typeface.mono(13)).foregroundStyle(target == nil ? Palette.tertiary : Palette.text)
            }
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Palette.row)
    }

    private func describe(_ target: EffectiveTarget?) -> String {
        guard let target else { return "Not set" }
        let prefix = target.kind == .limit ? "≤ " : ""
        let suffix = target.isReference ? " · DV" : ""
        return prefix + NumberFormatting.nutrient(target.amount, unit: target.unit) + suffix
    }
}

struct TargetEditor: View {
    let model: DiaryModel
    let definition: NutrientDefinition
    let close: () -> Void
    @State private var amount = ""
    @State private var kind: TargetKind = .target

    var body: some View {
        let current = model.effectiveTargets[definition.id]
        let reference = FDADailyValues.value(for: definition.id)
        VStack(alignment: .leading, spacing: 14) {
            SheetHeader(title: definition.name, subtitle: "Applies from today. Earlier days keep their targets.", close: close)
            Picker("Kind", selection: $kind) {
                Text("Target").tag(TargetKind.target)
                Text("Limit").tag(TargetKind.limit)
            }
            .pickerStyle(.segmented)
            HStack {
                TextField("Amount", text: $amount)
                    .keyboardType(.decimalPad)
                    .font(Typeface.mono(22, .semibold))
                Text(definition.unit.rawValue).foregroundStyle(Palette.secondary)
            }
            .padding(.horizontal, 14)
            .frame(height: 54)
            .background(Palette.control, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if let reference {
                Text("FDA Daily Value: \(NumberFormatting.nutrient(reference.amount, unit: reference.unit))\(reference.form.map { " (\($0))" } ?? "")\(reference.note.map { ". \($0)" } ?? "")")
                    .font(Typeface.sans(12))
                    .foregroundStyle(Palette.tertiary)
            }
            HStack(spacing: 10) {
                if current != nil {
                    Button("Turn off") { run { try await model.disableTarget(definition.id) } }
                        .buttonStyle(SecondaryButtonStyle())
                }
                if reference != nil, !(current?.isReference ?? false) {
                    Button("Use DV") { run { try await model.useReferenceValue(definition.id) } }
                        .buttonStyle(SecondaryButtonStyle())
                }
                Button("Save") {
                    guard let value = Double(amount.replacingOccurrences(of: ",", with: ".")), value.isFinite, value >= 0 else {
                        model.errorMessage = "Enter a number of zero or more."
                        return
                    }
                    run { try await model.setTarget(definition.id, amount: value, kind: kind) }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(16)
        .padding(.top, 8)
        .foregroundStyle(Palette.text)
        .onAppear {
            if let current {
                amount = NumberFormatting.quantity(current.amount)
                kind = current.kind == .limit ? .limit : .target
            }
        }
        .errorAlert(model)
    }

    private func run(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
                close()
            } catch {
                model.errorMessage = "Couldn’t save the target."
            }
        }
    }
}

