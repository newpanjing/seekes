import Foundation

enum SidebarItem: Hashable, Identifiable {
    case connection
    case overview
    case indices
    case console
    case analyzer
    case favorite(String)
    case settings
    
    var id: String {
        switch self {
        case .connection: return "connection"
        case .overview: return "overview"
        case .indices: return "indices"
        case .console: return "console"
        case .analyzer: return "analyzer"
        case .favorite(let name): return "favorite_\(name)"
        case .settings: return "settings"
        }
    }
    
    var title: String {
        switch self {
        case .connection: return "连接"
        case .overview: return "概览"
        case .indices: return "索引"
        case .console: return "控制台"
        case .analyzer: return "分词测试"
        case .favorite(let name): return name
        case .settings: return "设置"
        }
    }
    
    var iconName: String {
        switch self {
        case .connection: return "network"
        case .overview: return "square.grid.2x2"
        case .indices: return "tablecells"
        case .console: return "wrench.and.screwdriver"
        case .analyzer: return "text.viewfinder"
        case .favorite: return "square.grid.3x3"
        case .settings: return "gearshape"
        }
    }
}

enum IndexTab: String, CaseIterable, Identifiable {
    case data = "数据浏览"
    case mapping = "映射"
    case settings = "设置"
    case stats = "统计信息"
    
    var id: String { rawValue }
}

enum DocumentOperation {
    case view
    case update
    case delete
}

/// 文档查询的输入方式。
enum DocumentQueryMode: String, CaseIterable, Identifiable {
    case json
    case builder

    var id: String { rawValue }

    var title: String {
        switch self {
        case .json: return "JSON 查询"
        case .builder: return "条件查询"
        }
    }
}

/// 支持自动拼接的基础查询操作符。
enum DocumentQueryOperator: String, CaseIterable, Identifiable {
    case match
    case term
    case prefix

    var id: String { rawValue }

    var title: String {
        switch self {
        case .match: return "匹配"
        case .term: return "精确匹配"
        case .prefix: return "前缀"
        }
    }
}
