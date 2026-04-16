# AirShout P2P TCP 重构实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 P2P 传输从 MC (MultipeerConnectivity) 迁移到 TCP，实现更可靠的后台音频传输支持。

**Architecture:** MC 用于设备发现和地址交换，TCP 用于实际音频数据传输。

**Tech Stack:** Swift, Network.framework (TCP), MultipeerConnectivity, AVFAudio, SwiftUI

---

## 核心设计决策

| 项目 | 决策 |
|------|------|
| 设备唯一标识符 | UUID，随机生成，App 重启保持，换设备才变 |
| 设备命名 | `UIDevice.current.name` |
| 设备选择 | 用户从列表中选择一个接收端 |
| 多接收端行为 | 用户选择后建立 1v1 连接 |
| 同时发送端数量 | 只允许 1 个（独占控制） |
| 地址通知时机 | 接收端启动时 + IP 变化时 |
| 重连策略 | MC 获取最新 → 缓存重试 → 失败提示 |
| Phase 4 后续做 | 后台支持后续实现 |
| Fallback | 不保留，TCP 失败则传输失败 |

---

## PeerMessage 定义

```swift
struct PeerInfo {
    let deviceID: String      // UUID，唯一标识
    let displayName: String   // UIDevice.current.name
    var ip: String?           // 当前 IP 地址
    var port: Int?            // TCP 监听端口
}

enum PeerMessage {
    case addressInfo(deviceID: String, displayName: String, localIP: String, port: Int)
    case requestAddress(deviceID: String)
}
```

| 消息类型 | 用途 |
|---------|------|
| `addressInfo` | 接收端广播自己的 PeerInfo (deviceID + displayName + IP:Port) |
| `requestAddress` | 发送端请求接收端地址（用于重连） |

---

## 文件结构

```
AirShout/Features/P2P/
├── Messages/
│   └── PeerMessage.swift           # Task 1.1
├── DeviceIdentifier.swift           # Task 1.2
├── PeerAddressStore.swift           # Task 1.3
├── NetworkMonitor.swift            # Task 1.4
├── TCPConnectionManager.swift     # Task 2.1
├── P2PAudioManager.swift           # Task 3.1, 3.2
├── P2PViewModel.swift              # Task 3.3
└── P2PView.swift                   # Task 3.4
```

---

## Phase 1: 基础组件

### Task 1.1: PeerMessage 定义

**Files:**
- Create: `AirShout/Features/P2P/Messages/PeerMessage.swift`

```swift
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

enum PeerMessage {
    case addressInfo(deviceID: String, displayName: String, localIP: String, port: Int)
    case requestAddress(deviceID: String)
}
```

- [ ] **Step 1: 创建目录**

```bash
mkdir -p AirShout/Features/P2P/Messages
```

- [ ] **Step 2: 创建 PeerMessage.swift**

```swift
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

enum PeerMessage {
    case addressInfo(deviceID: String, displayName: String, localIP: String, port: Int)
    case requestAddress(deviceID: String)
}
```

- [ ] **Step 3: 提交**

```bash
git add AirShout/Features/P2P/Messages/PeerMessage.swift
git commit -m "feat: add PeerMessage and PeerInfo types"
```

---

### Task 1.2: DeviceIdentifier

**Files:**
- Create: `AirShout/Features/P2P/DeviceIdentifier.swift`

| 功能 | 说明 |
|------|------|
| 生成 UUID | 首次启动时生成 |
| 持久化存储 | 保存到 UserDefaults |
| 获取 | `DeviceIdentifier.current` 返回当前设备 ID |

```swift
import Foundation

final class DeviceIdentifier {
    static let shared = DeviceIdentifier()
    
    private enum Keys {
        static let deviceID = "com.airshout.p2p.deviceID"
    }
    
    private init() {}
    
    var currentDeviceID: String {
        if let existingID = UserDefaults.standard.string(forKey: Keys.deviceID) {
            return existingID
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: Keys.deviceID)
        return newID
    }
}
```

- [ ] **Step 1: 创建 DeviceIdentifier.swift**

```swift
import Foundation

final class DeviceIdentifier {
    static let shared = DeviceIdentifier()
    
    private enum Keys {
        static let deviceID = "com.airshout.p2p.deviceID"
    }
    
    private init() {}
    
    var currentDeviceID: String {
        if let existingID = UserDefaults.standard.string(forKey: Keys.deviceID) {
            return existingID
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: Keys.deviceID)
        return newID
    }
}
```

- [ ] **Step 2: 提交**

```bash
git add AirShout/Features/P2P/DeviceIdentifier.swift
git commit -m "feat: add DeviceIdentifier for persistent UUID"
```

---

### Task 1.3: PeerAddressStore

**Files:**
- Create: `AirShout/Features/P2P/PeerAddressStore.swift`

```swift
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
```

- [ ] **Step 1: 创建 PeerAddressStore.swift**

使用上面的代码。

- [ ] **Step 2: 提交**

```bash
git add AirShout/Features/P2P/PeerAddressStore.swift
git commit -m "feat: add PeerAddressStore for caching peer addresses"
```

---

### Task 1.4: NetworkMonitor

**Files:**
- Create: `AirShout/Features/P2P/NetworkMonitor.swift`

使用 `NWPathMonitor` 监听网络路径变化，检测本机 IP 是否改变。

```swift
import Foundation
import Network

final class NetworkMonitor {
    static let shared = NetworkMonitor()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.airshout.networkmonitor")
    
    var onIPChanged: ((String) -> Void)?
    private(set) var currentIP: String?
    
    private init() {}
    
    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            let newIP = self?.getLocalIPAddress()
            DispatchQueue.main.async {
                if let newIP = newIP, newIP != self?.currentIP {
                    self?.currentIP = newIP
                    self?.onIPChanged?(newIP)
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    func stop() {
        monitor.cancel()
    }
    
    func getCurrentIPAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        
        defer { freeifaddrs(ifaddr) }
        
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family
            
            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                               &hostname, socklen_t(hostname.count),
                               nil, 0, NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        
        return address
    }
}
```

- [ ] **Step 1: 创建 NetworkMonitor.swift**

使用上面的代码。

- [ ] **Step 2: 提交**

```bash
git add AirShout/Features/P2P/NetworkMonitor.swift
git commit -m "feat: add NetworkMonitor for IP change detection"
```

---

## Phase 2: TCP 连接层

### Task 2.1: TCPConnectionManager

**Files:**
- Create: `AirShout/Features/P2P/TCPConnectionManager.swift`

这是一个复杂的组件，包含接收端（Server）和发送端（Client）功能。

```swift
import Foundation
import Network
import Combine

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
    }
    
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var connectedPeers: [MCPeerID] = []
    
    private let role: Role
    private let queue = DispatchQueue(label: "com.airshout.tcpconnection")
    
    // Receiver (Server) properties
    private var listener: NWListener?
    private var connections: [MCPeerID: NWConnection] = [:]
    private var peerIDByConnection: [NWConnection: MCPeerID] = [:]
    private var currentListeningPort: Int?
    private var currentListeningIP: String?
    
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
        
        let ip = NetworkMonitor.shared.getCurrentIPAddress() ?? "127.0.0.1"
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
            
            for (_, connection) in self?.connections ?? [:] {
                connection.cancel()
            }
            self?.connections.removeAll()
            self?.peerIDByConnection.removeAll()
            
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
            }
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.receiveData(on: connection)
            case .failed, .cancelled:
                self?.removeConnection(connection)
            default:
                break
            }
        }
        connection.start(queue: queue)
    }
    
    private func receiveData(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                if let peerID = self?.peerIDByConnection[connection] {
                    DispatchQueue.main.async {
                        self?.onAudioReceived?(data, peerID)
                    }
                }
                self?.receiveData(on: connection)
            }
            
            if isComplete || error != nil {
                self?.removeConnection(connection)
            }
        }
    }
    
    private func removeConnection(_ connection: NWConnection) {
        queue.async { [weak self] in
            if let peerID = self?.peerIDByConnection[connection] {
                self?.connections.removeValue(forKey: peerID)
                self?.peerIDByConnection.removeValue(forKey: connection)
                
                DispatchQueue.main.async {
                    self?.connectedPeers.removeAll { $0 == peerID }
                    self?.onPeerDisconnected?(peerID)
                }
            }
            connection.cancel()
        }
    }
    
    func sendAudioToPeer(_ peerID: MCPeerID, data: Data) {
        queue.async { [weak self] in
            guard let connection = self?.connections[peerID] else { return }
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    print("Failed to send audio to \(peerID): \(error)")
                }
            })
        }
    }
    
    func sendAudioToAllPeers(_ data: Data) {
        queue.async { [weak self] in
            for (peerID, connection) in self?.connections ?? [:] {
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("Failed to send audio to \(peerID): \(error)")
                    }
                })
            }
        }
    }
    
    func addPeerConnection(_ peerID: MCPeerID, connection: NWConnection) {
        queue.async { [weak self] in
            self?.connections[peerID] = connection
            self?.peerIDByConnection[connection] = peerID
            
            DispatchQueue.main.async {
                if !(self?.connectedPeers.contains(peerID) ?? false) {
                    self?.connectedPeers.append(peerID)
                }
            }
            
            self?.receiveData(on: connection)
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
                self?.onAudioReceived?(data, MCPeerID(displayName: "sender"))
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
```

- [ ] **Step 1: 创建 TCPConnectionManager.swift**

使用上面的代码。

- [ ] **Step 2: 提交**

```bash
git add AirShout/Features/P2P/TCPConnectionManager.swift
git commit -m "feat: add TCPConnectionManager for audio streaming"
```

---

## Phase 3: P2PAudioManager 重写

### Task 3.1: P2PAudioManager (完整重写)

**Files:**
- Rewrite: `AirShout/Features/P2P/P2PAudioManager.swift`

这是核心组件，包含发送端和接收端功能。

```swift
import Foundation
import MultipeerConnectivity
import AVFAudio
import Combine

final class P2PAudioManager: NSObject, ObservableObject {
    static let shared = P2PAudioManager()
    
    enum Role {
        case sender
        case receiver
    }
    
    enum ConnectionState: Equatable {
        case disconnected
        case discovering
        case waitingForSelection
        case connecting
        case connected(peerCount: Int)
        case speaking
        case receiving
        case error(String)
    }
    
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var discoveredPeers: [PeerInfo] = []
    @Published private(set) var speakingPeerID: MCPeerID?
    
    private let role: Role
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    private let audioSession = AVAudioSession.sharedInstance()
    private let tcpManager: TCPConnectionManager
    
    // Sender-specific
    private var selectedPeerID: MCPeerID?
    private var selectedPeerInfo: PeerInfo?
    
    // Audio engine
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private let levelProcessor = AudioLevelProcessor()
    private var speakingEngineRunning = false
    
    private let engineQueue = DispatchQueue(label: "com.airshout.p2paudioengine")
    
    private override init() {
        self.role = .sender
        self.tcpManager = TCPConnectionManager(role: .sender)
        super.init()
        setupMultipeer()
        setupTCPCallbacks()
    }
    
    // MARK: - MC Setup
    
    private func setupMultipeer() {
        let myPeerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: "airshout-p2p")
        browser.delegate = self
        browser.startBrowsingForPeers()
        
        connectionState = .discovering
    }
    
    private func setupTCPCallbacks() {
        tcpManager.onAudioReceived = { [weak self] data, peerID in
            self?.playAudioData(data)
        }
        
        tcpManager.onPeerDisconnected = { [weak self] peerID in
            // Handle peer disconnect
        }
    }
    
    // MARK: - Public Methods (Sender)
    
    func selectPeer(_ peer: PeerInfo) {
        guard let peerID = PeerAddressStore.shared.getByDeviceID(peer.deviceID) else { return }
        selectedPeerID = peerID
        selectedPeerInfo = peer
        connectionState = .connecting
        
        Task {
            do {
                try await tcpManager.connect(to: peer)
                await MainActor.run {
                    self.connectionState = .receiving
                }
            } catch {
                await MainActor.run {
                    self.connectionState = .error("连接失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func startSpeaking() {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.tcpManager.isConnected else { return }
            
            self.audioEngine = AVAudioEngine()
            guard let audioEngine = self.audioEngine else { return }
            
            let inputNode = audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)
            
            guard inputFormat.sampleRate > 0 else { return }
            
            let levelProcessor = self.levelProcessor
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
                self.processSpeakingLevel(buffer, processor: levelProcessor)
                
                guard let channelData = buffer.floatChannelData else { return }
                let frameLength = Int(buffer.frameLength)
                let dataSize = frameLength * MemoryLayout<Float>.size
                let data = Data(bytes: channelData[0], count: dataSize)
                
                self.tcpManager.sendAudio(data)
            }
            
            do {
                try audioEngine.start()
                self.speakingEngineRunning = true
                DispatchQueue.main.async {
                    self.connectionState = .speaking
                }
            } catch {
                print("Failed to start speaking engine: \(error)")
            }
        }
    }
    
    func stopSpeaking() {
        engineQueue.async { [weak self] in
            self?.speakingEngineRunning = false
            self?.audioEngine?.inputNode.removeTap(onBus: 0)
            self?.audioEngine?.stop()
            self?.audioEngine = nil
            
            DispatchQueue.main.async {
                self?.connectionState = .receiving
            }
        }
    }
    
    private func processSpeakingLevel(_ buffer: AVAudioPCMBuffer, processor: AudioLevelProcessor) {
        let now = Date().timeIntervalSinceReferenceDate
        guard processor.shouldUpdate(now: now) else { return }
        guard let level = processor.calculateLevel(from: buffer) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = level
        }
    }
    
    private func playAudioData(_ data: Data) {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            guard let audioEngine = self.audioEngine else { return }
            guard let playerNode = self.playerNode else { return }
            
            let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Float>.size)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else { return }
            
            buffer.frameLength = frameCount
            
            data.withUnsafeBytes { rawBufferPointer in
                guard let baseAddress = rawBufferPointer.baseAddress else { return }
                memcpy(buffer.floatChannelData?[0], baseAddress, data.count)
            }
            
            playerNode.scheduleBuffer(buffer, completionHandler: nil)
            if !playerNode.isPlaying {
                playerNode.play()
            }
        }
    }
    
    func disconnect() {
        stopSpeaking()
        tcpManager.disconnect()
        PeerAddressStore.shared.clear()
        discoveredPeers.removeAll()
        connectionState = .discovering
    }
}

// MARK: - MCSessionDelegate

extension P2PAudioManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        // Handle session state changes
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(PeerMessage.self, from: data) else { return }
        
        switch message {
        case .addressInfo(let deviceID, let displayName, let localIP, let port):
            var info = PeerInfo(deviceID: deviceID, displayName: displayName)
            info.ip = localIP
            info.port = port
            PeerAddressStore.shared.save(peerID: peerID, info: info)
            
            DispatchQueue.main.async {
                if let index = self.discoveredPeers.firstIndex(where: { $0.deviceID == deviceID }) {
                    self.discoveredPeers[index] = info
                } else {
                    self.discoveredPeers.append(info)
                }
            }
            
        case .requestAddress(let deviceID):
            // Receiver handles this - sender doesn't need to respond
            break
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceBrowserDelegate

extension P2PAudioManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async {
            self.discoveredPeers.removeAll { $0.id == peerID.displayName }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async {
            self.connectionState = .error("浏览失败: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 1: 重写 P2PAudioManager.swift**

使用上面的代码。

- [ ] **Step 2: 提交**

```bash
git add AirShout/Features/P2P/P2PAudioManager.swift
git commit -m "feat: rewrite P2PAudioManager with TCP transport"
```

---

### Task 3.2: P2PViewModel

**Files:**
- Modify: `AirShout/Features/P2P/P2PViewModel.swift`

```swift
import Foundation
import Combine

final class P2PViewModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isShouting: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var devices: [PeerInfo] = []
    @Published var showPermissionAlert: Bool = false
    @Published var errorMessage: String?
    
    private let audioManager: P2PAudioManager
    private var cancellables = Set<AnyCancellable>()
    
    init(audioManager: P2PAudioManager = .shared) {
        self.audioManager = audioManager
        setupBindings()
    }
    
    private func setupBindings() {
        audioManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
        
        audioManager.$discoveredPeers
            .receive(on: DispatchQueue.main)
            .assign(to: &$devices)
        
        audioManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.updateConnectionStatus(from: state)
            }
            .store(in: &cancellables)
    }
    
    private func updateConnectionStatus(from state: P2PAudioManager.ConnectionState) {
        switch state {
        case .disconnected:
            connectionStatus = .disconnected
            isShouting = false
        case .discovering:
            connectionStatus = .connecting
        case .waitingForSelection:
            connectionStatus = .disconnected
        case .connecting:
            connectionStatus = .connecting
        case .connected:
            connectionStatus = .connected
        case .speaking:
            connectionStatus = .transmitting
            isShouting = true
        case .receiving:
            connectionStatus = .connected
            isShouting = false
        case .error(let message):
            connectionStatus = .error(message)
            errorMessage = message
        }
    }
    
    func selectPeer(_ peer: PeerInfo) {
        audioManager.selectPeer(peer)
    }
    
    func startShout() {
        Task { @MainActor in
            do {
                try await audioManager.start()
            } catch AudioError.microphonePermissionDenied {
                showPermissionAlert = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    func stopShout() {
        audioManager.stopSpeaking()
    }
    
    func restartDiscovery() {
        audioManager.disconnect()
    }
}
```

- [ ] **Step 1: 修改 P2PViewModel.swift**

- [ ] **Step 2: 提交**

---

### Task 3.3: P2PView

**Files:**
- Modify: `AirShout/Features/P2P/P2PView.swift`

更新 UI 显示设备名称、连接状态、缓存的 IP:Port。

```swift
import SwiftUI

struct P2PView: View {
    @StateObject private var viewModel = P2PViewModel()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6).opacity(0.3)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Text("AirShout P2P")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    ConnectionStatusView(status: viewModel.connectionStatus)
                }
                .padding(.top, 20)
                
                if viewModel.devices.isEmpty {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("正在搜索设备...")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(viewModel.devices) { device in
                        DeviceRow(device: device) {
                            viewModel.selectPeer(device)
                        }
                    }
                    .listStyle(.plain)
                }
                
                Spacer()
                
                WaveformView(audioLevel: viewModel.audioLevel)
                    .frame(height: 60)
                
                Spacer()
                
                ShoutButton(
                    isActive: viewModel.isShouting,
                    onTap: {
                        if viewModel.isShouting {
                            viewModel.stopShout()
                        } else {
                            viewModel.startShout()
                        }
                    }
                )
                
                Spacer()
            }
            .padding()
        }
        .alert("麦克风权限被拒绝", isPresented: $viewModel.showPermissionAlert) {
            Button("打开设置") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("请在设置中开启麦克风权限以使用隔空喊话功能")
        }
    }
}

struct DeviceRow: View {
    let device: PeerInfo
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(device.displayName)
                        .font(.headline)
                    
                    if let ip = device.ip, let port = device.port {
                        Text("\(ip):\(port)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if device.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.vertical, 8)
        }
    }
}
```

- [ ] **Step 1: 修改 P2PView.swift**

- [ ] **Step 2: 提交**

---

## Phase 4: 后续任务 (暂不实现)

### Task 4.1: 接收端实现
- MC Advertiser 广播 PeerInfo
- TCP Server 接受多个连接
- 独占控制
- IP 变化检测和通知

### Task 4.2: 后台支持
- 验证后台 TCP 保持
- 处理后台地址通知

---

## 验证清单

- [ ] MC 发现接收端正常
- [ ] 用户选择设备后建立 TCP 连接
- [ ] 音频通过 TCP 传输
- [ ] 独占控制生效（只允许一个发送端）
- [ ] 断开后重连逻辑
- [ ] UI 显示设备名称、状态、IP:Port

---

## 实施顺序

1. Task 1.1: PeerMessage
2. Task 1.2: DeviceIdentifier
3. Task 1.3: PeerAddressStore
4. Task 1.4: NetworkMonitor
5. Task 2.1: TCPConnectionManager
6. Task 3.1: P2PAudioManager
7. Task 3.2: P2PViewModel
8. Task 3.3: P2PView
