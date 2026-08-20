import SwiftUI

struct IndexListView: View {
    @EnvironmentObject var indexVM: IndexViewModel
    let onCreate: () -> Void
    let onRefresh: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    TextField("搜索索引名称", text: $indexVM.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .layoutPriority(1)
                }
                .padding(.leading, 12)
                .padding(.trailing, 10)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
                indexActionButton(systemImage: "plus", help: "新建索引", action: onCreate)
                indexActionButton(systemImage: "arrow.clockwise", help: "刷新索引", action: onRefresh)
            }
            .padding(.horizontal, 10)
            .padding(.top, 10)
            .padding(.bottom, 6)
            
            // Index List
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(indexVM.filteredIndices) { index in
                        IndexListRow(
                            index: index,
                            isSelected: indexVM.selectedIndex?.id == index.id,
                            isExpanded: indexVM.expandedIndices.contains(index.name),
                            fields: indexVM.indexFieldsMap[index.name] ?? [],
                            isLoadingFields: indexVM.loadingFieldsForIndex == index.name
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            indexVM.selectIndex(index)
                        }
                        .contextMenu {
                            Button("查看数据") { indexVM.selectIndex(index) }
                            Button("查看映射") {
                                indexVM.selectIndex(index)
                                indexVM.tabChanged(to: .mapping)
                            }
                            Button("刷新字段") { Task { await indexVM.loadFieldsForIndex(index.name) } }
                            Divider()
                            Button("删除索引", role: .destructive) {
                                NSAlert.showConfirmation(
                                    title: "删除索引",
                                    message: "确定要删除索引 \(index.name) 吗？索引中的所有文档都会被删除。"
                                ) { confirmed in
                                    if confirmed {
                                        Task { await indexVM.deleteIndex(index) }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            
            Spacer(minLength: 0)
            
            // Footer
            HStack {
                Text("共 \(indexVM.indices.count) 个索引")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.textBackgroundColor))
    }

    /// 索引列表顶部使用统一尺寸的图标操作按钮。
    private func indexActionButton(systemImage: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .medium))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .help(help)
    }
}

struct IndexListRow: View {
    let index: Index
    let isSelected: Bool
    let isExpanded: Bool
    let fields: [IndexField]
    let isLoadingFields: Bool
    @EnvironmentObject var indexVM: IndexViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row
            HStack(spacing: 6) {
                // Expand/collapse button
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        indexVM.toggleExpandIndex(index)
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 16, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(index.name)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        
                        Circle()
                            .fill(index.health == .green ? Color.green : (index.health == .yellow ? Color.yellow : Color.red))
                            .frame(width: 6, height: 6)
                        
                        Spacer(minLength: 4)
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(index.docsCount.formatted()) 文档")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        
                        Text("\(fields.count) 字段")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
            )
            
            // Fields list (when expanded)
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    if isLoadingFields {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("加载字段中...")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(.leading, 32)
                        .padding(.vertical, 6)
                    } else if fields.isEmpty {
                        Text("暂无字段信息")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .padding(.leading, 32)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(fields) { field in
                            FieldRowView(field: field, isSelected: isSelected)
                        }
                    }
                }
                .padding(.leading, 4)
                .padding(.bottom, 4)
            }
        }
    }
}

struct FieldRowView: View {
    let field: IndexField
    let isSelected: Bool

    private var iconName: String {
        if field.name == "_id" { return "key" }
        return field.isSearchable ? "magnifyingglass" : "tag"
    }

    private var iconColor: Color {
        if field.name == "_id" { return .orange }
        return field.isSearchable ? .blue : .secondary
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 16)
            
            Text(field.name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 4)
            
            Text(field.type)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.blue)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule().fill(Color.blue.opacity(0.1))
                )
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
    }
}
