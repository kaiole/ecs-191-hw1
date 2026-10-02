import InstalogCore
import SwiftUI

struct TodayView: View {
    @Bindable var model: DiaryModel
    @Binding var sheet: ActiveSheet?

    var body: some View {
        VStack(spacing: 0) {
            header
            SummaryHeader(model: model, openDetails: { sheet = .nutrients })
                .padding(.horizontal, 20)
                .padding(.top, 6)
            SectionCard(model: model, sheet: $sheet)
                .padding(.horizontal, 10)
                .padding(.top, 14)
            bottomBar
        }
        .background(Palette.background.ignoresSafeArea())
        .overlay(alignment: .bottom) { toast }
        .foregroundStyle(Palette.text)
    }

    private var header: some View {
        HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Format.dayHeading(model.viewedDate, today: model.today))
                    .font(Typeface.sans(24, .semibold, relativeTo: .title))
                    .tracking(-0.4)
                Text(Format.dayStamp(model.viewedDate))
                    .font(Typeface.mono(12, relativeTo: .caption))
                    .foregroundStyle(Palette.secondary)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            if !model.isViewingToday {
                Button("Today") { Task { await model.changeDate(to: model.today) } }
                    .font(Typeface.sans(14, .semibold))
                    .foregroundStyle(Palette.accent)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 6)
            }
            Button { sheet = .day } label: { Image(systemName: "calendar") }
                .buttonStyle(IconButtonStyle(background: .clear, foreground: Palette.secondary))
                .accessibilityLabel("Choose day")
            Button { sheet = .settings } label: { Image(systemName: "slider.horizontal.3") }
                .buttonStyle(IconButtonStyle(background: .clear, foreground: Palette.secondary))
                .accessibilityLabel("Settings")
        }
        .padding(.leading, 20)
        .padding(.trailing, 12)
        .padding(.top, 8)
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let previous = model.previousLogOfSelectedMeal, model.toast == nil {
                Label(
                    "Already logged at \(Format.time(previous.recordedAt)). Logging again adds another entry.",
                    systemImage: "info.circle"
                )
                .font(Typeface.sans(12, relativeTo: .caption))
                .foregroundStyle(Palette.secondary)
                .padding(.horizontal, 6)
            }
            HStack(spacing: 10) {
                if let meal = model.selectedMeal {
                    Button(action: openAddFood) {
                        Label("Add food", systemImage: "plus")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    Button {
                        Task { await model.logSelectedMeal() }
                    } label: {
                        HStack {
                            if model.isLogging {
                                ProgressView().tint(Palette.onAccent)
                            }
                            Text(logLabel(for: meal)).lineLimit(1)
                            Spacer(minLength: 4)
                            Text(NumberFormatting.energy(model.draftNutrition[.energy].known))
                                .font(Typeface.mono(14, .semibold))
                                .foregroundStyle(Palette.onAccentDim)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(model.isLogging)
                    .accessibilityLabel("\(logLabel(for: meal)), \(NumberFormatting.energy(model.draftNutrition[.energy].known)) calories")
                } else {
                    Button(action: openAddFood) {
                        Label("Add food to \(destinationLabel)", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private var destinationLabel: String {
        model.currentDestination.isUnsectioned && !model.hasSections ? "today" : model.currentDestination.name
    }

    private func logLabel(for meal: MealTemplate) -> String {
        (model.previousLogOfSelectedMeal == nil ? "Log to " : "Log again to ") + destinationLabel
    }

    private func openAddFood() {
        sheet = .addFood(destinationID: model.currentDestination.id, date: model.viewedDate)
    }

    @ViewBuilder
    private var toast: some View {
        if let toast = model.toast {
            ToastView(toast: toast, undo: { Task { await model.undo(toast) } })
                .padding(.horizontal, 12)
                .padding(.bottom, 92)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: toast.id) {
                    try? await Task.sleep(for: .seconds(5))
                    if model.toast?.id == toast.id {
                        withAnimation { model.toast = nil }
                    }
                }
        }
    }
}

struct ToastView: View {
    let toast: Toast
    let undo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Palette.success)
                .accessibilityHidden(true)
            Text(toast.message)
                .font(Typeface.sans(14, .medium, relativeTo: .subheadline))
                .frame(maxWidth: .infinity, alignment: .leading)
            if toast.undo != nil {
                Button("Undo", action: undo)
                    .font(Typeface.sans(14, .semibold))
                    .foregroundStyle(Palette.success)
                    .padding(.horizontal, 14)
                    .frame(minHeight: 40)
                    .background(Color(hex: 0xDDE3E7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .foregroundStyle(Palette.background)
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .frame(minHeight: 44)
        .background(Palette.text, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.55), radius: 16, y: 12)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.updatesFrequently)
    }
}
