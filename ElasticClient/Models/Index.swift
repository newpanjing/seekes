import Foundation

struct IndexField: Identifiable {
    let id = UUID()
    let name: String
    let type: String
    let isSearchable: Bool
    let isAggregatable: Bool
}

struct Index: Identifiable, Codable, Hashable {
    
    //名字
    let name: String
    //健康
    var health: IndexHealth
    //状态
    var status: IndexStatus
    //文档数量
    var docsCount: Int
    //文档删除
    var docsDeleted: Int
    var storeSize: String
    var primaryShards: Int
    var replicaShards: Int
    var creationDate: Date?
    var version: String?
    
    var id: String { name }
    
    enum IndexHealth: String, Codable {
        case green = "green"
        case yellow = "yellow"
        case red = "red"
        
        var displayText: String {
            switch self {
            case .green: return "正常"
            case .yellow: return "警告"
            case .red: return "异常"
            }
        }
        
        var color: String {
            switch self {
            case .green: return "green"
            case .yellow: return "yellow"
            case .red: return "red"
            }
        }
    }
    
    enum IndexStatus: String, Codable {
        case open
        case close
    }
}
