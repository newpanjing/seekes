import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Header
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.title3)
                    
                    TextField("搜索所有索引中的文档...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .font(.title3)
                        .onSubmit {
                            Task {
                                await viewModel.performSearch()
                            }
                        }
                    
                    if viewModel.isLoading {
                        ProgressView()
                            .controlSize(.small)
                    }
                    
                    Button(action: {
                        Task {
                            await viewModel.performSearch()
                        }
                    }) {
                        Text("搜索")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                if !viewModel.searchResults.isEmpty {
                    HStack {
                        Text("找到 \(viewModel.totalResults) 个结果")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Text("(\(viewModel.took) ms)")
                            .font(.callout)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .padding(20)
            
            Divider()
            
            // Results
            if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchResults.isEmpty && !viewModel.isLoading {
                VStack(spacing: 16) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)
                    Text("输入关键词搜索所有索引")
                        .font(.title2)
                        .foregroundColor(.secondary)
                    Text("支持跨所有索引的全文搜索")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                HSplitView {
                    // Results List
                    ScrollView {
                        LazyVStack(spacing: 1) {
                            ForEach(viewModel.searchResults) { hit in
                                SearchResultRow(
                                    hit: hit,
                                    isSelected: viewModel.selectedResult?.id == hit.id
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.selectResult(hit)
                                }
                            }
                        }
                    }
                    .frame(minWidth: 300)
                    
                    // Result Detail
                    if let result = viewModel.selectedResult {
                        VStack(alignment: .leading, spacing: 0) {
                            // Result Header
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("文档详情")
                                        .font(.headline)
                                    Spacer()
                                    Text("索引: \(result.index)")
                                        .font(.callout)
                                        .foregroundColor(.secondary)
                                    Text("ID: \(result.id)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                HStack(spacing: 16) {
                                    if let score = result.score {
                                        Text("评分: \(String(format: "%.2f", score))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            
                            Divider()
                            
                            // JSON Content
                            if viewModel.resultDetail != nil {
                                ResponseViewer(attributedText: JSONFormatter.formatJSONString(viewModel.getResultJSON()))
                            } else {
                                ProgressView("加载中...")
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                        .background(Color(NSColor.textBackgroundColor))
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("选择一个结果查看详情")
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        .onAppear {
            if viewModel.searchText.isEmpty && viewModel.searchResults.isEmpty {
                // Auto-load recent documents when connected
                Task {
                    await viewModel.performSearch()
                }
            }
        }
    }
}

struct SearchResultRow: View {
    let hit: DocumentHit
    let isSelected: Bool
    
    private var previewText: String {
        guard let source = hit.source else { return AppLanguage.localizedString("无内容") }
        if let firstKey = source.keys.first,
           let value = source[firstKey] {
            return "\(firstKey): \(String(describing: value.value).prefix(50))"
        }
        return "ID: \(hit.id)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(hit.id)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                Spacer()
                Text(hit.index)
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Capsule())
            }
            
            Text(previewText)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 1),
            alignment: .bottom
        )
    }
}
