import Foundation
import Combine
import SwiftUI

class IndexViewModel: ObservableObject {
    @Published var indices: [Index] = []
    @Published var selectedIndex: Index?
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedTab: IndexTab = .data {
        didSet {
            Task {
                await loadIndexDetails()
            }
        }
    }
    @Published var clusterInfo: ClusterInfo?
    @Published var indexStats: IndexStats?
    @Published var mappingData: Data?
    @Published var settingsData: Data?
    @Published var fields: [IndexField] = []
    @Published var indexFieldsMap: [String: [IndexField]] = [:]
    @Published var expandedIndices: Set<String> = []
    @Published var loadingFieldsForIndex: String?
    @Published var showCreateIndexSheet: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    var filteredIndices: [Index] {
        if searchText.isEmpty {
            return indices
        }
        return indices.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    init() {
        NotificationCenter.default.publisher(for: .connectionStatusChanged)
            .sink { [weak self] _ in
                Task {
                    await self?.loadIndices()
                }
            }
            .store(in: &cancellables)
        
        Task {
            await loadIndices()
        }
    }
    
    @MainActor
    func loadIndices() async {
        guard ESAPIClient.shared.hasConnection else {
            indices = []
            selectedIndex = nil
            clusterInfo = nil
            indexFieldsMap = [:]
            expandedIndices = []
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            async let indicesTask = ESAPIClient.shared.fetchIndices()
            async let clusterTask = ESAPIClient.shared.getClusterInfo()
            
            indices = try await indicesTask
            clusterInfo = try await clusterTask
            
            if selectedIndex == nil, let first = indices.first {
                selectedIndex = first
                await loadIndexDetails()
            } else if let selected = selectedIndex,
                      let updated = indices.first(where: { $0.name == selected.name }) {
                selectedIndex = updated
            } else if let first = indices.first {
                selectedIndex = first
                await loadIndexDetails()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    @MainActor
    func selectIndex(_ index: Index) {
        selectedIndex = index
        Task {
            await loadIndexDetails()
        }
    }
    
    @MainActor
    func toggleExpandIndex(_ index: Index) {
        if expandedIndices.contains(index.name) {
            expandedIndices.remove(index.name)
        } else {
            expandedIndices.insert(index.name)
            if indexFieldsMap[index.name] == nil {
                Task {
                    await loadFieldsForIndex(index.name)
                }
            }
        }
    }
    
    @MainActor
    func loadFieldsForIndex(_ indexName: String) async {
        loadingFieldsForIndex = indexName
        do {
            let data = try await ESAPIClient.shared.getIndexMapping(indexName: indexName)
            let parsedFields = parseFields(from: data, indexName: indexName)
            indexFieldsMap[indexName] = parsedFields
        } catch {
            // ignore error for fields loading
        }
        loadingFieldsForIndex = nil
    }
    
    @MainActor
    func loadIndexDetails() async {
        guard let index = selectedIndex else { return }
        
        do {
            switch selectedTab {
            case .data:
                // Documents are loaded by DocumentViewModel, also load fields for expanded view
                if indexFieldsMap[index.name] == nil {
                    Task {
                        await loadFieldsForIndex(index.name)
                    }
                }
            case .stats:
                indexStats = try await ESAPIClient.shared.getIndexStats(indexName: index.name)
            case .mapping:
                mappingData = try await ESAPIClient.shared.getIndexMapping(indexName: index.name)
                fields = parseFields(from: mappingData, indexName: index.name)
                indexFieldsMap[index.name] = fields
            case .settings:
                settingsData = try await ESAPIClient.shared.getIndexSettings(indexName: index.name)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    private func parseFields(from data: Data?, indexName: String) -> [IndexField] {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let indexMapping = json[indexName] as? [String: Any] ?? json.values.first as? [String: Any],
              let mappings = indexMapping["mappings"] as? [String: Any] else {
            return []
        }

        // 兼容 typeless mapping 与旧版 _doc/type 包装，并递归展开对象字段。
        let properties = (mappings["properties"] as? [String: Any])
            ?? (mappings.values.compactMap { $0 as? [String: Any] }
                .compactMap { $0["properties"] as? [String: Any] }.first)
        guard let properties else { return [] }
        return flattenFields(properties)
    }

    private func flattenFields(_ properties: [String: Any], prefix: String = "") -> [IndexField] {
        properties.keys.sorted().flatMap { (name: String) -> [IndexField] in
            guard let config = properties[name] as? [String: Any] else { return [] }
            let fullName = prefix.isEmpty ? name : "\(prefix).\(name)"
            let type = config["type"] as? String ?? "object"
            let field = IndexField(name: fullName, type: type, isSearchable: true, isAggregatable: type != "text")
            let nested = (config["properties"] as? [String: Any]).map { flattenFields($0, prefix: fullName) } ?? []
            return [field] + nested
        }
    }
    
    @MainActor
    func refresh() async {
        indexFieldsMap = [:]
        await loadIndices()
    }
    
    @MainActor
    func deleteIndex(_ index: Index) async {
        isLoading = true
        do {
            _ = try await ESAPIClient.shared.deleteIndex(name: index.name)
            indices.removeAll { $0.name == index.name }
            indexFieldsMap.removeValue(forKey: index.name)
            expandedIndices.remove(index.name)
            if selectedIndex?.name == index.name {
                selectedIndex = indices.first
                await loadIndexDetails()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    @MainActor
    func createIndex(name: String, numberOfShards: Int = 1, numberOfReplicas: Int = 1) async {
        isLoading = true
        do {
            let settings: [String: Any] = [
                "number_of_shards": numberOfShards,
                "number_of_replicas": numberOfReplicas
            ]
            _ = try await ESAPIClient.shared.createIndex(name: name, settings: settings)
            await loadIndices()
            showCreateIndexSheet = false
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func tabChanged(to tab: IndexTab) {
        selectedTab = tab
        Task {
            await loadIndexDetails()
        }
    }
}
