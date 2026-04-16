import Foundation
import Network
import Combine
import MultipeerConnectivity

final class TCPConnectionManager: ObservableObject {
    enum Role {
        case sender
        case receiver
    }
    
    enum ConnectionState: Equatable {
        case disconnected
        case listening(port: Int)
        case connecting
        case connected
        case failed(String)
        
        static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
            switch (lhs, rhs) {
            case (.disconnected, .disconnected): return true
            case (.listening(let l), .listening(let r)): return l == r
            case (.connecting, .connecting): return true
            case (.connected, .connected): return true
            case (.failed(let l), .failed(let r)): return l == r
            default: return false
            }
        }
    }
    
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var connectedPeers: [MCPeerID] = []
    
    private let role: Role
    private let queue = DispatchQueue(label: "com.airshout.tcpconnection")
    
    // Receiver (Server) properties
    private var listener: NWListener?
    private struct ConnectionInfo {
        let connection: NWConnection
        let peerID: MCPeerID
    }
    private var connections: [ConnectionInfo] = []
    private var currentListeningPort: Int?
    private var currentListeningIP: String?
    private var nextPeerID: Int = 0
    
    // Sender (Client) properties
    private var senderConnection: NWConnection?
    
    // Audio callbacks
    var onAudioReceived: ((Data, MCPeerID) -> Void)?
    var onPeerDisconnected: ((MCPeerID) -> Void)?
    
    init(role: Role) {
        self.role = role
    }
    
    // MARK: - Receiver (Server) Methods
    
    func startListening() async throws -> (ip: String, port: Int) {
        let port = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            queue.async {
                do {
                    let parameters = NWParameters.tcp
                    parameters.allowLocalEndpointReuse = true
                    
                    self.listener = try NWListener(using: parameters)
                    
                    self.listener?.stateUpdateHandler = { [weak self] state in
                        switch state {
                        case .ready:
                            if let port = self?.listener?.port?.rawValue {
                                continuation.resume(returning: Int(port))
                            }
                        case .failed(let error):
                            continuation.resume(throwing: error)
                        default:
                            break
                        }
                    }
                    
                    self.listener?.newConnectionHandler = { [weak self] connection in
                        self?.handleNewConnection(connection)
                    }
                    
                    self.listener?.start(queue: self.queue)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        let ip = NetworkMonitor.shared.getLocalIPAddress() ?? "127.0.0.1"
        currentListeningIP = ip
        currentListeningPort = port
        
        await MainActor.run {
            self.connectionState = .listening(port: port)
        }
        
        return (ip, port)
    }
    
    func stopListening() {
        queue.async { [weak self] in
            self?.listener?.cancel()
            self?.listener = nil
            
            for info in self?.connections ?? [] {
                info.connection.cancel()
            }
            self?.connections.removeAll()
            
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
            }
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        let peerID = MCPeerID(displayName: "peer-\(nextPeerID)")
        nextPeerID += 1
        
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(on: connection, peerID: peerID)
            case .failed, .cancelled:
                self?.removeConnection(for: peerID)
            default:
                break
            }
        }
        connection.start(queue: queue)
        
        queue.async { [weak self] in
            self?.connections.append(ConnectionInfo(connection: connection, peerID: peerID))
            
            DispatchQueue.main.async {
                if !(self?.connectedPeers.contains(peerID) ?? false) {
                    self?.connectedPeers.append(peerID)
                }
            }
        }
    }
    
    private func receiveData(on connection: NWConnection, peerID: MCPeerID) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                DispatchQueue.main.async {
                    self?.onAudioReceived?(data, peerID)
                }
            }
            
            if !isComplete && error == nil {
                self?.receiveData(on: connection, peerID: peerID)
            } else if isComplete || error != nil {
                self?.removeConnection(for: peerID)
            }
        }
    }
    
    private func removeConnection(for peerID: MCPeerID) {
        queue.async { [weak self] in
            self?.connections.removeAll { $0.peerID == peerID }
            
            DispatchQueue.main.async {
                self?.connectedPeers.removeAll { $0 == peerID }
                self?.onPeerDisconnected?(peerID)
            }
        }
    }
    
    func sendAudioToPeer(_ peerID: MCPeerID, data: Data) {
        queue.async { [weak self] in
            guard let info = self?.connections.first(where: { $0.peerID == peerID }) else { return }
            info.connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("Failed to send audio to \(peerID): \(error)")
                }
            })
        }
    }
    
    func sendAudioToAllPeers(_ data: Data) {
        queue.async { [weak self] in
            for info in self?.connections ?? [] {
                info.connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("Failed to send audio to \(info.peerID): \(error)")
                    }
                })
            }
        }
    }
    
    // MARK: - Sender (Client) Methods
    
    func connect(to address: PeerInfo) async throws {
        guard let ip = address.ip, let port = address.port else {
            throw TCPError.invalidAddress
        }
        
        await MainActor.run {
            self.connectionState = .connecting
        }
        
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(ip), port: NWEndpoint.Port(integerLiteral: UInt16(port)))
        let parameters = NWParameters.tcp
        senderConnection = NWConnection(to: endpoint, using: parameters)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [weak self] in
                self?.senderConnection?.stateUpdateHandler = { [weak self] state in
                    switch state {
                    case .ready:
                        DispatchQueue.main.async {
                            self?.connectionState = .connected
                        }
                        continuation.resume()
                        self?.startReceivingAudio()
                    case .failed(let error):
                        DispatchQueue.main.async {
                            self?.connectionState = .failed(error.localizedDescription)
                        }
                        continuation.resume(throwing: error)
                    case .cancelled:
                        DispatchQueue.main.async {
                            self?.connectionState = .disconnected
                        }
                    default:
                        break
                    }
                }
                self?.senderConnection?.start(queue: self?.queue ?? DispatchQueue.main)
            }
        }
    }
    
    func disconnect() {
        queue.async { [weak self] in
            self?.senderConnection?.cancel()
            self?.senderConnection = nil
            
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
            }
        }
    }
    
    private func startReceivingAudio() {
        senderConnection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                let dummyPeerID = MCPeerID(displayName: "sender")
                DispatchQueue.main.async {
                    self?.onAudioReceived?(data, dummyPeerID)
                }
            }
            
            if !isComplete && error == nil {
                self?.startReceivingAudio()
            }
        }
    }
    
    func sendAudio(_ data: Data) {
        queue.async { [weak self] in
            self?.senderConnection?.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("Failed to send audio: \(error)")
                }
            })
        }
    }
    
    var isConnected: Bool {
        if case .connected = connectionState {
            return true
        }
        return false
    }
}

enum TCPError: Error, LocalizedError {
    case invalidAddress
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "无效的地址"
        case .connectionFailed:
            return "连接失败"
        }
    }
}
