import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var indexVM = IndexViewModel()
    @StateObject private var documentVM = DocumentViewModel()
    @State private var showConnectionManager = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationSplitView {
            SidebarView(
                showConnectionManager: $showConnectionManager,
                showSettings: $showSettings
            )
            .environmentObject(appState)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220, max: 300)
        } detail: {
            Group {
                if !appState.isConnected && appState.connections.isEmpty {
                    WelcomeView(showConnectionManager: $showConnectionManager)
                } else {
                    switch appState.selectedSidebarItem {
                    case .connection:
                        ConnectionManagementView()
                    case .overview:
                        OverviewView()
                            .environmentObject(indexVM)
                    case .indices:
                        IndexView()
                            .environmentObject(indexVM)
                            .environmentObject(documentVM)
                    case .console:
                        DevToolsView()
                            .environmentObject(indexVM)
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
            .safeAreaInset(edge: .top, spacing: 0) {
                if appState.currentConnection != nil {
                    WorkspaceTabBar(selectedItem: $appState.selectedSidebarItem)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showConnectionManager) {
            ConnectionManagementView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onChange(of: appState.isConnected) { _, _ in
            NotificationCenter.default.post(name: .connectionStatusChanged, object: nil)
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button { showSettings = true } label: {
                    Label("设置", systemImage: "gearshape")
                }
            }
        }
    }
}

struct WelcomeView: View {
    @Binding var showConnectionManager: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            ESLogoView(size: 80)
            
            VStack(spacing: 8) {
                Text("欢迎使用 SeekES")
                    .font(.system(size: 28, weight: .bold))
                Text("请先添加 Elasticsearch 连接开始使用")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { showConnectionManager = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("添加连接")
                }
                .font(.headline)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

/// 连接建立后在内容区顶部提供功能切换，侧栏仅负责连接选择。
struct WorkspaceTabBar: View {
    @Binding var selectedItem: SidebarItem
    private let items: [SidebarItem] = [.overview, .indices, .console, .analyzer]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                Button {
                    selectedItem = item
                } label: {
                    Label(item.title, systemImage: item.iconName)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(selectedItem == item ? Color.accentColor.opacity(0.14) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
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
