import SwiftUI

struct AnalyzerView: View {
    @EnvironmentObject var indexVM: IndexViewModel
    @State private var analyzeMode: AnalyzeMode = .standard
    @State private var inputText: String = "Elasticsearch 是一个分布式的 RESTful 搜索和分析引擎"
    @State private var fieldName: String = ""
    @State private var selectedIndex: String = ""
    @State private var tokenizer: String = "standard"
    @State private var tokenFilters: String = "lowercase"
    @State private var isAnalyzing: Bool = false
    @State private var tokens: [AnalyzeToken] = []
    @State private var errorMessage: String?
    @State private var selectedToken: AnalyzeToken?
    
    enum AnalyzeMode: String, CaseIterable, Identifiable {
        case standard = "标准分词器"
        case ikSmart = "IK 智能分词"
        case ikMax = "IK 最细粒度"
        case simple = "简单分词器"
        case whitespace = "空格分词器"
        case keyword = "关键词分词器"
        case pattern = "正则分词器"
        case custom = "自定义分词器"
        case indexField = "索引字段分词"
        
        var id: String { rawValue }
        
        var analyzerName: String? {
            switch self {
            case .standard: return "standard"
            case .ikSmart: return "ik_smart"
            case .ikMax: return "ik_max_word"
            case .simple: return "simple"
            case .whitespace: return "whitespace"
            case .keyword: return "keyword"
            case .pattern: return "pattern"
            case .custom, .indexField: return nil
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Mode Selection
                    VStack(alignment: .leading, spacing: 8) {
                        Text("分词模式")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(AnalyzeMode.allCases) { mode in
                                    Button(action: {
                                        analyzeMode = mode
                                        tokens = []
                                    }) {
                                        Text(mode.rawValue)
                                            .font(.system(size: 12))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(analyzeMode == mode ? Color.blue : Color(NSColor.controlBackgroundColor))
                                            )
                                            .foregroundColor(analyzeMode == mode ? .white : .primary)
                                    }
                                    .buttonStyle(.plain)
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                    
                    // Additional options based on mode
                    if analyzeMode == .indexField {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("选择索引")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Picker("", selection: $selectedIndex) {
                                    Text("选择索引...").tag("")
                                    ForEach(indexVM.indices) { index in
                                        Text(index.name).tag(index.name)
                                    }
                                }
                                .frame(width: 250)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("字段名")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("例如: title", text: $fieldName)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 200)
                            }
                        }
                    } else if analyzeMode == .custom {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Tokenizer")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("tokenizer", text: $tokenizer)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 150)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Token Filters (逗号分隔)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("例如: lowercase, stop", text: $tokenFilters)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 280)
                            }
                        }
                    }
                    
                    // Input Text
                    VStack(alignment: .leading, spacing: 8) {
                        Text("待分词文本")
                            .font(.headline)
                        
                        TextEditor(text: $inputText)
                            .font(.system(size: 14))
                            .frame(minHeight: 80, maxHeight: 140)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Analyze Button
                    HStack {
                        Button(action: {
                            Task {
                                await performAnalyze()
                            }
                        }) {
                            Label(isAnalyzing ? "分词中" : "开始分词", systemImage: isAnalyzing ? "hourglass" : "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .contentShape(Rectangle())
                        .disabled(isAnalyzing || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .help("开始分词")
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    
                    // Results
                    if !tokens.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("分词结果")
                                    .font(.headline)
                                Text("(\(tokens.count) 个词条)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer(minLength: 0)
                            }
                            
                            // Token visualization
                            VStack(alignment: .leading, spacing: 8) {
                                Text("词条预览:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                TokenHighlightView(tokens: tokens, selectedToken: $selectedToken)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(NSColor.controlBackgroundColor))
                                    )
                            }
                            
                            // Token list table
                            VStack(spacing: 0) {
                                // Header
                                HStack {
                                    Text("#")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 40, alignment: .leading)
                                    Text("Token")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text("位置")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    Text("起始")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    Text("结束")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 60, alignment: .leading)
                                    Text("类型")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(width: 100, alignment: .leading)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.gray.opacity(0.1))
                                
                                Divider()
                                
                                // Token rows
                                ScrollView {
                                    LazyVStack(spacing: 0) {
                                        ForEach(Array(tokens.enumerated()), id: \.element.id) { index, token in
                                            TokenRowView(index: index + 1, token: token, isSelected: selectedToken?.id == token.id)
                                                .contentShape(Rectangle())
                                                .onTapGesture {
                                                    selectedToken = selectedToken?.id == token.id ? nil : token
                                                }
                                            Divider()
                                        }
                                    }
                                }
                                .frame(maxHeight: 300)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.textBackgroundColor))
        .onAppear {
            if selectedIndex.isEmpty, let firstIndex = indexVM.indices.first {
                selectedIndex = firstIndex.name
            }
            if indexVM.indices.isEmpty {
                Task {
                    await indexVM.loadIndices()
                    if selectedIndex.isEmpty, let firstIndex = indexVM.indices.first {
                        selectedIndex = firstIndex.name
                    }
                }
            }
        }
    }
    
    private func performAnalyze() async {
        guard ESAPIClient.shared.hasConnection else {
            errorMessage = "请先连接Elasticsearch"
            return
        }
        
        isAnalyzing = true
        errorMessage = nil
        tokens = []
        
        do {
            let response: AnalyzeResponse
            
            switch analyzeMode {
            case .indexField:
                guard !selectedIndex.isEmpty, !fieldName.isEmpty else {
                    errorMessage = "请选择索引并输入字段名"
                    isAnalyzing = false
                    return
                }
                response = try await ESAPIClient.shared.analyzeText(
                    index: selectedIndex,
                    text: inputText,
                    field: fieldName
                )
            case .custom:
                let filters = tokenFilters.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                response = try await ESAPIClient.shared.analyzeText(
                    text: inputText,
                    tokenizer: tokenizer,
                    filter: filters.isEmpty ? nil : filters
                )
            default:
                response = try await ESAPIClient.shared.analyzeText(
                    analyzer: analyzeMode.analyzerName,
                    text: inputText
                )
            }
            
            await MainActor.run {
                self.tokens = response.tokens
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        }
        
        isAnalyzing = false
    }
}

struct TokenHighlightView: View {
    let tokens: [AnalyzeToken]
    @Binding var selectedToken: AnalyzeToken?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 4) {
                ForEach(tokens) { token in
                    TokenChipView(token: token, isSelected: selectedToken?.id == token.id)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedToken = selectedToken?.id == token.id ? nil : token
                        }
                }
            }
        }
    }
}

struct TokenChipView: View {
    let token: AnalyzeToken
    let isSelected: Bool
    
    var body: some View {
        Text(token.token)
            .font(.system(size: 14, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.blue.opacity(0.4) : Color.blue.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
    }
}

struct TokenRowView: View {
    let index: Int
    let token: AnalyzeToken
    let isSelected: Bool
    
    var body: some View {
        HStack {
            Text("\(index)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 40, alignment: .leading)
            Text(token.token)
                .font(.system(size: 12, design: .monospaced))
                .fontWeight(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)
            Text("\(token.position)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text("\(token.startOffset)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text("\(token.endOffset)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(token.type)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.blue)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
                .frame(width: 100, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        
        let totalHeight = currentY + lineHeight
        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
