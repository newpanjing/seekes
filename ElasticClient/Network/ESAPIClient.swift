import Foundation

struct ClusterInfo: Codable {
    let name: String
    let clusterName: String
    let version: ClusterVersion
    let tagline: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case clusterName = "cluster_name"
        case version
        case tagline
    }
}

struct ClusterVersion: Codable {
    let number: String
    let buildFlavor: String?
    let buildType: String?
    let buildHash: String?
    let buildDate: String?
    let buildSnapshot: Bool?
    let luceneVersion: String?
    let minimumWireCompatibilityVersion: String?
    let minimumIndexCompatibilityVersion: String?
    
    enum CodingKeys: String, CodingKey {
        case number
        case buildFlavor = "build_flavor"
        case buildType = "build_type"
        case buildHash = "build_hash"
        case buildDate = "build_date"
        case buildSnapshot = "build_snapshot"
        case luceneVersion = "lucene_version"
        case minimumWireCompatibilityVersion = "minimum_wire_compatibility_version"
        case minimumIndexCompatibilityVersion = "minimum_index_compatibility_version"
    }
}

struct IndexStats: Codable {
    let docs: IndexDocsStats
    let store: IndexStoreStats
    let indexing: IndexIndexingStats
    let search: IndexSearchStats
}

struct IndexDocsStats: Codable {
    let count: Int
    let deleted: Int
}

struct IndexStoreStats: Codable {
    let sizeInBytes: Int
    
    enum CodingKeys: String, CodingKey {
        case sizeInBytes = "size_in_bytes"
    }
}

struct IndexIndexingStats: Codable {
    let indexTotal: Int
    let indexTimeInMillis: Int
    let deleteTotal: Int
    
    enum CodingKeys: String, CodingKey {
        case indexTotal = "index_total"
        case indexTimeInMillis = "index_time_in_millis"
        case deleteTotal = "delete_total"
    }
}

struct IndexSearchStats: Codable {
    let queryTotal: Int
    let queryTimeInMillis: Int
    let fetchTotal: Int
    
    enum CodingKeys: String, CodingKey {
        case queryTotal = "query_total"
        case queryTimeInMillis = "query_time_in_millis"
        case fetchTotal = "fetch_total"
    }
}

struct IndexMapping: Codable {
    let mappings: [String: AnyCodable]?
    let settings: [String: AnyCodable]?
}

struct CreateIndexRequest {
    let name: String
    let mappings: [String: Any]?
    let settings: [String: Any]?
    
    init(name: String, mappings: [String: Any]? = nil, settings: [String: Any]? = nil) {
        self.name = name
        self.mappings = mappings
        self.settings = settings
    }
}

struct IndexSettings: Codable {
    let numberOfShards: String?
    let numberOfReplicas: String?
    
    enum CodingKeys: String, CodingKey {
        case numberOfShards = "number_of_shards"
        case numberOfReplicas = "number_of_replicas"
    }
}

enum ESError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(Int, String?)
    case decodingError(Error)
    case unauthorized
    case notFound
    case noConnectionConfigured
    case invalidBody
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "无效的响应"
        case .httpError(let code, let message):
            return "HTTP错误 \(code): \(message ?? "")"
        case .decodingError(let error):
            return "解析错误: \(error.localizedDescription)"
        case .unauthorized:
            return "未授权访问，请检查用户名密码"
        case .notFound:
            return "资源未找到"
        case .noConnectionConfigured:
            return "请先配置Elasticsearch连接"
        case .invalidBody:
            return "请求体格式错误"
        }
    }
}

class ESAPIClient {
    static let shared = ESAPIClient()
    
    private var connection: Connection?
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    init(session: URLSession = .shared) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = false
        config.allowsExpensiveNetworkAccess = true
        config.allowsConstrainedNetworkAccess = true
        self.session = URLSession(configuration: config)
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }
    
    func configure(with connection: Connection) {
        self.connection = connection
    }
    
    var hasConnection: Bool {
        connection != nil
    }
    
    // MARK: - Cluster APIs
    func testConnection() async throws -> Bool {
        do {
            let _: ClusterInfo = try await request(path: "/", method: "GET")
            return true
        } catch ESError.decodingError(_) {
            // Even if we can't parse the full response, if we got a 200 OK, connection is valid
            let data = try await rawRequest(path: "/", method: "GET")
            // Check if we got any valid JSON response
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        }
    }
    
    func getClusterHealth() async throws -> [String: Any] {
        let data = try await rawRequest(path: "/_cluster/health", method: "GET")
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ESError.invalidResponse
        }
        return json
    }
    
    func getNodesInfo() async throws -> [String: Any] {
        let data = try await rawRequest(path: "/_nodes", method: "GET")
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ESError.invalidResponse
        }
        return json
    }
    
    func getClusterStats() async throws -> [String: Any] {
        let data = try await rawRequest(path: "/_cluster/stats", method: "GET")
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ESError.invalidResponse
        }
        return json
    }
    
    func getClusterInfo() async throws -> ClusterInfo {
        do {
            return try await request(path: "/", method: "GET")
        } catch ESError.decodingError(_) {
            // Try to manually parse basic info if full decode fails
            let data = try await rawRequest(path: "/", method: "GET")
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ESError.invalidResponse
            }
            
            let name = json["name"] as? String ?? "unknown"
            let clusterName = json["cluster_name"] as? String ?? "elasticsearch"
            let tagline = json["tagline"] as? String ?? "You Know, for Search"
            let versionNumber = (json["version"] as? [String: Any])?["number"] as? String ?? "0.0.0"
            
            return ClusterInfo(
                name: name,
                clusterName: clusterName,
                version: ClusterVersion(
                    number: versionNumber,
                    buildFlavor: nil,
                    buildType: nil,
                    buildHash: nil,
                    buildDate: nil,
                    buildSnapshot: nil,
                    luceneVersion: nil,
                    minimumWireCompatibilityVersion: nil,
                    minimumIndexCompatibilityVersion: nil
                ),
                tagline: tagline
            )
        }
    }
    
    // MARK: - Index APIs
    func fetchIndices() async throws -> [Index] {
        let catIndices: [CatIndexResponse] = try await request(
            path: "/_cat/indices",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "format", value: "json"),
                URLQueryItem(name: "h", value: "health,status,index,docs.count,docs.deleted,store.size,pri,rep,creation.date,version")
            ]
        )
        
        return catIndices.compactMap { catIndex in
            guard let healthValue = catIndex.health,
                  let statusValue = catIndex.status,
                  let health = Index.IndexHealth(rawValue: healthValue),
                  let status = Index.IndexStatus(rawValue: statusValue),
                  let docsCount = Int(catIndex.docsCount),
                  let primaryShards = Int(catIndex.pri),
                  let replicaShards = Int(catIndex.rep) else {
                return nil
            }
            
            var creationDate: Date?
            if let dateStr = catIndex.creationDate, let timestamp = Double(dateStr) {
                creationDate = Date(timeIntervalSince1970: timestamp / 1000)
            }
            
            return Index(
                name: catIndex.index,
                health: health,
                status: status,
                docsCount: docsCount,
                docsDeleted: Int(catIndex.docsDeleted) ?? 0,
                storeSize: formatBytes(catIndex.storeSize ?? "0"),
                primaryShards: primaryShards,
                replicaShards: replicaShards,
                creationDate: creationDate,
                version: nil
            )
        }
    }
    
    func getIndexStats(indexName: String) async throws -> IndexStats {
        let data = try await rawRequest(path: "/\(indexName)/_stats", method: "GET")
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let indices = root[IndexStatsJSONKey.indices] as? [String: Any],
              let index = indices[indexName] as? [String: Any],
              let total = index[IndexStatsJSONKey.total] as? [String: Any] else {
            throw ESError.invalidResponse
        }

        let docs = total[IndexStatsJSONKey.docs] as? [String: Any] ?? [:]
        let store = total[IndexStatsJSONKey.store] as? [String: Any] ?? [:]
        let indexing = total[IndexStatsJSONKey.indexing] as? [String: Any] ?? [:]
        let search = total[IndexStatsJSONKey.search] as? [String: Any] ?? [:]
        return IndexStats(
            docs: IndexDocsStats(
                count: statsInteger(docs[IndexStatsJSONKey.count]),
                deleted: statsInteger(docs[IndexStatsJSONKey.deleted])
            ),
            store: IndexStoreStats(sizeInBytes: statsInteger(store[IndexStatsJSONKey.sizeInBytes])),
            indexing: IndexIndexingStats(
                indexTotal: statsInteger(indexing[IndexStatsJSONKey.indexTotal]),
                indexTimeInMillis: statsInteger(indexing[IndexStatsJSONKey.indexTimeInMillis]),
                deleteTotal: statsInteger(indexing[IndexStatsJSONKey.deleteTotal])
            ),
            search: IndexSearchStats(
                queryTotal: statsInteger(search[IndexStatsJSONKey.queryTotal]),
                queryTimeInMillis: statsInteger(search[IndexStatsJSONKey.queryTimeInMillis]),
                fetchTotal: statsInteger(search[IndexStatsJSONKey.fetchTotal])
            )
        )
    }

    /// Elasticsearch 数值字段可能为 JSON 数值或字符串，统一转换为统计模型使用的整数。
    private func statsInteger(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) ?? 0 }
        return 0
    }
    
    func createIndex(name: String, mappings: [String: Any]? = nil, settings: [String: Any]? = nil) async throws -> Bool {
        var body: [String: Any] = [:]
        if let settings = settings {
            body["settings"] = settings
        }
        if let mappings = mappings {
            body["mappings"] = mappings
        }
        
        let _: [String: AnyCodable] = try await request(
            path: "/\(name)",
            method: "PUT",
            body: body.isEmpty ? nil : body
        )
        return true
    }
    
    func deleteIndex(name: String) async throws -> Bool {
        let _: [String: AnyCodable] = try await request(path: "/\(name)", method: "DELETE")
        return true
    }
    
    func getIndexMapping(indexName: String) async throws -> Data {
        return try await rawRequest(path: "/\(indexName)/_mapping", method: "GET")
    }
    
    func getIndexSettings(indexName: String) async throws -> Data {
        return try await rawRequest(path: "/\(indexName)/_settings", method: "GET")
    }

    /// 获取索引级健康详情，用于展示 Elasticsearch 返回的真实告警原因。
    func getIndexHealthDetails(indexName: String) async throws -> Data {
        return try await rawRequest(
            path: "/_cluster/health/\(indexName)",
            method: "GET",
            queryItems: [URLQueryItem(name: "level", value: "shards")]
        )
    }
    
    // MARK: - Document APIs
    func searchDocuments(index: String, query: [String: Any]? = nil, from: Int = 0, size: Int = 10, sort: [[String: Any]]? = nil) async throws -> SearchResponse {
        var body: [String: Any] = [
            "from": from,
            "size": size
        ]
        body["query"] = query ?? ["match_all": [:]]
        if let sort = sort {
            body["sort"] = sort
        }
        
        return try await request(
            path: "/\(index)/_search",
            method: "POST",
            body: body
        )
    }
    
    func getDocument(index: String, id: String) async throws -> Document {
        return try await request(path: "/\(index)/_doc/\(id)", method: "GET")
    }
    
    func indexDocument(index: String, id: String? = nil, document: [String: Any]) async throws -> Document {
        let path: String
        let method: String
        if let id {
            path = "/\(index)/_doc/\(id)"
            method = "PUT"
        } else {
            path = "/\(index)/_doc"
            method = "POST"
        }
        return try await request(path: path, method: method, body: document)
    }
    
    func updateDocument(index: String, id: String, document: [String: Any]) async throws -> Bool {
        let body: [String: Any] = ["doc": document]
        let _: [String: AnyCodable] = try await request(
            path: "/\(index)/_update/\(id)",
            method: "POST",
            body: body
        )
        return true
    }
    
    func deleteDocument(index: String, id: String) async throws -> Bool {
        let _: [String: AnyCodable] = try await request(
            path: "/\(index)/_doc/\(id)",
            method: "DELETE"
        )
        return true
    }
    
    func globalSearch(query: String, size: Int = 50) async throws -> SearchResponse {
        var queryBody: [String: Any]
        
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            queryBody = ["query": ["match_all": [:]]]
        } else {
            queryBody = [
                "query": [
                    "multi_match": [
                        "query": query,
                        "fields": ["*"],
                        "lenient": true
                    ]
                ]
            ]
        }
        
        return try await request(path: "/_search", method: "POST", 
                               queryItems: [URLQueryItem(name: "size", value: "\(size)")], 
                               body: queryBody)
    }
    
    func bulkImport(index: String, documents: [[String: Any]], idField: String? = nil) async throws -> Bool {
        var bulkBody = ""
        for doc in documents {
            var action: [String: Any] = ["index": [:]]
            if let idField = idField, let id = doc[idField] {
                action["index"] = ["_id": "\(id)"]
            }
            if let actionData = try? JSONSerialization.data(withJSONObject: action),
               let actionStr = String(data: actionData, encoding: .utf8),
               let docData = try? JSONSerialization.data(withJSONObject: doc),
               let docStr = String(data: docData, encoding: .utf8) {
                bulkBody += actionStr + "\n" + docStr + "\n"
            }
        }
        
        guard let bodyData = bulkBody.data(using: .utf8) else {
            throw ESError.invalidBody
        }
        
        var request = try buildRequest(path: "/\(index)/_bulk", method: "POST")
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        let (data, response) = try await session.data(for: request)
        let (_, _) = try validateResponse(data: data, response: response)
        return true
    }
    
    // MARK: - Query DSL
    func executeQuery(index: String, dsl: String) async throws -> SearchResponse {
        guard let bodyData = dsl.data(using: .utf8) else {
            throw ESError.invalidBody
        }
        
        var request = try buildRequest(path: "/\(index)/_search", method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        
        let (data, response) = try await session.data(for: request)
        let (_, data2) = try validateResponse(data: data, response: response)
        return try decoder.decode(SearchResponse.self, from: data2)
    }

    /// 执行原始 Query DSL，并保留服务端原始 JSON 结果供界面高亮展示。
    func executeRawQuery(index: String, dsl: String) async throws -> Data {
        guard let bodyData = dsl.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: bodyData)) != nil else {
            throw ESError.invalidBody
        }
        var request = try buildRequest(path: "/\(index)/_search", method: "POST")
        request.httpBody = bodyData
        let (data, response) = try await session.data(for: request)
        let (_, responseData) = try validateResponse(data: data, response: response)
        return responseData
    }
    
    func executeConsoleQuery(_ dsl: String) async throws -> Data {
        // Parse the DSL to handle multi-line console queries
        let lines = dsl.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.trimmingCharacters(in: .whitespaces).starts(with: "//") }
        
        guard lines.count >= 2 else {
            // Try as single request
            return try await rawRequest(path: "/_search", method: "GET")
        }
        
        // First line is method and path
        let firstLine = lines[0].trimmingCharacters(in: .whitespaces)
        let components = firstLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard components.count >= 2 else {
            throw ESError.invalidBody
        }
        
        let method = components[0].uppercased()
        let path = components[1]
        
        // Join remaining lines as body
        let bodyLines = lines.dropFirst().joined(separator: "\n")
        
        if method == "GET" && !bodyLines.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // GET with body - send as POST
            return try await rawRequest(path: path, method: "POST", bodyString: bodyLines)
        }
        
        return try await rawRequest(path: path, method: method, bodyString: bodyLines)
    }
    
    // MARK: - Analyze API
    func analyzeText(index: String? = nil, analyzer: String? = nil, text: String, field: String? = nil, tokenizer: String? = nil, filter: [String]? = nil) async throws -> AnalyzeResponse {
        var body: [String: Any] = ["text": text]
        
        if let analyzer = analyzer {
            body["analyzer"] = analyzer
        }
        if let field = field {
            body["field"] = field
        }
        if let tokenizer = tokenizer {
            body["tokenizer"] = tokenizer
        }
        if let filter = filter {
            body["filter"] = filter
        }
        
        let path: String
        if let index = index, !index.isEmpty {
            path = "/\(index)/_analyze"
        } else {
            path = "/_analyze"
        }
        
        let requestData = try JSONSerialization.data(withJSONObject: body, options: [])
        let requestBody = String(decoding: requestData, as: UTF8.self)
        let data = try await rawRequest(path: path, method: "POST", bodyString: requestBody)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ESError.invalidResponse
        }

        // Analyze 插件可能省略 offset/type/position，按可选字段读取，避免一条坏 token 使整页失败。
        let tokenValues = json["tokens"] as? [[String: Any]] ?? []
        let tokens = tokenValues.enumerated().compactMap { offset, value -> AnalyzeToken? in
            guard let token = value["token"] as? String else { return nil }
            let start = integerValue(value["start_offset"]) ?? 0
            let end = integerValue(value["end_offset"]) ?? start
            let position = integerValue(value["position"]) ?? offset
            return AnalyzeToken(
                token: token,
                startOffset: start,
                endOffset: end,
                type: value["type"] as? String ?? "unknown",
                position: position
            )
        }
        return AnalyzeResponse(tokens: tokens)
    }

    private func integerValue(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        if let value = value as? String { return Int(value) }
        return nil
    }
    
    // MARK: - Helper Methods
    private func formatBytes(_ sizeStr: String) -> String {
        // Elasticsearch returns human-readable sizes like "45.6mb"
        return sizeStr.uppercased().replacingOccurrences(of: "B", with: " B")
    }
    
    private func buildURL(path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        guard let connection = connection else {
            throw ESError.noConnectionConfigured
        }
        
        // Normalize host - ensure it has a scheme
        var host = connection.host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !host.hasPrefix("http://") && !host.hasPrefix("https://") {
            host = "http://" + host
        }
        
        // Build base URL
        var urlString = "\(host):\(connection.port)"
        
        // Add path
        var requestPath = path
        if !requestPath.starts(with: "/") {
            requestPath = "/" + requestPath
        }
        urlString += requestPath
        
        guard var components = URLComponents(string: urlString) else {
            throw ESError.invalidURL
        }
        
        if let queryItems = queryItems, !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw ESError.invalidURL
        }
        
        return url
    }
    
    private func buildRequest(path: String, method: String, queryItems: [URLQueryItem]? = nil, body: [String: Any]? = nil) throws -> URLRequest {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        }
        
        return request
    }
    
    private func addAuthHeaders(to request: inout URLRequest) {
        if let username = connection?.username, let password = connection?.password,
           !username.isEmpty && !password.isEmpty {
            let credentials = "\(username):\(password)".data(using: .utf8)?.base64EncodedString()
            if let credentials = credentials {
                request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            }
        }
    }
    
    private func validateResponse(data: Data, response: URLResponse) throws -> (HTTPURLResponse, Data) {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ESError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw ESError.unauthorized
        }
        
        if httpResponse.statusCode == 404 {
            // Try to parse error message
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let reason = error["reason"] as? String {
                throw ESError.httpError(404, reason)
            }
            throw ESError.notFound
        }
        
        if httpResponse.statusCode >= 400 {
            let message = errorMessage(from: data)
            throw ESError.httpError(httpResponse.statusCode, message)
        }
        
        return (httpResponse, data)
    }

    /// 优先提取 root_cause，避免只将 Elasticsearch 的 "all shards failed" 展示给用户。
    private func errorMessage(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if let error = json["error"] as? String { return error }
        guard let error = json["error"] as? [String: Any] else { return nil }
        if let rootCause = (error["root_cause"] as? [[String: Any]])?.first,
           let reason = rootCause["reason"] as? String {
            return reason
        }
        if let failedShard = (error["failed_shards"] as? [[String: Any]])?.first,
           let reason = (failedShard["reason"] as? [String: Any])?["reason"] as? String {
            return reason
        }
        return error["reason"] as? String ?? error["type"] as? String
    }
    
    private func request<T: Decodable>(path: String, method: String, queryItems: [URLQueryItem]? = nil, body: [String: Any]? = nil) async throws -> T {
        let request = try buildRequest(path: path, method: method, queryItems: queryItems, body: body)
        let (data, response) = try await session.data(for: request)
        let (_, data2) = try validateResponse(data: data, response: response)
        
        do {
            return try decoder.decode(T.self, from: data2)
        } catch {
            throw ESError.decodingError(error)
        }
    }
    
    private func rawRequest(path: String, method: String, queryItems: [URLQueryItem]? = nil, bodyString: String? = nil) async throws -> Data {
        let url = try buildURL(path: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        addAuthHeaders(to: &request)
        
        if let bodyString = bodyString, !bodyString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.httpBody = bodyString.data(using: .utf8)
        }
        
        let (data, response) = try await session.data(for: request)
        let (_, data2) = try validateResponse(data: data, response: response)
        return data2
    }
}

// Helper structs for decoding
private struct CatIndexResponse: Codable {
    let health: String?
    let status: String?
    let index: String
    let docsCount: String
    let docsDeleted: String
    let storeSize: String?
    let pri: String
    let rep: String
    let creationDate: String?
    let version: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        health = try container.decodeIfPresent(String.self, forKey: .health)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        index = try container.decodeIfPresent(String.self, forKey: .index) ?? ""
        docsCount = try container.decodeIfPresent(String.self, forKey: .docsCount) ?? "0"
        docsDeleted = try container.decodeIfPresent(String.self, forKey: .docsDeleted) ?? "0"
        storeSize = try container.decodeIfPresent(String.self, forKey: .storeSize)
        pri = try container.decodeIfPresent(String.self, forKey: .pri) ?? "0"
        rep = try container.decodeIfPresent(String.self, forKey: .rep) ?? "0"
        creationDate = try container.decodeIfPresent(String.self, forKey: .creationDate)
        version = try container.decodeIfPresent(String.self, forKey: .version)
    }

    private enum CodingKeys: String, CodingKey {
        case health, status, index, pri, rep, version
        case docsCount = "docs.count"
        case docsDeleted = "docs.deleted"
        case storeSize = "store.size"
        case creationDate = "creation.date"
    }
}

/// Elasticsearch 索引统计响应中的固定字段名。
private enum IndexStatsJSONKey {
    static let indices = "indices"
    static let total = "total"
    static let docs = "docs"
    static let store = "store"
    static let indexing = "indexing"
    static let search = "search"
    static let count = "count"
    static let deleted = "deleted"
    static let sizeInBytes = "size_in_bytes"
    static let indexTotal = "index_total"
    static let indexTimeInMillis = "index_time_in_millis"
    static let deleteTotal = "delete_total"
    static let queryTotal = "query_total"
    static let queryTimeInMillis = "query_time_in_millis"
    static let fetchTotal = "fetch_total"
}
