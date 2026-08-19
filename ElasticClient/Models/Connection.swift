import Foundation

struct Connection: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var username: String?
    var password: String?
    var isActive: Bool
    
    init(id: UUID = UUID(), name: String, host: String = "http://localhost", port: Int = 9200, username: String? = nil, password: String? = nil, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.password = password
        self.isActive = isActive
    }
    
    var baseURL: String {
        var normalizedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedHost.hasPrefix("http://") && !normalizedHost.hasPrefix("https://") {
            normalizedHost = "http://" + normalizedHost
        }
        return "\(normalizedHost):\(port)"
    }
}
