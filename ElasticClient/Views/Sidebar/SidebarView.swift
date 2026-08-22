import SwiftUI

/// 连接导航侧栏；功能导航统一位于内容区顶部。
struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showConnectionEditor: Bool
    @Binding var editingConnection: Connection?
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                AppLogoView().frame(width: 30, height: 30)
                Text("SeekES").font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    editingConnection = nil
                    showConnectionEditor = true
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("添加连接")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                if appState.connections.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 22))
                            .foregroundColor(.secondary)
                        Text("暂无连接")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 32)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(appState.connections) { connection in
                            Button {
                                Task { await appState.connect(to: connection) }
                            } label: {
                                ConnectionCard(
                                    connection: connection,
                                    isConnected: appState.isConnected && appState.currentConnection?.id == connection.id,
                                    isSelected: appState.currentConnection?.id == connection.id
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("连接") {
                                    Task { await appState.connect(to: connection) }
                                }
                                Button("编辑") {
                                    editingConnection = connection
                                    showConnectionEditor = true
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    NSAlert.showConfirmation(
                                        title: AppLanguage.localizedString("删除连接"),
                                        message: String(format: AppLanguage.localizedString("确定要删除连接 %@ 吗？此操作不可撤销。"), connection.name)
                                    ) { confirmed in
                                        if confirmed { appState.deleteConnection(connection) }
                                    }
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }

            Spacer(minLength: 0)
            Divider()
            HStack {
                Button { showSettings = true } label: {
                    Label("设置", systemImage: "gearshape")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .help("设置")
                Spacer()
            }
            .padding(12)
        }
        .background(Color(NSColor.underPageBackgroundColor))
    }
}

struct ConnectionCard: View {
    let connection: Connection
    let isConnected: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "server.rack")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(connection.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                Text(connection.baseURL).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            Circle().fill(isConnected ? .green : .gray).frame(width: 7, height: 7)
        }
        .foregroundColor(.primary)
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.12) : .clear)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
