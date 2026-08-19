import Foundation
import Combine

@MainActor
class SearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [DocumentHit] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var totalResults: Int = 0
    @Published var selectedResult: DocumentHit?
    @Published var resultDetail: Document?
    @Published var took: Int = 0
    
    func performSearch() async {
        guard ESAPIClient.shared.hasConnection else {
            errorMessage = "请先连接Elasticsearch"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await ESAPIClient.shared.globalSearch(query: searchText)
            searchResults = response.hits.hits
            totalResults = response.hits.total.value
            took = response.took
            selectedResult = searchResults.first
            
            if let first = searchResults.first {
                resultDetail = try await ESAPIClient.shared.getDocument(index: first.index, id: first.id)
            } else {
                resultDetail = nil
            }
        } catch {
            errorMessage = error.localizedDescription
            searchResults = []
            totalResults = 0
        }
        
        isLoading = false
    }
    
    func selectResult(_ hit: DocumentHit) {
        selectedResult = hit
        Task {
            do {
                resultDetail = try await ESAPIClient.shared.getDocument(index: hit.index, id: hit.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func getResultJSON() -> String {
        guard let doc = resultDetail,
              let source = doc.source else {
            return ""
        }
        
        var dict: [String: Any] = [:]
        for (key, value) in source {
            dict[key] = value.value
        }
        
        if let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }
        return ""
    }
}
