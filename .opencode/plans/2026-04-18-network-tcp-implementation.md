# Network TCP Implementation Plan

## Phase 1: Core Infrastructure

### 1.1 Create Models

**File: `AirShout/Core/Models/SavedConnection.swift`**

```swift
struct SavedConnection: Codable, Identifiable {
    let id: UUID
    var name: String
    var ip: String
    var port: UInt16
    var lastConnected: Date?
}

struct SavedConnectionList: Codable {
    var connections: [SavedConnection]
}
```

- Uses `UserDefaults` key `savedConnections`
- Add `Codable` conformance to `ConnectionStatus` if needed for error states

### 1.2 Create PacketProcessor

**File: `AirShout/Core/Network/PacketProcessor.swift`**

**Protocol Header:**
```swift
struct PacketHeader {
    static let magic: UInt16 = 0x4148
    static let version: UInt8 = 0x01
    static let headerSize = 7

    var type: PacketType
    var timestamp: UInt32
    var payloadLength: UInt16
}

enum PacketType: UInt8 {
    case audio = 0x01
    case control = 0x02
}

enum ControlSubtype: UInt8 {
    case ping = 0x01
    case pong = 0x02
    case disconnect = 0x03
}
```

**PacketProcessor State Machine:**
```swift
class PacketProcessor {
    enum State {
        case waitingForHeader
        case waitingForPayload(length: UInt16)
    }

    var state: State = .waitingForHeader
    var recvBuffer = Data()
    var currentHeader: PacketHeader?

    func processReceivedData(_ data: Data) -> [AudioPacket]
}
```

**Magic Sync:** When `magic != 0x4148`, scan forward byte-by-byte to find next valid Magic.

### 1.3 Create JitterBuffer

**File: `AirShout/Core/Network/JitterBuffer.swift`**

```swift
struct AudioPacket {
    let timestamp: UInt32
    let payload: Data
}

class JitterBuffer {
    var packets: [AudioPacket] = []
    var targetDelayMs: Int = 100

    func insert(_ packet: AudioPacket)
    func popIfReady(currentTimeMs: UInt32) -> AudioPacket?
    func cleanup(maxCount: Int = 100)
}
```

- Thread-safe with `NSLock`
- Packets sorted by timestamp on insert
- `popIfReady` returns packet when `currentTime >= packet.timestamp + targetDelay`

### 1.4 Create AudioSessionConfig Extension (if needed)

Check existing `AudioSessionConfig.swift` - may not need changes if already configured for `.playAndRecord` with proper options for background audio.

---

## Phase 2: NetworkManager

### 2.1 NetworkManager Core

**File: `AirShout/Core/Network/NetworkManager.swift`**

Implements `AudioManaging` protocol:

```swift
class NetworkManager: AudioManaging {
    static let shared = NetworkManager()

    // AudioManaging
    var audioLevel: Float { ... }
    var isRunning: Bool { ... }
    var connectionStatus: ConnectionStatus { ... }
    var audioLevelPublisher: AnyPublisher<Float, Never>

    // TCP Server
    var serverListener: NWListener?
    var localPort: UInt16

    // TCP Client
    var clientConnection: NWConnection?

    // Audio
    var senderEngine: AVAudioEngine
    var receiverEngine: AVAudioEngine
    var jitterBuffer: JitterBuffer
    var packetProcessor: PacketProcessor

    // Queues
    let networkQueue = DispatchQueue(label: "com.airshout.network")
    let audioEngineQueue = DispatchQueue(label: "com.airshout.network.audioengine")
}
```

### 2.2 Server Listening

```swift
func startListening(port: UInt16) throws {
    localPort = port
    let params = NWParameters.tcp
    params.allowLocalEndpointReuse = true

    listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    listener?.stateUpdateHandler = { [weak self] state in
        // handle errors
    }
    listener?.newConnectionHandler = { [weak self] conn in
        self?.handleIncomingConnection(conn)
    }
    listener?.start(queue: networkQueue)
}

private func handleIncomingConnection(_ conn: NWConnection) {
    activeConnections.append(conn)
    conn.start(queue: networkQueue)
    receiveData(from: conn)
    updateStatus(.connected)
}
```

### 2.3 Client Connection

```swift
func connect(ip: String, port: UInt16) {
    updateStatus(.connecting)
    let endpoint = NWEndpoint.hostPort(host: .init(ip), port: .init(rawValue: port)!)
    clientConnection = NWConnection(to: endpoint, using: .tcp)
    clientConnection?.stateUpdateHandler = { [weak self] state in
        // handle state changes
    }
    clientConnection?.start(queue: networkQueue)
}

func disconnect() {
    clientConnection?.cancel()
    activeConnections.forEach { $0.cancel() }
    activeConnections.removeAll()
    stopAudioEngines()
    updateStatus(.disconnected)
}
```

### 2.4 Audio Send Path

```swift
private func setupSenderEngine() {
    let inputNode = senderEngine.inputNode
    let format = inputNode.outputFormat(forBus: 0)

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
        self?.handleAudioBuffer(buffer)
    }

    senderEngine.prepare()
    try? senderEngine.start()
}

private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    // Accumulate ~50ms worth of buffers before sending
    sendBuffer.append(buffer)

    if sendBuffer.duration >= 0.050 {  // 50ms
        let packet = createPacket(from: sendBuffer)
        send(packet)
        sendBuffer.reset()
    }
}

private func createPacket(from buffer: AVAudioPCMBuffer) -> Data {
    // Create header + PCM data
    var data = Data()
    // Append 7-byte header (magic, version, type, timestamp, length)
    // Append PCM float data
    return data
}
```

### 2.5 Audio Receive Path

```swift
private func receiveData(from conn: NWConnection) {
    conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
        if let data = data {
            let packets = self?.packetProcessor.processReceivedData(data) ?? []
            for packet in packets {
                self?.jitterBuffer.insert(packet)
            }
        }
        if !isComplete && error == nil {
            self?.receiveData(from: conn)
        }
    }
}

// Playback thread (10ms polling)
private func startPlaybackThread() {
    Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
        self?.checkPlayback()
    }
}

private func checkPlayback() {
    let currentTimeMs = UInt32(Date().timeIntervalSince1970 * 1000)

    if let packet = jitterBuffer.popIfReady(currentTimeMs: currentTimeMs) {
        let pcmBuffer = createPCMBuffer(from: packet.payload)
        receiverPlayerNode?.scheduleBuffer(pcmBuffer, completionHandler: nil)
    }
}
```

---

## Phase 3: ViewModels

### 3.1 NetworkViewModel

**File: `AirShout/Features/Network/NetworkViewModel.swift`**

```swift
class NetworkViewModel: ObservableObject {
    @Published var localIP: String = ""
    @Published var localPort: String = "8080"
    @Published var savedConnections: [SavedConnection] = []
    @Published var selectedConnection: SavedConnection?
    @Published var isListening: Bool = false
    @Published var isTransmitting: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var audioLevel: Float = 0
    @Published var showAddConnection: Bool = false

    private let networkManager = NetworkManager.shared
    private let preferences = UserPreferences.shared
}
```

**Key Methods:**
- `startListening()` / `stopListening()`
- `addConnection(name:ip:port:)`
- `removeConnection(at: IndexSet)`
- `selectConnection(_:)`
- `startTransmission()` / `stopTransmission()`

---

## Phase 4: Views

### 4.1 LocalInfoView

**File: `AirShout/Views/Network/LocalInfoView.swift`**

```
┌─────────────────────────────────────────┐
│  本机信息                                │
├─────────────────────────────────────────┤
│  IP: 192.168.1.100                      │
│  端口: [8080____]  (TextField)          │
│                                         │
│  [开始监听] / [停止监听] (Toggle)        │
└─────────────────────────────────────────┘
```

- Auto-detect local IP on appear using `getifaddrs()`
- Port TextField with numeric keyboard
- Start/Stop listening button

### 4.2 ConnectionListView

**File: `AirShout/Views/Network/ConnectionListView.swift`**

```
┌─────────────────────────────────────────┐
│  已保存的连接                     [+]   │
├─────────────────────────────────────────┤
│  iPhone-A    192.168.1.101:8080    >    │
│  HomePod     192.168.1.102:8080    >    │
│  ─────────────────────────────────      │
└─────────────────────────────────────────┘
```

- List with saved connections
- Swipe to delete
- Tap to select
- "+" button shows AddConnectionSheet

### 4.3 ConnectionItemView

**File: `AirShout/Views/Network/ConnectionItemView.swift`**

```
┌─────────────────────────────────────────┐
│  [名称] 192.168.1.101:8080        [状态] │
└─────────────────────────────────────────┘
```

### 4.4 AddConnectionSheet

```
┌─────────────────────────────────────────┐
│  添加连接                            [×] │
├─────────────────────────────────────────┤
│  名称: [________________]                │
│  IP地址: [________________]             │
│  端口: [________]                       │
│                                         │
│           [保存]                        │
└─────────────────────────────────────────┘
```

### 4.5 NetworkView

**File: `AirShout/Views/Network/NetworkView.swift`**

```
┌─────────────────────────────────────────┐
│  [LocalInfoView - 本机信息]              │
├─────────────────────────────────────────┤
│  [ConnectionListView - 已保存的连接]      │
├─────────────────────────────────────────┤
│  [WaveformView - 音量波形]               │
│                                         │
│  [开始传输] / [停止传输]                  │
└─────────────────────────────────────────┘
```

- Vertical stack layout
- Waveform + Start/Stop at bottom
- Start button enabled only when connection established

---

## Phase 5: Integration

### 5.1 Update MainTabView

```swift
TabView {
    ContentView()           // AirPlay
    P2PView()               // P2P MultipeerConnectivity
    NetworkView()           // NEW: TCP Network
}
.tabItem {
    Label("网络", systemImage: "network")
}
```

### 5.2 Update Info.plist

Add to `UIBackgroundModes`:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

### 5.3 Network Entitlements

Check that app has necessary entitlements for:
- `com.apple.developer.networking.wifi-info` (for local IP)
- Network extensions (if needed)

---

## Implementation Order

1. **Phase 1.1**: `SavedConnection` model + UserDefaults persistence
2. **Phase 1.2**: `PacketProcessor` - protocol parsing
3. **Phase 1.3**: `JitterBuffer` - audio buffering
4. **Phase 2.1**: `NetworkManager` core - TCP server/client setup
5. **Phase 2.2**: Audio send path (mic → TCP)
6. **Phase 2.3**: Audio receive path (TCP → speaker)
7. **Phase 3**: `NetworkViewModel`
8. **Phase 4.1**: `LocalInfoView`
9. **Phase 4.2**: `ConnectionListView` + add sheet
10. **Phase 4.3**: `NetworkView` composition
11. **Phase 5.1**: MainTabView integration
12. **Phase 5.2**: Info.plist background audio
13. **Build verification**

---

## Key Technical Decisions

| Decision | Rationale |
|----------|-----------|
| Use `Network.framework` NWListener/NWConnection | Modern Swift concurrency-friendly API |
| 50ms send buffer | Balance between latency and TCP overhead |
| 100ms jitter buffer target | Reasonable trade-off between smoothness and latency |
| State machine for packet parsing | Robust handling of TCP stream boundaries |
| Magic byte sync on error | Recover gracefully from corrupted data |
| 10ms playback polling | Responsive without excessive CPU usage |
| Separate sender/receiver engines | Cleaner separation of concerns |

---

## Testing Considerations

1. **Unit tests**:
   - `PacketProcessor`: Test parsing with various boundary conditions
   - `JitterBuffer`: Test ordering, overflow, timing
   - `SavedConnection`: Codable round-trip

2. **Integration tests**:
   - Two simulators/devices on same network
   - Test background audio continuation
   - Test route change handling

3. **Edge cases**:
   - Rapid connect/disconnect
   - Network interface change
   - Port already in use
   - Invalid IP address format