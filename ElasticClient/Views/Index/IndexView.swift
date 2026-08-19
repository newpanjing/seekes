import SwiftUI

struct IndexView: View {
    @EnvironmentObject var indexVM: IndexViewModel
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var appState: AppState
    @State private var showCreateIndex = false
    @State private var newIndexName = ""
    @State private var newIndexShards = 1
    @State private var newIndexReplicas = 1
    
    var body: some View {
        VStack(spacing: 0) {
            if !appState.isConnected {
                VStack(spacing: 16) {
                    Image(systemName: "network.slash")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("未连接到Elasticsearch")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                // Top Header
                IndexHeaderView(
                    showCreateIndex: $showCreateIndex,
                    onRefresh: {
                        Task {
                            await indexVM.refresh()
                        }
                    }
                )
                
                Divider()
                
                // Error message
                if let error = indexVM.errorMessage {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.orange)
                        Spacer(minLength: 12)
                        Button("重试") {
                            Task {
                                await indexVM.loadIndices()
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                }
                
                // Main Content
                HSplitView {
                    // Left: Index List with expandable fields
                    IndexListView()
                        .frame(minWidth: 220, idealWidth: 280)
                    
                    // Right: Content Area
                    if indexVM.selectedIndex != nil {
                        IndexDetailView()
                            .frame(minWidth: 500)
                    } else {
                        VStack(alignment: .center, spacing: 12) {
                            if indexVM.isLoading {
                                ProgressView("加载中...")
                            } else {
                                Text("选择一个索引开始浏览")
                                    .foregroundColor(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor))
        .sheet(isPresented: $showCreateIndex) {
            CreateIndexSheet(
                isPresented: $showCreateIndex,
                indexName: $newIndexName,
                shards: $newIndexShards,
                replicas: $newIndexReplicas,
                onCreate: {
                    Task {
                        await indexVM.createIndex(name: newIndexName, numberOfShards: newIndexShards, numberOfReplicas: newIndexReplicas)
                        newIndexName = ""
                    }
                }
            )
        }
        .onChange(of: indexVM.selectedIndex) { _, newIndex in
            if let idx = newIndex {
                NotificationCenter.default.post(name: .indexSelected, object: idx.name)
            }
        }
        .onAppear {
            if let idx = indexVM.selectedIndex {
                NotificationCenter.default.post(name: .indexSelected, object: idx.name)
            }
        }
    }
}

struct IndexDetailView: View {
    @EnvironmentObject var indexVM: IndexViewModel
    @EnvironmentObject var documentVM: DocumentViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            if let index = indexVM.selectedIndex {
                // Index Info Header
                IndexInfoHeaderView(index: index)
                
                // Tab Bar
                IndexTabBarView()
                
                Divider()
                
                // Tab Content
                switch indexVM.selectedTab {
                case .data:
                    DataTabView()
                case .mapping:
                    IndexMappingView(data: indexVM.mappingData)
                case .settings:
                    IndexSettingsView(data: indexVM.settingsData)
                case .stats:
                    IndexStatsView(stats: indexVM.indexStats)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DataTabView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            DocumentSearchBarView()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            
            Divider()
            
            // Document List + Detail
            HSplitView {
                DocumentListView()
                    .frame(minWidth: 200, idealWidth: 280)
                
                JSONViewerTextView()
                    .frame(minWidth: 300)
            }
            
            Divider()
            
            // Pagination
            DocumentPaginationView()
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct IndexHeaderView: View {
    @Binding var showCreateIndex: Bool
    let onRefresh: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("索引")
                    .font(.system(size: 24, weight: .bold))
                Text("管理和浏览 Elasticsearch 索引，点击展开箭头查看字段")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            
            Spacer(minLength: 12)
            
            HStack(spacing: 10) {
                Button(action: { showCreateIndex = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                        Text("新建索引")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

struct CreateIndexSheet: View {
    @Binding var isPresented: Bool
    @Binding var indexName: String
    @Binding var shards: Int
    @Binding var replicas: Int
    let onCreate: () -> Void
    @EnvironmentObject var indexVM: IndexViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            Text("新建索引")
                .font(.headline)
                .padding()
            
            Divider()
            
            Form {
                TextField("索引名称", text: $indexName)
                    .textFieldStyle(.roundedBorder)
                
                Stepper("主分片数: \(shards)", value: $shards, in: 1...10)
                Stepper("副本数: \(replicas)", value: $replicas, in: 0...5)
            }
            .padding()
            
            Divider()
            
            HStack {
                Button("取消") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("创建") {
                    onCreate()
                }
                .buttonStyle(.borderedProminent)
                .disabled(indexName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 400, height: 250)
    }
}

struct IndexInfoHeaderView: View {
    let index: Index
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Text(index.name)
                    .font(.system(size: 20, weight: .semibold))
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(index.health == .green ? Color.green : (index.health == .yellow ? Color.yellow : Color.red))
                        .frame(width: 6, height: 6)
                    Text(index.health.displayText)
                        .font(.system(size: 13))
                        .foregroundColor(index.health == .green ? .green : (index.health == .yellow ? .orange : .red))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill((index.health == .green ? Color.green : (index.health == .yellow ? Color.yellow : Color.red)).opacity(0.1))
                )
                
                Spacer(minLength: 12)
                
                Button(action: {
                    // Add favorite action
                }) {
                    Image(systemName: "star")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 32) {
                    InfoItem(label: "文档数", value: "\(index.docsCount.formatted())")
                    InfoItem(label: "存储大小", value: index.storeSize)
                    InfoItem(label: "主分片", value: "\(index.primaryShards)")
                    InfoItem(label: "副本", value: "\(index.replicaShards)")
                    if let date = index.creationDate {
                        InfoItem(label: "创建时间", value: date.formattedString())
                    }
                    if let version = index.version {
                        InfoItem(label: "版本", value: version)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct InfoItem: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
        }
    }
}

struct IndexTabBarView: View {
    @EnvironmentObject var indexVM: IndexViewModel
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(IndexTab.allCases) { tab in
                Button(action: {
                    indexVM.tabChanged(to: tab)
                }) {
                    VStack(spacing: 0) {
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: indexVM.selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(indexVM.selectedTab == tab ? .blue : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        
                        if indexVM.selectedTab == tab {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 2)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct IndexMappingView: View {
    let data: Data?
    
    var body: some View {
        VStack(spacing: 0) {
            if let data = data,
               let jsonString = String(data: data, encoding: .utf8) {
                ResponseViewer(attributedText: JSONFormatter.formatJSONString(jsonString))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 12) {
                    ProgressView("加载中...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct IndexSettingsView: View {
    let data: Data?
    
    var body: some View {
        VStack(spacing: 0) {
            if let data = data,
               let jsonString = String(data: data, encoding: .utf8) {
                ResponseViewer(attributedText: JSONFormatter.formatJSONString(jsonString))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                VStack(spacing: 12) {
                    ProgressView("加载中...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct IndexStatsView: View {
    let stats: IndexStats?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let stats = stats {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 180), spacing: 16)
                    ], spacing: 16) {
                        StatsCard(title: "文档总数", value: "\(stats.docs.count.formatted())", icon: "doc.text", color: .blue)
                        StatsCard(title: "已删除文档", value: "\(stats.docs.deleted.formatted())", icon: "trash", color: .orange)
                        StatsCard(title: "索引操作", value: "\(stats.indexing.indexTotal.formatted())", icon: "square.and.pencil", color: .green)
                        StatsCard(title: "查询次数", value: "\(stats.search.queryTotal.formatted())", icon: "magnifyingglass", color: .purple)
                        StatsCard(title: "存储大小", value: ByteCountFormatter.string(fromByteCount: Int64(stats.store.sizeInBytes), countStyle: .file), icon: "internaldrive", color: .blue)
                        StatsCard(title: "查询耗时", value: "\(stats.search.queryTimeInMillis)ms", icon: "clock", color: .orange)
                    }
                    .padding()
                } else {
                    VStack(spacing: 12) {
                        ProgressView("加载统计信息中...")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    .padding(.top, 100)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct StatsCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                Spacer(minLength: 0)
            }
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
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
    }
}
