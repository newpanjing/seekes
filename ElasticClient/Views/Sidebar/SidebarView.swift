import SwiftUI

/// 连接导航侧栏；功能导航统一位于内容区顶部。
struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @Binding var showConnectionManager: Bool
    @Binding var showSettings: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ESLogoView().frame(width: 30, height: 30)
                Text("SeekES").font(.system(size: 18, weight: .semibold))
                Spacer()
                Button { showConnectionManager = true } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
                .help("添加连接")
            }
            .padding(16)

            Divider()

            ScrollView {
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
                    }
                }
                .padding(8)
            }

            if appState.connections.isEmpty {
                ContentUnavailableView("暂无连接", systemImage: "network.slash")
                    .padding()
            }

            Spacer(minLength: 0)
            Divider()
            HStack {
                Button { showConnectionManager = true } label: {
                    Label("管理连接", systemImage: "network")
                }
                .buttonStyle(.plain)
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .buttonStyle(.plain)
                .help("设置")
            }
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor))
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
