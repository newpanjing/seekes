import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var indexVM: IndexViewModel
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("概览")
                        .font(.system(size: 24, weight: .bold))
                    Text("集群健康状态和统计信息")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                
                if !appState.isConnected {
                    VStack(spacing: 16) {
                        Image(systemName: "network.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("未连接到Elasticsearch")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("请先添加并连接到 Elasticsearch 实例")
                            .font(.body)
                            .foregroundColor(.secondary)
                        Button("连接管理") {
                            appState.showSettings = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 100)
                } else {
                    // Cluster Info
                    if let cluster = indexVM.clusterInfo {
                        ClusterInfoCard(cluster: cluster)
                            .padding(.horizontal, 24)
                    }
                    
                    // Stats Cards
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        OverviewStatCard(
                            title: "索引数量",
                            value: "\(indexVM.indices.count)",
                            icon: "tablecells",
                            color: .blue
                        )
                        OverviewStatCard(
                            title: "文档总数",
                            value: "\(indexVM.indices.reduce(0) { $0 + $1.docsCount }.formatted())",
                            icon: "doc.text",
                            color: .green
                        )
                        OverviewStatCard(
                            title: "健康索引",
                            value: "\(indexVM.indices.filter { $0.health == .green }.count)",
                            icon: "checkmark.circle",
                            color: .green
                        )
                        OverviewStatCard(
                            title: "警告索引",
                            value: "\(indexVM.indices.filter { $0.health == .yellow }.count)",
                            icon: "exclamationmark.triangle",
                            color: .orange
                        )
                    }
                    .padding(.horizontal, 24)
                    
                    // Index List Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("索引列表")
                            .font(.headline)
                        
                        VStack(spacing: 1) {
                            ForEach(indexVM.indices.prefix(10)) { index in
                                HStack {
                                    Circle()
                                        .fill(index.health == .green ? Color.green : (index.health == .yellow ? Color.yellow : Color.red))
                                        .frame(width: 8, height: 8)
                                    Text(index.name)
                                        .font(.system(size: 13, design: .default))
                                    Spacer()
                                    Text("\(index.docsCount.formatted()) docs")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                    Text(index.storeSize)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .frame(width: 80, alignment: .trailing)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(NSColor.controlBackgroundColor))
                            }
                        }
                        .cornerRadius(8)
                    }
                    .padding(.horizontal, 24)
                    
                    if indexVM.isLoading {
                        ProgressView("加载中...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct ClusterInfoCard: View {
    let cluster: ClusterInfo
    
    var body: some View {
        HStack(spacing: 20) {
            ESLogoView(size: 56)
            
            VStack(alignment: .leading, spacing: 8) {
                Text(cluster.clusterName)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("节点名称")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(cluster.name)
                            .font(.callout)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("版本")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(cluster.version.number)
                            .font(.callout)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lucene版本")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(cluster.version.luceneVersion ?? "-")
                            .font(.callout)
                    }
                }
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.1), Color.cyan.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

struct OverviewStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Spacer()
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold))
            
            Text(title)
                .font(.callout)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}
