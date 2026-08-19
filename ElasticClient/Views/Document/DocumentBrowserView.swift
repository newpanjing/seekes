import SwiftUI

struct DocumentSearchBarView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var indexVM: IndexViewModel

    private var fields: [IndexField] {
        guard let indexName = indexVM.selectedIndex?.name else { return [] }
        return indexVM.indexFieldsMap[indexName] ?? []
    }
    
    var body: some View {
        HStack(spacing: 10) {
            Picker("查询模式", selection: $documentVM.queryMode) {
                ForEach(DocumentQueryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .frame(width: 100)

            if documentVM.queryMode == .json {
                TextField("输入查询 DSL（JSON 格式），留空查询所有文档", text: $documentVM.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(queryInputBackground)
            } else {
                Picker("字段", selection: $documentVM.queryField) {
                    Text("选择字段").tag("")
                    ForEach(fields) { field in
                        Text("\(field.name) (\(field.type))").tag(field.name)
                    }
                }
                .frame(width: 180)
                Picker("操作符", selection: $documentVM.queryOperator) {
                    ForEach(DocumentQueryOperator.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .frame(width: 105)
                TextField("查询值", text: $documentVM.queryValue)
                    .textFieldStyle(.roundedBorder)
            }
            
            Button(action: {
                Task {
                    await documentVM.searchDocuments()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                    Text("搜索")
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.blue)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                documentVM.searchQuery = ""
                documentVM.queryField = ""
                documentVM.queryValue = ""
                Task {
                    await documentVM.searchDocuments()
                }
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 32)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var queryInputBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(NSColor.controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

struct DocumentListView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("共 \(documentVM.totalResults.formatted()) 条")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Spacer(minLength: 8)
                
                Menu {
                    Button("_id", action: {
                        documentVM.sortField = "_id"
                        Task { await documentVM.searchDocuments() }
                    })
                    Button("_score", action: {
                        documentVM.sortField = "_score"
                        Task { await documentVM.searchDocuments() }
                    })
                } label: {
                    HStack(spacing: 4) {
                        Text(documentVM.sortField)
                            .font(.system(size: 12))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    documentVM.sortOrder = documentVM.sortOrder == "asc" ? "desc" : "asc"
                    Task {
                        await documentVM.searchDocuments()
                    }
                }) {
                    Image(systemName: documentVM.sortOrder == "asc" ? "arrow.up" : "arrow.down")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            
            Divider()
            
            if documentVM.isLoading {
                VStack(spacing: 12) {
                    ProgressView("加载中...")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if documentVM.errorMessage != nil && documentVM.documents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                    Text(documentVM.errorMessage ?? "加载失败")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else if documentVM.documents.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)
                    Text("暂无文档")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(documentVM.documents.enumerated()), id: \.element.id) { index, doc in
                            DocumentListRow(
                                doc: doc,
                                index: (documentVM.currentPage - 1) * documentVM.pageSize + index + 1,
                                isSelected: documentVM.selectedDocument?.id == doc.id
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                documentVM.selectDocument(doc)
                            }
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DocumentListRow: View {
    let doc: DocumentHit
    let index: Int
    let isSelected: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("\(index)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? .white : .secondary)
                    .frame(width: 24)
                
                Text(doc.id)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(isSelected ? .white : .primary)
                    .lineLimit(1)
                
                Spacer(minLength: 0)
            }
            
            if let score = doc.score {
                Text("Score: \(String(format: "%.2f", score))")
                    .font(.system(size: 11))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
                    .padding(.leading, 24)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isSelected ? Color.blue : Color.clear)
        )
        .padding(.horizontal, 8)
        .padding(.vertical, 1)
    }
}

struct JSONViewerTextView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let doc = documentVM.selectedDocument {
                    Text(doc.id)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer(minLength: 8)
                
                if documentVM.isEditing {
                    Button(action: {
                        documentVM.cancelEditing()
                    }) {
                        Text("取消")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        Task {
                            await documentVM.saveDocument()
                        }
                    }) {
                        Text("保存")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            .background(Color.blue)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                } else {
                    Button(action: {
                        documentVM.startEditing()
                    }) {
                        Text("编辑")
                            .font(.system(size: 12))
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.blue.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: {
                        NSAlert.showConfirmation(
                            title: "删除文档",
                            message: "确定要删除文档 \(documentVM.selectedDocument?.id ?? "") 吗？此操作不可撤销。"
                        ) { confirmed in
                            if confirmed {
                                Task {
                                    await documentVM.deleteDocument()
                                }
                            }
                        }
                    }) {
                        Text("删除")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.red.opacity(0.5), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                    
                    Button(action: {
                        documentVM.copyDocumentToClipboard()
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            
            Divider()
            
            if documentVM.isEditing {
                ConsoleEditor(text: $documentVM.editJsonText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                if documentVM.isLoading && documentVM.selectedDocumentDetail == nil {
                    VStack(spacing: 12) {
                        ProgressView("加载文档中...")
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else if let error = documentVM.errorMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.red)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                } else {
                    ResponseViewer(attributedText: documentVM.getDocumentJSON())
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DocumentPaginationView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    
    var body: some View {
        HStack {
            Text("检索结果 (\(documentVM.totalResults.formatted()))")
                .font(.system(size: 13, weight: .medium))
            
            Spacer(minLength: 12)
            
            HStack(spacing: 4) {
                Button(action: {
                    if documentVM.currentPage > 1 {
                        documentVM.goToPage(documentVM.currentPage - 1)
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11))
                        .foregroundColor(documentVM.currentPage > 1 ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(documentVM.currentPage <= 1)
                
                let startPage = max(1, documentVM.currentPage - 2)
                let endPage = min(documentVM.totalPages, startPage + 4)
                let adjustedStart = max(1, endPage - 4)
                
                ForEach(adjustedStart...endPage, id: \.self) { page in
                    Button(action: {
                        documentVM.goToPage(page)
                    }) {
                        Text("\(page)")
                            .font(.system(size: 12, weight: documentVM.currentPage == page ? .semibold : .regular))
                            .foregroundColor(documentVM.currentPage == page ? .white : .primary)
                            .frame(width: 28, height: 28)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(documentVM.currentPage == page ? Color.blue : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                if documentVM.totalPages > 5 {
                    Text("...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                    
                    Button(action: {
                        documentVM.goToPage(documentVM.totalPages)
                    }) {
                        Text("\(documentVM.totalPages)")
                            .font(.system(size: 12))
                            .foregroundColor(.primary)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(action: {
                    if documentVM.currentPage < documentVM.totalPages {
                        documentVM.goToPage(documentVM.currentPage + 1)
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(documentVM.currentPage < documentVM.totalPages ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .disabled(documentVM.currentPage >= documentVM.totalPages)
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            )
            
            Spacer(minLength: 12)
            
            HStack(spacing: 8) {
                Text("每页")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                
                Menu {
                    Button("10", action: {
                        documentVM.pageSize = 10
                        documentVM.currentPage = 1
                        Task { await documentVM.searchDocuments() }
                    })
                    Button("20", action: {
                        documentVM.pageSize = 20
                        documentVM.currentPage = 1
                        Task { await documentVM.searchDocuments() }
                    })
                    Button("50", action: {
                        documentVM.pageSize = 50
                        documentVM.currentPage = 1
                        Task { await documentVM.searchDocuments() }
                    })
                    Button("100", action: {
                        documentVM.pageSize = 100
                        documentVM.currentPage = 1
                        Task { await documentVM.searchDocuments() }
                    })
                } label: {
                    HStack(spacing: 4) {
                        Text("\(documentVM.pageSize)")
                            .font(.system(size: 12))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                
                Text("条")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }
}

extension NSAlert {
    static func showConfirmation(title: String, message: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.addButton(withTitle: "删除")
            alert.addButton(withTitle: "取消")
            alert.alertStyle = .warning
            
            let response = alert.runModal()
            completion(response == .alertFirstButtonReturn)
        }
    }
}
