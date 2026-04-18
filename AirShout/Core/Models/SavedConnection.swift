import Foundation

struct SavedConnection: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var ip: String
    var port: UInt16
    var lastConnected: Date?

    init(id: UUID = UUID(), name: String, ip: String, port: UInt16, lastConnected: Date? = nil) {
        self.id = id
        self.name = name
        self.ip = ip
        self.port = port
        self.lastConnected = lastConnected
    }
}

class SavedConnectionStorage {
    static let shared = SavedConnectionStorage()
    private let key = "savedConnections"

    private init() {}

    func load() -> [SavedConnection] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode([SavedConnection].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ connections: [SavedConnection]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(connections)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save connections: \(error)")
        }
    }

    func add(_ connection: SavedConnection) {
        var connections = load()
        connections.append(connection)
        save(connections)
    }

    func remove(at index: Int) {
        var connections = load()
        guard index < connections.count else { return }
        connections.remove(at: index)
        save(connections)
    }

    func update(_ connection: SavedConnection) {
        var connections = load()
        if let idx = connections.firstIndex(where: { $0.id == connection.id }) {
            connections[idx] = connection
            save(connections)
        }
    }
}