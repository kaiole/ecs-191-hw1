import InstalogCore
import SwiftUI

@main
struct InstalogApp: App {
    @State private var model: DiaryModel?
    @State private var startupError: String?

    init() {
        Typeface.registerBundledFonts()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let model {
                    RootView(model: model)
                } else if let startupError {
                    StartupErrorView(message: startupError)
                } else {
                    Palette.background.ignoresSafeArea()
                }
            }
            .preferredColorScheme(.dark)
            .task { await start() }
        }
    }

    private func start() async {
        guard model == nil else { return }
        do {
            let url = try SQLitePersonalStore.defaultURL()
            #if DEBUG
            if CommandLine.arguments.contains("--reset-data") {
                for suffix in ["", "-wal", "-shm"] {
                    try? FileManager.default.removeItem(atPath: url.path + suffix)
                }
            }
            #endif
            let store = try SQLitePersonalStore(url: url)
            // Search still works for saved meals and custom foods if the catalog can't open.
            let catalog = try? SQLiteFoodCatalog.bundled()
            let diary = DiaryModel(store: store, catalog: catalog)
            await diary.load()
            model = diary
        } catch {
            startupError = "Couldn’t open local storage. \(error)"
        }
    }
}

struct StartupErrorView: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "externaldrive.badge.exclamationmark").font(.system(size: 40))
            Text(message).multilineTextAlignment(.center)
        }
        .foregroundStyle(Palette.secondary)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background)
    }
}

/// Every sheet the main screen can present.
enum ActiveSheet: Identifiable, Hashable {
    case sections
    case entry(UUID)
    case addFood(destinationID: String, date: LogDate)
    case settings
    case setup
    case nutrients
    case day
    case newMeal

    var id: String {
        switch self {
        case .sections: "sections"
        case .entry(let id): "entry-\(id)"
        case .addFood(let destination, let date): "add-\(destination)-\(date)"
        case .settings: "settings"
        case .setup: "setup"
        case .nutrients: "nutrients"
        case .day: "day"
        case .newMeal: "newMeal"
        }
    }
}

struct RootView: View {
    @Bindable var model: DiaryModel
    @State private var sheet: ActiveSheet?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TodayView(model: model, sheet: $sheet)
            .sheet(item: $sheet) { sheet in
                sheetContent(sheet)
                    .errorAlert(model)
                    .presentationBackground(Palette.sheet)
                    .presentationCornerRadius(28)
                    .presentationDragIndicator(.visible)
                    .preferredColorScheme(.dark)
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { model.errorMessage != nil && sheet == nil }, set: { if !$0 { model.errorMessage = nil } })
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(model.errorMessage ?? "")
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.refreshForCurrentDate(isIdle: sheet == nil) } }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                Task { await model.refreshForCurrentDate(isIdle: sheet == nil) }
            }
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ActiveSheet) -> some View {
        let close = { self.sheet = nil }
        switch sheet {
        case .sections:
            SectionsSheet(model: model, close: close, editRoutine: { self.sheet = .setup })
                .presentationDetents([.medium, .large])
        case .entry(let id):
            if let entry = model.entries.first(where: { $0.id == id }) {
                EntrySheet(model: model, original: entry, close: close)
                    .presentationDetents([.large])
            }
        case .addFood(let destinationID, let date):
            AddFoodSheet(
                model: model,
                destination: model.destinations.first { $0.id == destinationID } ?? model.currentDestination,
                date: date, close: close)
        case .settings:
            SettingsSheet(model: model, close: close)
        case .setup:
            NavigationStack { SetupView(model: model, close: close) }
        case .nutrients:
            NutrientsSheet(model: model, close: close, openSettings: { self.sheet = .settings })
        case .day:
            DayPickerSheet(model: model, close: close)
                .presentationDetents([.medium, .large])
        case .newMeal:
            NavigationStack { MealEditorView(model: model, meal: nil, onDone: close) }
        }
    }
}
