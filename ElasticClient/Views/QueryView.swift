import SwiftUI

/// 独立查询页，支持原始 DSL 与可视化条件，并展示高亮后的原始响应。
struct QueryView: View {
    @EnvironmentObject var indexVM: IndexViewModel
    @State private var queryMode: DocumentQueryMode = .json
    @State private var selectedIndex = ""
    @State private var rawQuery = Self.defaultQuery
    @State private var field = ""
    @State private var queryOperator: DocumentQueryOperator = .match
    @State private var value = ""
    @State private var analyzer = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var queryDuration: TimeInterval?
    @State private var rawResponse = ""
    @State private var formattedResponse = ""
    @State private var resultPresentation: QueryResultPresentation = .json
    @State private var inputPresentation: QueryInputPresentation = .editor

    private var fields: [IndexField] {
        indexVM.indexFieldsMap[selectedIndex] ?? []
    }

    /// 初始示例可直接执行，同时提示 JSON DSL 的基本结构。
    private static let defaultQuery = "{\n  \"query\": {\n    \"match_all\": {}\n  }\n}"
    private static let analyzers = ["standard", "simple", "whitespace", "keyword", "pattern", "english"]

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("索引", selection: $selectedIndex) {
                    Text("选择索引").tag("")
                    ForEach(indexVM.indices) { index in
                        Text(index.name).tag(index.name)
                    }
                }
                .frame(width: 220)
                Picker("模式", selection: $queryMode) {
                    ForEach(DocumentQueryMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .frame(width: 120)
                Spacer()
                Button {
                    Task { await executeQuery() }
                } label: {
                    Label(isLoading ? "查询中" : "查询", systemImage: isLoading ? "hourglass" : "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedIndex.isEmpty || isLoading)
                .help(isLoading ? "查询中" : "执行查询")
                Button {
                    formatQuery()
                } label: {
                    Label("格式化", systemImage: "text.alignleft")
                }
                .buttonStyle(.bordered)
                .help("格式化 JSON")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            if queryMode == .builder {
                HStack(spacing: 12) {
                    Picker("字段", selection: $field) {
                        Text("选择字段").tag("")
                        ForEach(fields) { item in
                            Text("\(item.name) (\(item.type))").tag(item.name)
                        }
                    }
                    .frame(width: 240)
                    Picker("操作", selection: $queryOperator) {
                        ForEach(DocumentQueryOperator.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }
                    .frame(width: 120)
                    TextField("查询值", text: $value)
                        .textFieldStyle(.roundedBorder)
                    if queryOperator == .match {
                        Picker("分词器", selection: $analyzer) {
                            Text("默认分词").tag("")
                            ForEach(Self.analyzers, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .frame(width: 160)
                    }
                    Button { rawQuery = generatedQuery } label: {
                        Label("生成 JSON", systemImage: "arrow.down.doc")
                    }
                    .buttonStyle(.bordered)
                    .help("生成 JSON")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            Divider()

            VSplitView {
                VStack(spacing: 0) {
                    HStack(alignment: .center) {
                        Text("查询条件")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Picker("输入展示", selection: $inputPresentation) {
                            ForEach(QueryInputPresentation.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    Divider()
                    if inputPresentation == .editor {
                        JSONEditor(text: $rawQuery)
                    } else {
                        CollapsibleJSONView(jsonText: rawQuery)
                    }
                }
                .frame(minHeight: 180)

                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 4) {
                        ForEach(QueryResultPresentation.allCases) { item in
                            Button {
                                resultPresentation = item
                            } label: {
                                Text(item.title)
                                    .font(.system(size: 12, weight: resultPresentation == item ? .semibold : .regular))
                                    .foregroundColor(resultPresentation == item ? .primary : .secondary)
                                    .padding(.horizontal, 12)
                                    .frame(height: 28)
                                    .background(resultPresentation == item ? Color(NSColor.selectedContentBackgroundColor).opacity(0.15) : .clear)
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    Divider()
                    if let errorMessage {
                        Text(errorMessage).foregroundColor(.red).padding(.horizontal, 12).padding(.top, 8)
                    }
                    if resultPresentation == .json {
                        CollapsibleJSONView(jsonText: formattedResponse)
                    } else {
                        ScrollView([.horizontal, .vertical]) {
                            Text(rawResponse)
                                .font(.system(size: 12, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                    }
                }
                .background(Color(NSColor.textBackgroundColor))
            }
            .frame(maxHeight: .infinity)

            Divider()
            HStack(spacing: 12) {
                Text(queryDuration.map { String(format: "查询用时 %.0f ms", $0 * 1000) } ?? "尚未执行查询")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .onAppear { selectInitialIndex() }
        .onChange(of: selectedIndex) { _, name in
            if let index = indexVM.indices.first(where: { $0.name == name }) {
                indexVM.selectIndex(index)
            }
        }
    }

    private var generatedQuery: String {
        let analyzerName = analyzer.trimmingCharacters(in: .whitespacesAndNewlines)
        let body: [String: Any]
        switch queryOperator {
        case .match:
            let matchValue: Any = analyzerName.isEmpty
                ? value
                : [QueryDSLKey.query: value, QueryDSLKey.analyzer: analyzerName]
            body = [QueryDSLKey.query: [QueryDSLKey.match: [field: matchValue]]]
        case .term: body = [QueryDSLKey.query: [QueryDSLKey.term: [field: [QueryDSLKey.value: value]]]]
        case .prefix: body = [QueryDSLKey.query: [QueryDSLKey.prefix: [field: [QueryDSLKey.value: value]]]]
        }
        guard let data = try? JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted]),
              let text = String(data: data, encoding: .utf8) else { return "{}" }
        return text
    }

    private func selectInitialIndex() {
        if selectedIndex.isEmpty, let first = indexVM.indices.first {
            selectedIndex = first.name
            indexVM.selectIndex(first)
        }
    }

    private func executeQuery() async {
        let startedAt = Date()
        isLoading = true
        errorMessage = nil
        if queryMode == .builder { rawQuery = generatedQuery }
        do {
            let data = try await ESAPIClient.shared.executeRawQuery(index: selectedIndex, dsl: rawQuery)
            rawResponse = String(decoding: data, as: UTF8.self)
            queryDuration = Date().timeIntervalSince(startedAt)
            let object = try JSONSerialization.jsonObject(with: data)
            let prettyData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted])
            formattedResponse = String(decoding: prettyData, as: UTF8.self)
        } catch {
            queryDuration = Date().timeIntervalSince(startedAt)
            rawResponse = error.localizedDescription
            formattedResponse = rawResponse
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func formatQuery() {
        guard let data = rawQuery.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted]) else {
            errorMessage = "JSON 格式错误"
            return
        }
        rawQuery = String(decoding: prettyData, as: UTF8.self)
        errorMessage = nil
    }
}

private enum QueryInputPresentation: String, CaseIterable, Identifiable {
    case editor
    case outline

    var id: String { rawValue }
    var title: String { self == .editor ? "编辑" : "折叠" }
}

private enum QueryResultPresentation: String, CaseIterable, Identifiable {
    case json
    case text

    var id: String { rawValue }
    var title: String { self == .json ? "JSON" : "原文" }
}

/// 查询 DSL 的固定字段名，避免 UI 自动拼接时出现无语义的字符串。
private enum QueryDSLKey {
    static let query = "query"
    static let match = "match"
    static let term = "term"
    static let prefix = "prefix"
    static let value = "value"
    static let analyzer = "analyzer"
}
