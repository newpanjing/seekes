import SwiftUI
import SwiftData

@main
struct SeekESApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var appState: AppState

    init() {
        let container: ModelContainer
        do {
            container = try ModelContainer(for: StoredConnection.self, StoredAppSettings.self)
        } catch {
            fatalError(String(format: AppLanguage.localizedString("无法初始化本地数据库: %@"), error.localizedDescription))
        }
        modelContainer = container
        _appState = StateObject(wrappedValue: AppState(modelContext: container.mainContext))
    }
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(appState)
                .environment(\.locale, appState.language.locale)
                // Recreate the scene when the selected locale changes so every
                // localized SwiftUI label resolves against the new bundle.
                .id(appState.language.rawValue)
                .frame(minWidth: 1200, minHeight: 800)
        }
        .modelContainer(modelContainer)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}
