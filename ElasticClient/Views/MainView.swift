import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var indexVM = IndexViewModel()
    @StateObject private var documentVM = DocumentViewModel()
    @State private var showConnectionEditor = false
    @State private var editingConnection: Connection?
    @State private var showSettings = false
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .all
    
    var body: some View {
        NavigationSplitView(columnVisibility: $sidebarVisibility) {
            SidebarView(
                showConnectionEditor: $showConnectionEditor,
                editingConnection: $editingConnection,
                showSettings: $showSettings
            )
            .environmentObject(appState)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } detail: {
            VStack(spacing: 0) {
                if appState.isConnected {
                    WorkspaceHeader(
                        selectedItem: $appState.selectedSidebarItem,
                        leadingPadding: sidebarVisibility == .detailOnly ? 184 : 20
                    )
                        .environmentObject(appState)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: 56)
                    Divider()
                }

                if !appState.isConnected && appState.connections.isEmpty {
                    WelcomeView(showConnectionEditor: $showConnectionEditor)
                } else {
                    switch appState.selectedSidebarItem {
                    case .overview:
                        OverviewView()
                            .environmentObject(indexVM)
                    case .indices:
                        IndexView()
                            .environmentObject(indexVM)
                            .environmentObject(documentVM)
                    case .query:
                        QueryView()
                            .environmentObject(indexVM)
                    case .console:
                        OverviewView().environmentObject(indexVM)
                    case .analyzer:
                        AnalyzerView()
                            .environmentObject(indexVM)
                    case .favorite(let name):
                        FavoriteIndexView(indexName: name)
                            .environmentObject(indexVM)
                            .environmentObject(documentVM)
                    case .settings:
                        SettingsView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .ignoresSafeArea(.container, edges: .top)
            .padding(.top, -40)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showConnectionEditor) {
            ConnectionEditView(connection: $editingConnection)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: appState.isConnected) { _, _ in
            NotificationCenter.default.post(name: .connectionStatusChanged, object: nil)
        }
    }

}

struct WelcomeView: View {
    @Binding var showConnectionEditor: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            AppLogoView(size: 56)
            
            Text("请先添加 Elasticsearch 连接")
                .font(.title3)
                .foregroundColor(.secondary)
            
            Button(action: { showConnectionEditor = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("添加连接")
                }
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 16)
                .frame(height: 36)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

/// 顶部功能切换栏。
struct WorkspaceHeader: View {
    @Binding var selectedItem: SidebarItem
    let leadingPadding: CGFloat
    private let items: [SidebarItem] = [.overview, .indices, .query, .analyzer]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                Button {
                    selectedItem = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(iconColor(for: item))
                            .frame(height: 18)
                        Text(item.title)
                            .font(.system(size: 13, weight: selectedItem == item ? .semibold : .regular))
                    }
                    .frame(width: 76, height: 56)
                    .contentShape(Rectangle())
                    .background(selectedItem == item ? Color.accentColor.opacity(0.14) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, leadingPadding)
    }

    /// 为功能入口提供稳定颜色，便于快速区分模块。
    private func iconColor(for item: SidebarItem) -> Color {
        switch item {
        case .overview: return .blue
        case .indices: return .teal
        case .query: return .purple
        case .analyzer: return .orange
        default: return .secondary
        }
    }
}

struct FavoriteIndexView: View {
    let indexName: String
    @EnvironmentObject var indexVM: IndexViewModel
    @EnvironmentObject var documentVM: DocumentViewModel
    
    var body: some View {
        IndexView()
            .environmentObject(indexVM)
            .environmentObject(documentVM)
            .onAppear {
                if let index = indexVM.indices.first(where: { $0.name == indexName }) {
                    indexVM.selectIndex(index)
                } else {
                    Task {
                        await indexVM.loadIndices()
                        if let index = indexVM.indices.first(where: { $0.name == indexName }) {
                            indexVM.selectIndex(index)
                        }
                    }
                }
            }
    }
}
