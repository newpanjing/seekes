import Foundation
import SwiftData

/// SwiftData 中持久化的 Elasticsearch 连接配置。
@Model
final class StoredConnection {
    @Attribute(.unique) var id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String?
    var password: String?
    var isActive: Bool
    var sortOrder: Int

    init(connection: Connection, sortOrder: Int) {
        id = connection.id
        name = connection.name
        host = connection.host
        port = connection.port
        username = connection.username
        password = connection.password
        isActive = connection.isActive
        self.sortOrder = sortOrder
    }

    /// 将数据库记录转换为界面与网络层使用的值类型。
    var connection: Connection {
        Connection(
            id: id,
            name: name,
            host: host,
            port: port,
            username: username,
            password: password,
            isActive: isActive
        )
    }

    /// 同步更新连接记录，避免删除重建导致列表顺序变化。
    func update(from connection: Connection, sortOrder: Int) {
        name = connection.name
        host = connection.host
        port = connection.port
        username = connection.username
        password = connection.password
        isActive = connection.isActive
        self.sortOrder = sortOrder
    }
}

/// SwiftData 中唯一的应用偏好记录。
@Model
final class StoredAppSettings {
    @Attribute(.unique) var identifier: String
    var themeRawValue: String
    var languageRawValue: String
    var currentConnectionID: UUID?
    var favoriteIndexData: Data
    var hasMigratedLegacyData: Bool

    init(identifier: String, themeRawValue: String, languageRawValue: String, currentConnectionID: UUID?, favoriteIndexData: Data, hasMigratedLegacyData: Bool) {
        self.identifier = identifier
        self.themeRawValue = themeRawValue
        self.languageRawValue = languageRawValue
        self.currentConnectionID = currentConnectionID
        self.favoriteIndexData = favoriteIndexData
        self.hasMigratedLegacyData = hasMigratedLegacyData
    }
}
