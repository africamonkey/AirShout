import Foundation

struct PeerInfo: Identifiable, Equatable {
    let deviceID: String
    let displayName: String
    var ip: String?
    var port: Int?
    
    var id: String { deviceID }
    
    var isComplete: Bool {
        ip != nil && port != nil
    }
}

enum PeerMessage: Codable {
    case addressInfo(deviceID: String, displayName: String, localIP: String, port: Int)
    case requestAddress(deviceID: String)
    
    enum CodingKeys: String, CodingKey {
        case type
        case deviceID
        case displayName
        case localIP
        case port
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "addressInfo":
            let deviceID = try container.decode(String.self, forKey: .deviceID)
            let displayName = try container.decode(String.self, forKey: .displayName)
            let localIP = try container.decode(String.self, forKey: .localIP)
            let port = try container.decode(Int.self, forKey: .port)
            self = .addressInfo(deviceID: deviceID, displayName: displayName, localIP: localIP, port: port)
        case "requestAddress":
            let deviceID = try container.decode(String.self, forKey: .deviceID)
            self = .requestAddress(deviceID: deviceID)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unknown message type")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .addressInfo(let deviceID, let displayName, let localIP, let port):
            try container.encode("addressInfo", forKey: .type)
            try container.encode(deviceID, forKey: .deviceID)
            try container.encode(displayName, forKey: .displayName)
            try container.encode(localIP, forKey: .localIP)
            try container.encode(port, forKey: .port)
        case .requestAddress(let deviceID):
            try container.encode("requestAddress", forKey: .type)
            try container.encode(deviceID, forKey: .deviceID)
        }
    }
}
