import Foundation
import MultipeerConnectivity

final class PeerAddressStore {
    static let shared = PeerAddressStore()
    
    private var addresses: [MCPeerID: PeerInfo] = [:]
    private var deviceIDToPeerID: [String: MCPeerID] = [:]
    private let queue = DispatchQueue(label: "com.airshout.peeraddressstore")
    
    private init() {}
    
    func save(peerID: MCPeerID, info: PeerInfo) {
        queue.async { [weak self] in
            self?.addresses[peerID] = info
            self?.deviceIDToPeerID[info.deviceID] = peerID
        }
    }
    
    func get(peerID: MCPeerID) -> PeerInfo? {
        queue.sync { addresses[peerID] }
    }
    
    func getByDeviceID(_ deviceID: String) -> PeerInfo? {
        queue.sync {
            guard let peerID = deviceIDToPeerID[deviceID] else { return nil }
            return addresses[peerID]
        }
    }
    
    func updateAddress(peerID: MCPeerID, ip: String, port: Int) {
        queue.async { [weak self] in
            self?.addresses[peerID]?.ip = ip
            self?.addresses[peerID]?.port = port
        }
    }
    
    func remove(peerID: MCPeerID) {
        queue.async { [weak self] in
            if let info = self?.addresses[peerID] {
                self?.deviceIDToPeerID.removeValue(forKey: info.deviceID)
            }
            self?.addresses.removeValue(forKey: peerID)
        }
    }
    
    func clear() {
        queue.async { [weak self] in
            self?.addresses.removeAll()
            self?.deviceIDToPeerID.removeAll()
        }
    }
}
