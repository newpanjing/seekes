import SwiftUI

/// 数据浏览工具栏的统一尺寸，避免同一操作区出现不同规格的按钮。
private enum DocumentToolbarLayout {
    static let controlHeight: CGFloat = 24
    static let iconSize: CGFloat = 11
    static let controlSpacing: CGFloat = 4
}

struct DocumentSearchBarView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    @EnvironmentObject var indexVM: IndexViewModel
    @State private var showCreateDocument = false

    private var fields: [IndexField] {
        guard let indexName = indexVM.selectedIndex?.name else { return [] }
        return indexVM.indexFieldsMap[indexName] ?? []
    }
    
    var body: some View {
        HStack(spacing: DocumentToolbarLayout.controlSpacing) {
            Picker("查询模式", selection: $documentVM.queryMode) {
                ForEach(DocumentQueryMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .labelsHidden()
            .font(.system(size: DocumentToolbarLayout.iconSize))
            .frame(width: 104, height: DocumentToolbarLayout.controlHeight)

            if documentVM.queryMode == .json {
                TextField("输入查询 DSL（JSON 格式），留空查询所有文档", text: $documentVM.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(.horizontal, 10)
                    .frame(height: DocumentToolbarLayout.controlHeight)
                    .background(queryInputBackground)
            } else {
                Picker("字段", selection: $documentVM.queryField) {
                    Text("选择字段").tag("")
                    ForEach(fields) { field in
                        Text("\(field.name) (\(field.type))").tag(field.name)
                    }
                }
                .font(.system(size: DocumentToolbarLayout.iconSize))
                .frame(width: 180, height: DocumentToolbarLayout.controlHeight)
                Picker("操作符", selection: $documentVM.queryOperator) {
                    ForEach(DocumentQueryOperator.allCases) { item in
                        Text(item.title).tag(item)
                    }
                }
                .font(.system(size: DocumentToolbarLayout.iconSize))
                .frame(width: 105, height: DocumentToolbarLayout.controlHeight)
                TextField("查询值", text: $documentVM.queryValue)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: DocumentToolbarLayout.iconSize))
                    .frame(height: DocumentToolbarLayout.controlHeight)
            }
            
            Button(action: {
                Task {
                    await documentVM.searchDocuments()
                }
            }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: DocumentToolbarLayout.iconSize, weight: .medium))
                    .frame(width: DocumentToolbarLayout.controlHeight, height: DocumentToolbarLayout.controlHeight)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
            .help("搜索文档")
            
            Button(action: {
                documentVM.searchQuery = ""
                documentVM.queryField = ""
                documentVM.queryValue = ""
                Task {
                    await documentVM.searchDocuments()
                }
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: DocumentToolbarLayout.iconSize, weight: .medium))
                    .frame(width: DocumentToolbarLayout.controlHeight, height: DocumentToolbarLayout.controlHeight)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("重置查询")

            Button {
                showCreateDocument = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: DocumentToolbarLayout.iconSize, weight: .medium))
                    .frame(width: DocumentToolbarLayout.controlHeight, height: DocumentToolbarLayout.controlHeight)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .help("新建文档")
        }
        .sheet(isPresented: $showCreateDocument) {
            CreateDocumentSheet(isPresented: $showCreateDocument)
                .environmentObject(documentVM)
        }
    }

    private var queryInputBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(NSColor.controlBackgroundColor))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

/// 为当前索引创建单个 JSON 文档，支持指定或自动生成文档 ID。
private struct CreateDocumentSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var documentVM: DocumentViewModel
    @State private var documentID = ""
    @State private var documentJSON = "{\n\n}"
    @State private var contentMode: CreateDocumentContentMode = .json

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("新建文档").font(.headline)
                Spacer()
                Button { isPresented = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.bordered)
                    .help("关闭")
            }
            .padding(12)
            Divider()
            VStack(alignment: .leading, spacing: 8) {
                Text("文档 ID（可选）")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                TextField("留空则自动生成", text: $documentID)
                    .textFieldStyle(.roundedBorder)
                    .frame(height: 28)
                if let error = documentVM.errorMessage {
                    Text(error).font(.caption).foregroundColor(.red)
                }
            }
            .padding(12)
            HStack {
                Text("文档内容")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Picker("内容格式", selection: $contentMode) {
                    ForEach(CreateDocumentContentMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 150)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            if contentMode == .json {
                JSONEditor(text: $documentJSON)
            } else {
                ConsoleEditor(text: $documentJSON)
            }
            Divider()
            HStack {
                Button { isPresented = false } label: { Image(systemName: "xmark") }
                    .buttonStyle(.bordered)
                    .help("取消")
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button {
                    Task {
                        if await documentVM.createDocument(id: documentID, jsonText: documentJSON) {
                            isPresented = false
                        }
                    }
                } label: { Image(systemName: "checkmark") }
                .buttonStyle(.borderedProminent)
                .help("创建")
                .disabled(documentVM.isLoading)
                .keyboardShortcut(.defaultAction)
            }
            .padding(12)
        }
        .frame(width: 620, height: 460)
    }
}

private enum CreateDocumentContentMode: String, CaseIterable, Identifiable {
    case json
    case text

    var id: String { rawValue }
    var title: String { self == .json ? "JSON 编辑器" : "原文" }
}

struct DocumentListView: View {
    @EnvironmentObject var documentVM: DocumentViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("共 \(documentVM.totalResults.formatted()) 条")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Button {
                    Task { await documentVM.searchDocuments() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("刷新结果")

                Button {
                    Task { await documentVM.exportAllDocuments() }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("导出全部结果")

                Button {
                    documentVM.exportSelectedDocument()
                } label: {
                    Image(systemName: "doc.badge.arrow.down")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(documentVM.selectedDocument == nil)
                .help("导出选中文档")
                
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
            .padding(.vertical, 5)
            
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
                            .contextMenu {
                                Button("查看") { documentVM.selectDocument(doc) }
                                Button("编辑") {
                                    documentVM.selectDocument(doc)
                                    documentVM.startEditing()
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    documentVM.selectDocument(doc)
                                    NSAlert.showConfirmation(
                                        title: "删除文档",
                                        message: "确定要删除文档 \(doc.id) 吗？此操作不可撤销。"
                                    ) { confirmed in
                                        if confirmed {
                                            Task { await documentVM.deleteDocument() }
                                        }
                                    }
                                }
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
        .padding(.vertical, 7)
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
                
                HStack(spacing: DocumentToolbarLayout.controlSpacing) {
                    if documentVM.isEditing {
                        Button(action: {
                            documentVM.cancelEditing()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: DocumentToolbarLayout.iconSize, weight: .medium))
                                .frame(width: DocumentToolbarLayout.controlHeight, height: DocumentToolbarLayout.controlHeight)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .help("取消编辑")

                        Button(action: {
                            Task {
                                await documentVM.saveDocument()
                            }
                        }) {
                            Image(systemName: "checkmark")
                                .font(.system(size: DocumentToolbarLayout.iconSize, weight: .medium))
                                .frame(width: DocumentToolbarLayout.controlHeight, height: DocumentToolbarLayout.controlHeight)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                        .help("保存文档")
                    } else {
                        Button(action: {
                            documentVM.startEditing()
                        }) {
                            Image(systemName: "pencil")
                                .font(.system(size: DocumentToolbarLayout.iconSize, weight: .medium))
                                .frame(width: DocumentToolbarLayout.controlHeight, height: DocumentToolbarLayout.controlHeight)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .help("编辑文档")

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
                            Image(systemName: "trash")
                                .font(.system(size: DocumentToolbarLayout.iconSize, weight: .medium))
                                .frame(width: DocumentToolbarLayout.controlHeight, height: DocumentToolbarLayout.controlHeight)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(.red)
                        .help("删除文档")

                        Button(action: {
                            documentVM.copyDocumentToClipboard()
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: DocumentToolbarLayout.iconSize, weight: .medium))
                                .frame(width: DocumentToolbarLayout.controlHeight, height: DocumentToolbarLayout.controlHeight)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .help("复制文档 JSON")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            
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
                    CollapsibleJSONView(jsonText: documentVM.documentJSONString())
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

            if let duration = documentVM.lastQueryDuration {
                Text("ES \(documentVM.took) ms · 总计 \(Int((duration * 1000).rounded())) ms")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
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
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help("上一页")
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
                            .foregroundColor(documentVM.currentPage == page ? .accentColor : .primary)
                            .frame(width: 36, height: 32)
                            .contentShape(Rectangle())
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(documentVM.currentPage == page ? Color.accentColor.opacity(0.12) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(documentVM.currentPage == page ? Color.accentColor.opacity(0.45) : .clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
                
                if endPage < documentVM.totalPages {
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
                            .frame(width: 36, height: 32)
                            .contentShape(Rectangle())
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
                        .frame(width: 36, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .help("下一页")
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
