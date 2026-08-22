import Foundation
import Combine
import SwiftUI
import AppKit
import SwiftData

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "系统"
    case light = "浅色"
    case dark = "深色"
    
    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: return "跟随系统"
        case .light: return "浅色"
        case .dark: return "深色"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// 应用界面语言；system 表示跟随 macOS 当前语言。
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case chinese = "zh-Hans"
    case japanese = "ja"
    case korean = "ko"
    case russian = "ru"

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .system: return "跟随系统"
        case .english: return "English"
        case .chinese: return "中文简体"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .russian: return "Русский"
        }
    }

    var locale: Locale {
        self == .system ? .current : Locale(identifier: rawValue)
    }

    static func localized(_ key: String, locale: Locale) -> String {
        let identifiers = [locale.identifier, locale.language.languageCode?.identifier].compactMap { $0 }
        for identifier in identifiers {
            guard let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
                  let bundle = Bundle(path: path) else { continue }
            return bundle.localizedString(forKey: key, value: key, table: nil)
        }
        return Bundle.main.localizedString(forKey: key, value: key, table: nil)
    }

    /// 当前生效语言，供无法访问 SwiftUI 环境的模型、网络与服务层使用；由 AppState 维护。
    static var current: AppLanguage = .system

    /// 以当前应用语言翻译字符串；带占位符时请配合 `String(format:)` 使用。
    static func localizedString(_ key: String) -> String {
        localized(key, locale: current.locale)
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var connections: [Connection] = []
    @Published var currentConnection: Connection?
    @Published var isConnected: Bool = false
    @Published var selectedSidebarItem: SidebarItem = .indices
    @Published var favorites: [String] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showFavorites: Bool = true
    @Published var theme: AppTheme = .system {
        didSet {
            applyTheme()
            if !isRestoringPersistentState { saveSettings() }
        }
    }
    @Published var language: AppLanguage = .system {
        didSet {
            AppLanguage.current = language
            if !isRestoringPersistentState { saveSettings() }
        }
    }
    
    private let modelContext: ModelContext
    private let legacyUserDefaults = UserDefaults.standard
    private let legacyConnectionsKey = "elastic_client_connections"
    private let legacyCurrentConnectionIDKey = "elastic_client_current_connection"
    private let legacyThemeKey = "elastic_client_theme"
    private let legacyFavoritesKey = "elastic_client_favorites"
    private let legacyLanguageKey = "seekes_language"
    private let settingsIdentifier = "seekes_settings"
    private var isRestoringPersistentState = false
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        isRestoringPersistentState = true
        loadPersistedState()
        isRestoringPersistentState = false
    }
    
    // MARK: - Connection Management
    func addConnection(_ connection: Connection) {
        var newConnection = connection
        newConnection.isActive = true
        
        // Mark all other connections as inactive
        for i in connections.indices {
            connections[i].isActive = false
        }
        
        connections.append(newConnection)
        currentConnection = newConnection
        ESAPIClient.shared.configure(with: newConnection)
        save()
    }
    
    func updateConnection(_ connection: Connection) {
        if let index = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[index] = connection
            save()
            
            if currentConnection?.id == connection.id {
                currentConnection = connection
                ESAPIClient.shared.configure(with: connection)
            }
        }
    }
    
    func deleteConnection(_ connection: Connection) {
        connections.removeAll { $0.id == connection.id }
        if currentConnection?.id == connection.id {
            currentConnection = connections.first
            isConnected = false
            if let conn = currentConnection {
                ESAPIClient.shared.configure(with: conn)
            }
        }
        save()
    }
    
    func connect(to connection: Connection) async {
        isLoading = true
        errorMessage = nil
        
        ESAPIClient.shared.configure(with: connection)
        
        do {
            let success = try await ESAPIClient.shared.testConnection()
            isConnected = success
            currentConnection = connection
            selectedSidebarItem = .indices
            isLoading = false
            
            // Update active status
            for i in connections.indices {
                connections[i].isActive = (connections[i].id == connection.id)
            }
            
            save()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func disconnect() {
        isConnected = false
    }
    
    // MARK: - Favorites Management
    func toggleFavorite(_ indexName: String) {
        if favorites.contains(indexName) {
            favorites.removeAll { $0 == indexName }
        } else {
            favorites.append(indexName)
        }
        saveSettings()
    }
    
    func isFavorite(_ indexName: String) -> Bool {
        favorites.contains(indexName)
    }
    
    // MARK: - Theme
    private func applyTheme() {
        NSApp.appearance = theme.colorScheme == .dark ? NSAppearance(named: .darkAqua) : 
                          theme.colorScheme == .light ? NSAppearance(named: .aqua) : nil
    }
    
    // MARK: - SwiftData Persistence
    /// 从 SwiftData 恢复状态；首次升级时仅迁移一次旧版 UserDefaults 数据。
    private func loadPersistedState() {
        let storedConnections = (try? modelContext.fetch(FetchDescriptor<StoredConnection>(sortBy: [SortDescriptor(\.sortOrder)]))) ?? []
        if storedConnections.isEmpty {
            connections = legacyConnections()
            persistConnections()
        } else {
            connections = storedConnections.map(\.connection)
        }

        let settings = settingsRecord()
        if !settings.hasMigratedLegacyData {
            migrateLegacySettings(into: settings)
        }
        theme = AppTheme(rawValue: settings.themeRawValue) ?? .system
        language = AppLanguage(rawValue: settings.languageRawValue) ?? .system
        favorites = (try? JSONDecoder().decode([String].self, from: settings.favoriteIndexData)) ?? []
        currentConnection = connections.first(where: { $0.id == settings.currentConnectionID })
        if let currentConnection {
            ESAPIClient.shared.configure(with: currentConnection)
        }
        applyTheme()
    }

    /// 读取旧版连接数据，仅用于没有 SwiftData 记录时的首次迁移。
    private func legacyConnections() -> [Connection] {
        guard let data = legacyUserDefaults.data(forKey: legacyConnectionsKey),
              let decoded = try? JSONDecoder().decode([Connection].self, from: data) else {
            return []
        }
        return decoded
    }

    /// 将旧版偏好迁移到同一份 SwiftData 设置记录，保留旧数据以便版本回退。
    private func migrateLegacySettings(into settings: StoredAppSettings) {
        settings.themeRawValue = legacyUserDefaults.string(forKey: legacyThemeKey) ?? AppTheme.system.rawValue
        settings.languageRawValue = legacyUserDefaults.string(forKey: legacyLanguageKey) ?? AppLanguage.system.rawValue
        settings.currentConnectionID = legacyUserDefaults.string(forKey: legacyCurrentConnectionIDKey).flatMap(UUID.init(uuidString:))
        let favorites = legacyUserDefaults.stringArray(forKey: legacyFavoritesKey) ?? []
        settings.favoriteIndexData = (try? JSONEncoder().encode(favorites)) ?? Data()
        settings.hasMigratedLegacyData = true
        saveModelContext()
    }

    /// 获取唯一的应用设置记录，不存在时创建默认记录。
    private func settingsRecord() -> StoredAppSettings {
        if let settings = try? modelContext.fetch(FetchDescriptor<StoredAppSettings>()).first(where: { $0.identifier == settingsIdentifier }) {
            return settings
        }
        let settings = StoredAppSettings(
            identifier: settingsIdentifier,
            themeRawValue: AppTheme.system.rawValue,
            languageRawValue: AppLanguage.system.rawValue,
            currentConnectionID: nil,
            favoriteIndexData: Data(),
            hasMigratedLegacyData: false
        )
        modelContext.insert(settings)
        return settings
    }

    /// 将内存中的连接列表同步到 SwiftData，移除已删除的记录。
    private func persistConnections() {
        let stored = (try? modelContext.fetch(FetchDescriptor<StoredConnection>())) ?? []
        var records = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
        for (offset, connection) in connections.enumerated() {
            if let record = records.removeValue(forKey: connection.id) {
                record.update(from: connection, sortOrder: offset)
            } else {
                modelContext.insert(StoredConnection(connection: connection, sortOrder: offset))
            }
        }
        records.values.forEach(modelContext.delete)
        saveModelContext()
    }

    private func save() {
        persistConnections()
        saveSettings()
    }
    
    private func saveSettings() {
        let settings = settingsRecord()
        settings.themeRawValue = theme.rawValue
        settings.languageRawValue = language.rawValue
        settings.currentConnectionID = currentConnection?.id
        settings.favoriteIndexData = (try? JSONEncoder().encode(favorites)) ?? Data()
        saveModelContext()
    }

    /// 提交 SwiftData 变更；保存失败时保留错误，避免连接数据静默丢失。
    private func saveModelContext() {
        modelContext.processPendingChanges()
        do {
            try modelContext.save()
        } catch {
            errorMessage = String(format: AppLanguage.localizedString("本地数据保存失败：%@"), error.localizedDescription)
            print("SeekES SwiftData save failed: \(error)")
        }
    }
}
