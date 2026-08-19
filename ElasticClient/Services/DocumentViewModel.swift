import Foundation
import Combine
import SwiftUI
import AppKit

class DocumentViewModel: ObservableObject {
    @Published var documents: [DocumentHit] = []
    @Published var selectedDocument: DocumentHit?
    @Published var selectedDocumentDetail: Document?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var searchQuery: String = ""
    @Published var queryMode: DocumentQueryMode = .json
    @Published var queryField: String = ""
    @Published var queryOperator: DocumentQueryOperator = .match
    @Published var queryValue: String = ""
    @Published var currentPage: Int = 1
    @Published var totalResults: Int = 0
    @Published var pageSize: Int = 10
    @Published var took: Int = 0
    @Published var documentOperation: DocumentOperation = .view
    @Published var isEditing: Bool = false
    @Published var showOperationPanel: Bool = true
    @Published var sortField: String = "_id"
    @Published var sortOrder: String = "asc"
    @Published var editJsonText: String = ""
    @Published var showImportSheet: Bool = false
    @Published var consoleText: String = "GET /_cat/indices?v"
    @Published var consoleResult: NSAttributedString?
    @Published var consoleIsLoading: Bool = false
    @Published var isConnected: Bool = false
    
    private var currentIndex: String?
    private var cancellables = Set<AnyCancellable>()
    
    var totalPages: Int {
        max(1, (totalResults + pageSize - 1) / pageSize)
    }
    
    init() {
        NotificationCenter.default.publisher(for: .indexSelected)
            .sink { [weak self] notification in
                if let indexName = notification.object as? String {
                    self?.currentIndex = indexName
                    self?.currentPage = 1
                    Task {
                        await self?.searchDocuments()
                    }
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .connectionStatusChanged)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.checkConnectionStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkConnectionStatus() {
        // We'll check by making a simple API call or rely on ESAPIClient having a configured connection
        isConnected = ESAPIClient.shared.hasConnection
    }
    
    @MainActor
    func selectDocument(_ doc: DocumentHit) {
        selectedDocument = doc
        documentOperation = .view
        isEditing = false
        Task {
            await loadDocumentDetail(index: doc.index, id: doc.id)
        }
    }
    
    @MainActor
    func loadDocumentDetail(index: String, id: String) async {
        do {
            selectedDocumentDetail = try await ESAPIClient.shared.getDocument(index: index, id: id)
            if let source = selectedDocumentDetail?.source,
               let jsonData = try? JSONSerialization.data(withJSONObject: sourceDictionary(from: source), options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                editJsonText = jsonString
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func sourceDictionary(from source: [String: AnyCodable]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in source {
            result[key] = value.value
        }
        return result
    }
    
    @MainActor
    func searchDocuments() async {
        checkConnectionStatus()
        guard let indexName = currentIndex, isConnected else {
            documents = []
            totalResults = 0
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let from = (currentPage - 1) * pageSize
            let sort: [[String: Any]] = [[sortField: ["order": sortOrder]]]
            
            let query: [String: Any]?
            if queryMode == .builder {
                query = makeBuilderQuery()
            } else if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let data = searchQuery.data(using: .utf8),
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let q = parsed["query"] as? [String: Any] {
                    query = q
                } else {
                    query = parsed
                }
            } else if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errorMessage = "JSON 格式错误"
                isLoading = false
                return
            } else {
                query = nil
            }
            
            let response = try await ESAPIClient.shared.searchDocuments(
                index: indexName,
                query: query,
                from: from,
                size: pageSize,
                sort: sort
            )
            
            documents = response.hits.hits
            totalResults = response.hits.total.value
            took = response.took
            
            if selectedDocument == nil || !documents.contains(where: { $0.id == selectedDocument?.id }) {
                selectedDocument = documents.first
                if let first = documents.first {
                    await loadDocumentDetail(index: first.index, id: first.id)
                } else {
                    selectedDocumentDetail = nil
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }

    /// 根据 UI 中选择的字段、操作符和值构建 Elasticsearch Query DSL。
    private func makeBuilderQuery() -> [String: Any]? {
        let field = queryField.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = queryValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !field.isEmpty, !value.isEmpty else { return nil }
        switch queryOperator {
        case .match: return ["match": [field: value]]
        case .term: return ["term": [field: ["value": value]]]
        case .prefix: return ["prefix": [field: ["value": value]]]
        }
    }
    
    @MainActor
    func saveDocument() async {
        guard let doc = selectedDocument else { return }
        
        isLoading = true
        do {
            guard let jsonData = editJsonText.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
                errorMessage = "JSON格式错误"
                isLoading = false
                return
            }
            
            var source = json
            source.removeValue(forKey: "_index")
            source.removeValue(forKey: "_id")
            source.removeValue(forKey: "_version")
            source.removeValue(forKey: "_seq_no")
            source.removeValue(forKey: "_primary_term")
            source.removeValue(forKey: "found")
            source.removeValue(forKey: "_source")
            
            _ = try await ESAPIClient.shared.updateDocument(index: doc.index, id: doc.id, document: source)
            await loadDocumentDetail(index: doc.index, id: doc.id)
            await searchDocuments()
            isEditing = false
            documentOperation = .view
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    @MainActor
    func deleteDocument() async {
        guard let doc = selectedDocument else { return }
        
        isLoading = true
        do {
            _ = try await ESAPIClient.shared.deleteDocument(index: doc.index, id: doc.id)
            documents.removeAll { $0.id == doc.id }
            selectedDocument = documents.first
            totalResults = max(0, totalResults - 1)
            if let first = selectedDocument {
                await loadDocumentDetail(index: first.index, id: first.id)
            } else {
                selectedDocumentDetail = nil
                editJsonText = ""
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func getDocumentJSON() -> NSAttributedString {
        guard let doc = selectedDocumentDetail,
              let source = doc.source else {
            return NSAttributedString(string: "选择一个文档查看详情", attributes: [.foregroundColor: NSColor.secondaryLabelColor])
        }
        
        let sourceDict = sourceDictionary(from: source)
        return JSONFormatter.format(sourceDict)
    }
    
    func startEditing() {
        isEditing = true
        documentOperation = .update
    }
    
    func cancelEditing() {
        isEditing = false
        documentOperation = .view
        if let doc = selectedDocument {
            Task {
                await loadDocumentDetail(index: doc.index, id: doc.id)
            }
        }
    }
    
    @MainActor
    func goToPage(_ page: Int) {
        guard page >= 1 && page <= totalPages else { return }
        currentPage = page
        Task {
            await searchDocuments()
        }
    }
    
    func setOperation(_ op: DocumentOperation) {
        documentOperation = op
        isEditing = (op == .update)
    }
    
    func copyDocumentToClipboard() {
        guard let doc = selectedDocumentDetail,
              let source = doc.source else { return }
        
        let sourceDict = sourceDictionary(from: source)
        if let jsonData = try? JSONSerialization.data(withJSONObject: sourceDict, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(jsonString, forType: .string)
        }
    }
    
    @MainActor
    func executeConsoleQuery() async {
        checkConnectionStatus()
        guard isConnected else {
            errorMessage = "请先连接Elasticsearch"
            return
        }
        
        consoleIsLoading = true
        do {
            let data = try await ESAPIClient.shared.executeConsoleQuery(consoleText)
            if let json = try? JSONSerialization.jsonObject(with: data, options: []),
               let prettyData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                consoleResult = JSONFormatter.formatJSONString(prettyString)
            } else {
                consoleResult = NSAttributedString(string: String(data: data, encoding: .utf8) ?? "")
            }
        } catch {
            consoleResult = NSAttributedString(string: error.localizedDescription, attributes: [.foregroundColor: NSColor.systemRed])
        }
        consoleIsLoading = false
    }
}
