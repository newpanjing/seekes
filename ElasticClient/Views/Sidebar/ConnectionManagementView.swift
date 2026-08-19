import SwiftUI

struct ConnectionManagementView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var editingConnection: Connection?
    @State private var showAddSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("连接管理")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: {
                    editingConnection = nil
                    showAddSheet = true
                }) {
                    Label("添加连接", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            Divider()
            
            // Error message
            if let error = appState.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.callout)
                        .foregroundColor(.red)
                    Spacer()
                    Button {
                        appState.errorMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.red.opacity(0.1))
            }
            
            // Connection List
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(appState.connections) { connection in
                        ConnectionRowView(
                            connection: connection,
                            isActive: appState.currentConnection?.id == connection.id,
                            isConnected: appState.isConnected && appState.currentConnection?.id == connection.id,
                            isLoading: appState.isLoading && appState.currentConnection?.id == connection.id,
                            onConnect: {
                                Task {
                                    await appState.connect(to: connection)
                                }
                            },
                            onEdit: {
                                editingConnection = connection
                                showAddSheet = true
                            },
                            onDelete: {
                                appState.deleteConnection(connection)
                            }
                        )
                    }
                    
                    if appState.connections.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "network.slash")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("暂无连接")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            Text("点击上方按钮添加Elasticsearch连接")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 60)
                    }
                }
                .padding()
            }
            
            Divider()
            
            // Footer
            HStack {
                Spacer()
                Button("关闭") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 600, height: 500)
        .sheet(isPresented: $showAddSheet) {
            ConnectionEditView(connection: $editingConnection)
        }
    }
}

struct ConnectionRowView: View {
    let connection: Connection
    let isActive: Bool
    let isConnected: Bool
    let isLoading: Bool
    let onConnect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            ESLogoView()
                .frame(width: 40, height: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(connection.name)
                        .font(.headline)
                    if isActive {
                        Text("当前")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
                
                Text(connection.baseURL)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.7)
                        Text("连接中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Circle()
                            .fill(isConnected ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(isConnected ? "已连接" : "未连接")
                            .font(.caption)
                            .foregroundColor(isConnected ? Color.green : .secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: onConnect) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(isConnected ? "重新连接" : "连接", systemImage: isConnected ? "arrow.clockwise" : "link")
                            .font(.callout)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
                
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isActive ? Color.blue.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: isActive ? 2 : 1)
                )
        )
    }
}

struct ConnectionEditView: View {
    @Binding var connection: Connection?
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var name: String = ""
    @State private var host: String = "http://localhost"
    @State private var port: String = "9200"
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var useAuth: Bool = false
    @State private var isTesting: Bool = false
    @State private var testResult: (success: Bool, message: String)?
    
    var isEditing: Bool {
        connection != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text(isEditing ? "编辑连接" : "新建连接")
                .font(.headline)
                .padding()
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    FormField(title: "连接名称", placeholder: "My Elasticsearch") {
                        TextField("连接名称", text: $name)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    HStack(alignment: .top, spacing: 12) {
                        FormField(title: "主机地址", placeholder: "http://localhost") {
                            TextField("主机地址", text: $host)
                                .textFieldStyle(.roundedBorder)
                        }

                        FormField(title: "端口", placeholder: "9200") {
                            TextField("端口", text: $port)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 110)
                        }
                    }
                    
                    // Authentication - Toggle on the same line as label
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("启用认证")
                                .font(.callout)
                                .fontWeight(.medium)
                            Spacer()
                            Toggle("", isOn: $useAuth)
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        
                        if useAuth {
                            FormField(title: "用户名") {
                                TextField("用户名", text: $username)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            FormField(title: "密码") {
                                SecureField("密码", text: $password)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    
                }
                .padding()
            }
            
            Divider()
            
            HStack {
                Button("测试连接") {
                    testConnection()
                }
                .disabled(isTesting)

                if isTesting {
                    ProgressView().controlSize(.small)
                } else if let result = testResult {
                    Label(result.message, systemImage: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(result.success ? .green : .red)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                
                Spacer()
                
                Button("取消") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button(isEditing ? "保存" : "添加") {
                    saveConnection()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty || host.isEmpty || port.isEmpty || isTesting)
            }
            .padding()
        }
        .frame(width: 500, height: 480)
        .onAppear {
            if let conn = connection {
                name = conn.name
                host = conn.host
                port = "\(conn.port)"
                username = conn.username ?? ""
                password = conn.password ?? ""
                useAuth = conn.username != nil && !conn.username!.isEmpty
            }
        }
    }
    
    private func testConnection() {
        guard let portInt = Int(port) else {
            testResult = (false, "端口必须是数字")
            return
        }
        
        isTesting = true
        testResult = nil
        
        let testConn = Connection(
            name: name.isEmpty ? "Test" : name,
            host: host,
            port: portInt,
            username: useAuth ? username : nil,
            password: useAuth ? password : nil
        )
        
        Task {
            ESAPIClient.shared.configure(with: testConn)
            do {
                let clusterInfo = try await ESAPIClient.shared.getClusterInfo()
                await MainActor.run {
                    testResult = (true, "连接成功！集群: \(clusterInfo.clusterName), 版本: \(clusterInfo.version.number)")
                    isTesting = false
                }
            } catch {
                await MainActor.run {
                    testResult = (false, "连接失败: \(error.localizedDescription)")
                    isTesting = false
                }
            }
        }
    }
    
    private func saveConnection() {
        guard let portInt = Int(port) else { return }
        
        let newConnection = Connection(
            id: connection?.id ?? UUID(),
            name: name,
            host: host,
            port: portInt,
            username: useAuth && !username.isEmpty ? username : nil,
            password: useAuth && !password.isEmpty ? password : nil,
            isActive: true
        )
        
        if isEditing {
            appState.updateConnection(newConnection)
        } else {
            appState.addConnection(newConnection)
        }
        
        dismiss()
    }
}

struct FormField<Content: View>: View {
    let title: String
    var placeholder: String? = nil
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.callout)
                .fontWeight(.medium)
            content()
        }
    }
}
