import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("设置")
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("关闭")
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    // Appearance Section
                    SettingsSection(title: "外观", icon: "paintpalette.fill") {
                        SettingsItem(icon: "circle.lefthalf.filled", title: "主题", iconColor: .blue) {
                            HStack(spacing: 12) {
                                ForEach(AppTheme.allCases) { theme in
                                    ThemeButton(theme: theme, isSelected: appState.theme == theme) {
                                        appState.theme = theme
                                    }
                                }
                            }
                        }

                        SettingsItem(icon: "globe", title: "语言", iconColor: .green) {
                            Picker("语言", selection: $appState.language) {
                                ForEach(AppLanguage.allCases) { language in
                                    Text(language.title).tag(language)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 150)
                        }
                    }
                    
                    // About Section
                    SettingsSection(title: "关于", icon: "info.circle.fill") {
                        SettingsItem(icon: "number.circle.fill", title: "版本", iconColor: .gray) {
                            Text("1.0.0")
                                .foregroundColor(.secondary)
                        }
                        
                        SettingsItem(icon: "cube.box.fill", title: "Elasticsearch 支持", iconColor: .blue) {
                            Text("7.x / 8.x")
                                .foregroundColor(.secondary)
                        }
                        
                        SettingsItem(icon: "swift", title: "技术栈", iconColor: .orange) {
                            Text("SwiftUI + SwiftData")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 600, height: 550)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SettingsSection<Content: View>: View {
    let title: LocalizedStringKey
    let icon: String
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            VStack(spacing: 1) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
    }
}

struct SettingsItem<Content: View>: View {
    let icon: String
    let title: LocalizedStringKey
    let iconColor: Color
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            
            Text(title)
                .font(.system(size: 14))
            
            Spacer()
            
            content()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
}

struct ThemeButton: View {
    let theme: AppTheme
    let isSelected: Bool
    let action: () -> Void
    
    var iconName: String {
        switch theme {
        case .system: return "desktopcomputer"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 18))
                Text(theme.title)
                    .font(.system(size: 12))
            }
            .frame(width: 70, height: 60)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .foregroundColor(isSelected ? .blue : .primary)
        }
        .buttonStyle(.plain)
    }
}
