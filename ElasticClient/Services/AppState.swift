import Foundation
import Combine
import SwiftUI
import AppKit

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "系统"
    case light = "浅色"
    case dark = "深色"
    
    var id: String { rawValue }
    
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

    var title: String {
        switch self {
        case .system: return "跟随系统"
        case .english: return "English"
        case .chinese: return "中文"
        case .japanese: return "日本語"
        case .korean: return "한국어"
        case .russian: return "Русский"
        }
    }

    var locale: Locale {
        self == .system ? .current : Locale(identifier: rawValue)
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
            saveSettings()
        }
    }
    @Published var language: AppLanguage = .system {
        didSet { saveSettings() }
    }
    @Published var showAddConnection: Bool = false
    @Published var showSettings: Bool = false
    
    private let userDefaults = UserDefaults.standard
    private let connectionsKey = "elastic_client_connections"
    private let currentConnectionIdKey = "elastic_client_current_connection"
    private let themeKey = "elastic_client_theme"
    private let favoritesKey = "elastic_client_favorites"
    private let languageKey = "seekes_language"
    
    init() {
        loadInitialTheme()
        loadFromUserDefaults()
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
        save()
        
        if currentConnection?.id == connection.id {
            currentConnection = connections.first
            isConnected = false
            if let conn = currentConnection {
                ESAPIClient.shared.configure(with: conn)
            }
            saveSettings()
        }
    }
    
    func connect(to connection: Connection) async {
        isLoading = true
        errorMessage = nil
        
        ESAPIClient.shared.configure(with: connection)
        
        do {
            let success = try await ESAPIClient.shared.testConnection()
            isConnected = success
            currentConnection = connection
            selectedSidebarItem = .overview
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
    private func loadInitialTheme() {
        if let themeRaw = userDefaults.string(forKey: themeKey),
           let savedTheme = AppTheme(rawValue: themeRaw) {
            theme = savedTheme
        }
        if let languageRaw = userDefaults.string(forKey: languageKey),
           let savedLanguage = AppLanguage(rawValue: languageRaw) {
            language = savedLanguage
        }
        applyTheme()
    }
    
    private func applyTheme() {
        NSApp.appearance = theme.colorScheme == .dark ? NSAppearance(named: .darkAqua) : 
                          theme.colorScheme == .light ? NSAppearance(named: .aqua) : nil
    }
    
    // MARK: - UserDefaults Persistence
    private func loadFromUserDefaults() {
        // Load connections
        if let data = userDefaults.data(forKey: connectionsKey),
           let decoded = try? JSONDecoder().decode([Connection].self, from: data) {
            connections = decoded
        }
        
        // Load favorites
        if let savedFavorites = userDefaults.stringArray(forKey: favoritesKey) {
            favorites = savedFavorites
        }
        
        // Restore current connection
        if let currentIdString = userDefaults.string(forKey: currentConnectionIdKey),
           let currentId = UUID(uuidString: currentIdString),
           let conn = connections.first(where: { $0.id == currentId }) {
            currentConnection = conn
            ESAPIClient.shared.configure(with: conn)
        }
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(connections) {
            userDefaults.set(encoded, forKey: connectionsKey)
        }
        saveSettings()
    }
    
    private func saveSettings() {
        userDefaults.set(theme.rawValue, forKey: themeKey)
        userDefaults.set(favorites, forKey: favoritesKey)
        userDefaults.set(language.rawValue, forKey: languageKey)
        userDefaults.set(currentConnection?.id.uuidString, forKey: currentConnectionIdKey)
    }
}
