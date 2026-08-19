import SwiftUI

struct IndexListView: View {
    @EnvironmentObject var indexVM: IndexViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    TextField("搜索索引名称", text: $indexVM.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
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
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(NSColor.textBackgroundColor))
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
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                        .frame(width: 16, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(index.name)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundColor(isSelected ? .white : .primary)
                            .lineLimit(1)
                        
                        Circle()
                            .fill(index.health == .green ? Color.green : (index.health == .yellow ? Color.yellow : Color.red))
                            .frame(width: 6, height: 6)
                        
                        Spacer(minLength: 4)
                    }
                    
                    HStack(spacing: 8) {
                        Text("\(index.docsCount.formatted()) 文档")
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                        
                        Text("\(fields.count) 字段")
                            .font(.system(size: 11))
                            .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.blue : Color.clear)
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
                        ForEach(fields.prefix(20)) { field in
                            FieldRowView(field: field, isSelected: isSelected)
                        }
                        if fields.count > 20 {
                            Text("... 还有 \(fields.count - 20) 个字段")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .padding(.leading, 32)
                                .padding(.vertical, 4)
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
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "ellipsis")
                .font(.system(size: 8))
                .foregroundColor(isSelected ? .white.opacity(0.5) : .secondary.opacity(0.5))
                .frame(width: 16)
            
            Text(field.name)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(isSelected ? .white.opacity(0.9) : .primary)
                .lineLimit(1)
            
            Spacer(minLength: 4)
            
            Text(field.type)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isSelected ? .white.opacity(0.7) : .blue)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white.opacity(0.2) : Color.blue.opacity(0.1))
                )
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .padding(.vertical, 3)
    }
}
