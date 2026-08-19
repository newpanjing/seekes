import SwiftUI
import Charts

struct DevToolsView: View {
    @State private var selectedTool: DevTool = .clusterHealth
    @State private var clusterHealth: [String: Any]?
    @State private var nodesInfo: [String: Any]?
    @State private var clusterStats: [String: Any]?
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    
    enum DevTool: String, CaseIterable, Identifiable {
        case clusterHealth = "集群健康"
        case nodesInfo = "节点信息"
        case clusterStats = "集群统计"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .clusterHealth: return "heart.text.square.fill"
            case .nodesInfo: return "server.rack"
            case .clusterStats: return "chart.bar.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("控制台")
                        .font(.system(size: 24, weight: .bold))
                    Text("集群管理和调试工具")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                
                Spacer(minLength: 12)
                
                Button(action: {
                    Task {
                        await loadData()
                    }
                }) {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            
            Divider()
            
            HSplitView {
                // Tools List
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(DevTool.allCases) { tool in
                        Button(action: {
                            selectedTool = tool
                            Task {
                                await loadData()
                            }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: tool.icon)
                                    .frame(width: 20)
                                Text(tool.rawValue)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selectedTool == tool ? Color.blue.opacity(0.15) : Color.clear)
                        )
                    }
                    Spacer(minLength: 0)
                }
                .padding(8)
                .frame(width: 180)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.controlBackgroundColor))
                
                // Content
                VStack(spacing: 0) {
                    if isLoading {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("加载中...")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.red)
                            Text(error)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                switch selectedTool {
                                case .clusterHealth:
                                    if let health = clusterHealth {
                                        ClusterHealthView(health: health)
                                    }
                                case .nodesInfo:
                                    if let nodes = nodesInfo {
                                        NodesInfoView(nodes: nodes)
                                    }
                                case .clusterStats:
                                    if let stats = clusterStats {
                                        ClusterStatsView(stats: stats)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    }
                }
                .frame(minWidth: 400)
                .frame(maxHeight: .infinity, alignment: .topLeading)
                .background(Color(NSColor.textBackgroundColor))
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            Task {
                await loadData()
            }
        }
    }
    
    private func loadData() async {
        guard ESAPIClient.shared.hasConnection else {
            errorMessage = "请先连接Elasticsearch"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            switch selectedTool {
            case .clusterHealth:
                clusterHealth = try await ESAPIClient.shared.getClusterHealth()
            case .nodesInfo:
                nodesInfo = try await ESAPIClient.shared.getNodesInfo()
            case .clusterStats:
                clusterStats = try await ESAPIClient.shared.getClusterStats()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Cluster Health View
struct ClusterHealthView: View {
    let health: [String: Any]
    
    private var statusColor: Color {
        let status = health["status"] as? String ?? "unknown"
        switch status {
        case "green": return .green
        case "yellow": return .yellow
        case "red": return .red
        default: return .gray
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Status Card
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("集群状态")
                        .font(.headline)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 12, height: 12)
                        Text((health["status"] as? String ?? "unknown").uppercased())
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                }
                
                Spacer(minLength: 12)
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("集群名称")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(health["cluster_name"] as? String ?? "-")
                        .font(.headline)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(statusColor.opacity(0.1))
            )
            
            // Stats Grid
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 16)
            ], spacing: 16) {
                DevStatCard(title: "节点数", value: "\(health["number_of_nodes"] as? Int ?? 0)", icon: "server.rack")
                DevStatCard(title: "数据节点", value: "\(health["number_of_data_nodes"] as? Int ?? 0)", icon: "externaldrive")
                DevStatCard(title: "主分片", value: "\(health["active_primary_shards"] as? Int ?? 0)", icon: "cube")
                DevStatCard(title: "总分片", value: "\(health["active_shards"] as? Int ?? 0)", icon: "cubes")
                DevStatCard(title: "初始化中", value: "\(health["initializing_shards"] as? Int ?? 0)", icon: "arrow.triangle.2.circlepath")
                DevStatCard(title: "未分配", value: "\(health["unassigned_shards"] as? Int ?? 0)", icon: "exclamationmark.triangle", color: .orange)
            }
            
            // Raw JSON
            DevJSONSection(title: "原始数据", data: health)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NodesInfoView: View {
    let nodes: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let nodesDict = nodes["nodes"] as? [String: Any] {
                Text("节点列表 (\(nodesDict.count))")
                    .font(.headline)
                
                ForEach(Array(nodesDict.keys.sorted()), id: \.self) { nodeId in
                    if let node = nodesDict[nodeId] as? [String: Any] {
                        NodeInfoCard(nodeId: nodeId, node: node)
                    }
                }
            }
            
            DevJSONSection(title: "原始数据", data: nodes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct NodeInfoCard: View {
    let nodeId: String
    let node: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(node["name"] as? String ?? "Unknown")
                        .font(.headline)
                    Text(nodeId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let version = node["version"] as? String {
                    Text("v\(version)")
                        .font(.callout)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
                }
            }
            
            if let transport = node["transport_address"] as? String {
                InfoRow(label: "地址", value: transport)
            }
            if let host = node["host"] as? String {
                InfoRow(label: "主机", value: host)
            }
            if let ip = node["ip"] as? String {
                InfoRow(label: "IP", value: ip)
            }
            if let roles = node["roles"] as? [String] {
                InfoRow(label: "角色", value: roles.joined(separator: ", "))
            }
        }
        .padding()
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

struct ClusterStatsView: View {
    let stats: [String: Any]

    private var chartMetrics: [(String, Int)] {
        guard let indices = stats["indices"] as? [String: Any] else { return [] }
        let docs = indices["docs"] as? [String: Any]
        return [
            ("索引", indices["count"] as? Int ?? 0),
            ("文档", docs?["count"] as? Int ?? 0),
            ("已删除", docs?["deleted"] as? Int ?? 0)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if let clusterName = stats["cluster_name"] as? String {
                Text("集群: \(clusterName)")
                    .font(.headline)
            }
            
            if let indices = stats["indices"] as? [String: Any] {
                Text("索引统计")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 16)
                ], spacing: 16) {
                    DevStatCard(title: "索引数", value: "\(indices["count"] as? Int ?? 0)", icon: "folder")
                    
                    if let docs = indices["docs"] as? [String: Any] {
                        DevStatCard(title: "文档数", value: "\(docs["count"] as? Int ?? 0)", icon: "doc.text")
                        DevStatCard(title: "已删除", value: "\(docs["deleted"] as? Int ?? 0)", icon: "trash")
                    }
                    
                    if let store = indices["store"] as? [String: Any] {
                        let sizeInBytes = store["size_in_bytes"] as? Int64 ?? 0
                        DevStatCard(title: "存储大小", value: ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file), icon: "internaldrive")
                    }
                }

                if !chartMetrics.isEmpty {
                    Chart(chartMetrics, id: \.0) { metric in
                        BarMark(
                            x: .value("指标", metric.0),
                            y: .value("数量", metric.1)
                        )
                        .foregroundStyle(.blue.gradient)
                    }
                    .frame(height: 220)
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            if let nodes = stats["nodes"] as? [String: Any] {
                Text("节点统计")
                    .font(.headline)
                
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 16)
                ], spacing: 16) {
                    let count = nodes["count"] as? [String: Any] ?? [:]
                    DevStatCard(title: "总节点", value: "\(count["total"] as? Int ?? 0)", icon: "server.rack")
                    DevStatCard(title: "数据节点", value: "\(count["data"] as? Int ?? 0)", icon: "externaldrive")
                    DevStatCard(title: "协调节点", value: "\(count["coordinating_only"] as? Int ?? 0)", icon: "arrow.left.arrow.right")
                    
                    if let os = nodes["os"] as? [String: Any],
                       let mem = os["mem"] as? [String: Any] {
                        let totalMem = mem["total_in_bytes"] as? Int64 ?? 0
                        let usedMem = mem["used_in_bytes"] as? Int64 ?? 0
                        DevStatCard(title: "总内存", value: ByteCountFormatter.string(fromByteCount: totalMem, countStyle: .memory), icon: "memorychip")
                        DevStatCard(title: "已用内存", value: ByteCountFormatter.string(fromByteCount: usedMem, countStyle: .memory), icon: "memorychip", color: .orange)
                        if let freeMem = mem["free_in_bytes"] as? Int64 {
                            DevStatCard(title: "可用内存", value: ByteCountFormatter.string(fromByteCount: freeMem, countStyle: .memory), icon: "memorychip", color: .green)
                        }
                    }
                }
            }
            
            DevJSONSection(title: "原始数据", data: stats)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DevStatCard: View {
    let title: String
    let value: String
    let icon: String
    var color: Color = .blue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
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

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

struct DevJSONSection: View {
    let title: String
    let data: [String: Any]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                ResponseViewer(attributedText: JSONFormatter.formatJSONString(jsonString))
                    .frame(maxHeight: 300)
            }
        }
    }
}
