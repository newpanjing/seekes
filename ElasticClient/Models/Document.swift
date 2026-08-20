import Foundation

struct Document: Identifiable, Codable, Hashable {
    let id: String
    let index: String
    var version: Int?
    var source: [String: AnyCodable]?
    var found: Bool?
    var seqNo: Int?
    var primaryTerm: Int?
    
    enum CodingKeys: String, CodingKey {
        case id = "_id"
        case index = "_index"
        case version = "_version"
        case source = "_source"
        case found
        case seqNo = "_seq_no"
        case primaryTerm = "_primary_term"
    }
}

struct DocumentHit: Codable, Identifiable, Hashable {
    let index: String
    let id: String
    let score: Double?
    let source: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case index = "_index"
        case id = "_id"
        case score = "_score"
        case source = "_source"
    }
}

struct SearchResponse: Codable {
    let took: Int
    let timedOut: Bool
    let hits: SearchHits
    
    enum CodingKeys: String, CodingKey {
        case took
        case timedOut = "timed_out"
        case hits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        took = try container.decodeIfPresent(Int.self, forKey: .took) ?? 0
        timedOut = try container.decodeIfPresent(Bool.self, forKey: .timedOut) ?? false
        hits = try container.decodeIfPresent(SearchHits.self, forKey: .hits) ?? SearchHits(total: SearchTotal(value: 0, relation: "eq"), maxScore: nil, hits: [])
    }
}

struct SearchHits: Codable {
    let total: SearchTotal
    let maxScore: Double?
    let hits: [DocumentHit]
    
    enum CodingKeys: String, CodingKey {
        case total
        case maxScore = "max_score"
        case hits
    }

    init(total: SearchTotal, maxScore: Double?, hits: [DocumentHit]) {
        self.total = total
        self.maxScore = maxScore
        self.hits = hits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        total = try container.decodeIfPresent(SearchTotal.self, forKey: .total) ?? SearchTotal(value: 0, relation: "eq")
        maxScore = try container.decodeIfPresent(Double.self, forKey: .maxScore)
        hits = try container.decodeIfPresent([DocumentHit].self, forKey: .hits) ?? []
    }
}

struct SearchTotal: Codable {
    let value: Int
    let relation: String

    init(value: Int, relation: String) {
        self.value = value
        self.relation = relation
    }

    init(from decoder: Decoder) throws {
        let single = try decoder.singleValueContainer()
        if let value = try? single.decode(Int.self) {
            self.init(value: value, relation: "eq")
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            value: try container.decodeIfPresent(Int.self, forKey: .value) ?? 0,
            relation: try container.decodeIfPresent(String.self, forKey: .relation) ?? "eq"
        )
    }

    private enum CodingKeys: String, CodingKey {
        case value
        case relation
    }
}

struct AnalyzeResponse: Codable {
    let tokens: [AnalyzeToken]

    init(tokens: [AnalyzeToken]) {
        self.tokens = tokens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tokens = (try? container.decode([AnalyzeToken].self, forKey: .tokens)) ?? []
    }
}

struct AnalyzeToken: Codable, Identifiable {
    let token: String
    let startOffset: Int
    let endOffset: Int
    let type: String
    let position: Int
    
    var id: String { "\(position)-\(token)" }

    init(token: String, startOffset: Int, endOffset: Int, type: String, position: Int) {
        self.token = token
        self.startOffset = startOffset
        self.endOffset = endOffset
        self.type = type
        self.position = position
    }
    
    enum CodingKeys: String, CodingKey {
        case token
        case startOffset = "start_offset"
        case endOffset = "end_offset"
        case type
        case position
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        token = try container.decode(String.self, forKey: .token)
        startOffset = Self.decodeInt(container, key: .startOffset) ?? 0
        endOffset = Self.decodeInt(container, key: .endOffset) ?? startOffset
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        position = Self.decodeInt(container, key: .position) ?? 0
    }

    private static func decodeInt(_ container: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        if let value = try? container.decode(String.self, forKey: key) { return Int(value) }
        return nil
    }
}

struct AnyCodable: Codable, Hashable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if container.decodeNil() {
            self.value = NSNull()
        } else if let bool = try? container.decode(Bool.self) {
            self.value = bool
        } else if let int = try? container.decode(Int.self) {
            self.value = int
        } else if let double = try? container.decode(Double.self) {
            self.value = double
        } else if let string = try? container.decode(String.self) {
            self.value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            self.value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            self.value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable cannot decode value")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case is NSNull:
            try container.encodeNil()
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            let context = EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable cannot encode value")
            throw EncodingError.invalidValue(value, context)
        }
    }
    
    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        return String(describing: lhs.value) == String(describing: rhs.value)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(String(describing: value))
    }
}
