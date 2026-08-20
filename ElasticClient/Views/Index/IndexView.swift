import SwiftUI

struct IndexView: View {
    @EnvironmentObject var indexVM: IndexViewModel
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var appState: AppState
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
                // Error message
                if let error = indexVM.errorMessage {
                    HStack(alignment: .top) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text(error)
                            .font(.callout)
                            .foregroundColor(.orange)
                        Spacer(minLength: 12)
                        Button {
                            Task {
                                await indexVM.loadIndices()
                            }
                        } label: { Label("重试", systemImage: "arrow.clockwise") }
                        .buttonStyle(.bordered)
                        .help("重试")
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                }
                
                // Main Content
                HSplitView {
                    // Left: Index List with expandable fields
                    IndexListView(
                        onRefresh: { Task { await indexVM.refresh() } }
                    )
                        .frame(minWidth: 220, idealWidth: 220, maxWidth: 260)
                    
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
        .sheet(isPresented: $indexVM.showCreateIndexSheet) {
            CreateIndexSheet(
                isPresented: $indexVM.showCreateIndexSheet,
                indexName: $newIndexName,
                shards: $newIndexShards,
                replicas: $newIndexReplicas
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
    @EnvironmentObject var indexVM: IndexViewModel
    @State private var showCreateDocument = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            DocumentSearchBarView()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            HStack {
                Text("索引数据")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    showCreateDocument = true
                } label: {
                    Label("新建文档", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            
            Divider()
            
            // Document List + Detail
            HSplitView {
                DocumentListView()
                    .frame(minWidth: 180, idealWidth: 220, maxWidth: 240)
                
                JSONViewerTextView()
                    .frame(minWidth: 500)
            }
            
            Divider()
            
            // Pagination
            DocumentPaginationView()
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .sheet(isPresented: $showCreateDocument) {
            CreateDocumentSheet(isPresented: $showCreateDocument)
                .environmentObject(documentVM)
                .environmentObject(indexVM)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct CreateIndexSheet: View {
    @Binding var isPresented: Bool
    @Binding var indexName: String
    @Binding var shards: Int
    @Binding var replicas: Int
    @EnvironmentObject var indexVM: IndexViewModel
    @State private var mode: CreationMode = .visual
    @State private var fields: [CreateIndexField] = []
    @State private var definitionJSON = "{\n  \"settings\": {\n    \"number_of_shards\": 1,\n    \"number_of_replicas\": 1\n  },\n  \"mappings\": {\n    \"properties\": {}\n  }\n}"

    private enum CreationMode: String, CaseIterable, Identifiable {
        case visual = "可视化"
        case json = "JSON"

        var id: String { rawValue }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("新建索引")
                .font(.headline)
                .padding()
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                TextField("索引名称", text: $indexName)
                    .textFieldStyle(.roundedBorder)

                Picker("创建方式", selection: $mode) {
                    ForEach(CreationMode.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if mode == .visual {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Stepper("主分片数: \(shards)", value: $shards, in: 1...10)
                            Stepper("副本数: \(replicas)", value: $replicas, in: 0...5)
                        }
                        HStack {
                            Text("字段").font(.subheadline.weight(.semibold))
                            Spacer()
                            Button {
                                fields.append(CreateIndexField())
                            } label: {
                                Label("新增字段", systemImage: "plus")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                        if fields.isEmpty {
                            Text("暂无字段，可直接创建空索引")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 6) {
                                    ForEach($fields) { $field in
                                        HStack(spacing: 8) {
                                            TextField("字段名", text: $field.name)
                                                .textFieldStyle(.roundedBorder)
                                            Picker("类型", selection: $field.type) {
                                                ForEach(CreateIndexField.types, id: \.self) { type in
                                                    Text(type).tag(type)
                                                }
                                            }
                                            .labelsHidden()
                                            .frame(width: 130)
                                            Button {
                                                fields.removeAll { $0.id == field.id }
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.borderless)
                                            .foregroundColor(.red)
                                            .help("删除字段")
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 180)
                        }
                    }
                } else {
                    JSONEditor(text: $definitionJSON, showsLineNumbers: false)
                        .frame(minHeight: 260)
                }

                if let error = indexVM.errorMessage {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }
            .padding()
            
            Divider()
            
            HStack {
                Button {
                    isPresented = false
                } label: { Label("取消", systemImage: "xmark") }
                .buttonStyle(.bordered)
                .help("取消")
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button {
                    Task {
                        if mode == .visual {
                            await indexVM.createIndex(name: indexName, numberOfShards: shards, numberOfReplicas: replicas, fields: fields)
                        } else {
                            await indexVM.createIndex(name: indexName, definitionJSON: definitionJSON)
                        }
                        if indexVM.errorMessage == nil {
                            indexName = ""
                            isPresented = false
                        }
                    }
                } label: { Label("创建", systemImage: "checkmark") }
                .buttonStyle(.borderedProminent)
                .help("创建")
                .disabled(indexName.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 620, height: 560, alignment: .topLeading)
    }
}

/// 可视化创建索引时的一行字段配置。
struct CreateIndexField: Identifiable {
    let id = UUID()
    var name = ""
    var type = "keyword"

    static let types = ["keyword", "text", "integer", "long", "float", "double", "boolean", "date", "ip", "object", "nested"]
}

struct IndexInfoHeaderView: View {
    let index: Index
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 24) {
                    InfoItem(label: "文档数", value: "\(index.docsCount.formatted())")
                    InfoItem(label: "存储大小", value: index.storeSize)
                    InfoItem(label: "主分片", value: "\(index.primaryShards)")
                    InfoItem(label: "副本", value: "\(index.replicaShards)")
                    if let date = index.creationDate {
                        InfoItem(label: "创建时间", value: date.formattedString())
                    }
                    IndexHealthBadge(index: index)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 告警索引可查看服务端健康详情，正常索引仅展示状态。
private struct IndexHealthBadge: View {
    let index: Index
    @State private var isLoading = false
    @State private var showDetails = false
    @State private var details = ""

    private var statusColor: Color {
        index.health == .green ? .green : (index.health == .yellow ? .orange : .red)
    }

    var body: some View {
        Group {
            if index.health == .green {
                label
            } else {
                Button(action: loadDetails) { label }
                    .buttonStyle(.plain)
                    .help("查看健康告警详情")
            }
        }
        .sheet(isPresented: $showDetails) {
            IndexHealthDetailSheet(indexName: index.name, details: details)
        }
    }

    private var label: some View {
        HStack(spacing: 4) {
            if isLoading {
                ProgressView().controlSize(.mini)
            } else {
                Circle().fill(statusColor).frame(width: 6, height: 6)
            }
            Text(index.health.displayText).font(.system(size: 13)).foregroundColor(statusColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(statusColor.opacity(0.1)))
    }

    private func loadDetails() {
        Task {
            isLoading = true
            do {
                let data = try await ESAPIClient.shared.getIndexHealthDetails(indexName: index.name)
                details = String(decoding: data, as: UTF8.self)
            } catch {
                details = error.localizedDescription
            }
            isLoading = false
            showDetails = true
        }
    }
}

private struct IndexHealthDetailSheet: View {
    let indexName: String
    let details: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(indexName).font(.headline).lineLimit(1)
                Spacer()
                Button("关闭") { dismiss() }
            }
            .padding(12)
            Divider()
            CollapsibleJSONView(jsonText: details)
        }
        .frame(width: 720, height: 500)
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
                        Text(tab.title)
                            .font(.system(size: 14, weight: indexVM.selectedTab == tab ? .semibold : .regular))
                            .foregroundColor(indexVM.selectedTab == tab ? .blue : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                        
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
                        StatsCard(title: "查询耗时", value: formattedDuration(stats.search.queryTimeInMillis), icon: "clock", color: .orange)
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

    /// 按毫秒或秒展示查询耗时，避免数值与单位粘连。
    private func formattedDuration(_ milliseconds: Int) -> String {
        milliseconds < 1_000 ? "\(milliseconds) ms" : String(format: "%.2f s", Double(milliseconds) / 1_000)
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
