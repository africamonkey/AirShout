# MC-Enhanced Network Discovery Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add MultipeerConnectivity discovery to Network tab. MC exchanges IP/port/deviceName between devices. Discovered devices appear in "Saved Connections". User connects via TCP.

**Architecture:** New `MultipeerManager` handles MC browsing/session. `NetworkViewModel` coordinates MC + TCP. `SettingsView` for device name. Deduplication by `ip+port`.

**Tech Stack:** MultipeerConnectivity, Network.framework, SwiftUI

---

## File Structure

### New Files
- `AirShout/Core/Network/MultipeerManager.swift` - MC Browser/Session/Advertiser for Network tab
- `AirShout/Views/Settings/SettingsView.swift` - Device name configuration

### Modified Files
- `AirShout/Core/Models/SavedConnection.swift` - Add `source: ConnectionSource` field
- `AirShout/Shared/Preferences/UserPreferences.swift` - Add `deviceName` property
- `AirShout/Views/Network/LocalInfoView.swift` - Add device name display
- `AirShout/Views/Network/ConnectionListView.swift` - Show source indicator icon
- `AirShout/Views/MainTabView.swift` - Add Settings tab
- `AirShout/Features/Network/NetworkViewModel.swift` - Integrate MultipeerManager, auto-start listener
- `AirShout/AirShoutApp.swift` - Initialize MultipeerManager on app launch

---

## Task 1: Add ConnectionSource to SavedConnection

**Files:**
- Modify: `AirShout/Core/Models/SavedConnection.swift`

- [ ] **Step 1: Add ConnectionSource enum and update SavedConnection**

```swift
import Foundation

enum ConnectionSource: String, Codable {
    case manual      // User manually added
    case discovered  // MC discovered
    case connected   // Previously connected via TCP
}

struct SavedConnection: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var ip: String
    var port: UInt16
    var source: ConnectionSource
    var lastConnected: Date?

    init(id: UUID = UUID(), name: String, ip: String, port: UInt16, source: ConnectionSource = .manual, lastConnected: Date? = nil) {
        self.id = id
        self.name = name
        self.ip = ip
        self.port = port
        self.source = source
        self.lastConnected = lastConnected
    }

    static func == (lhs: SavedConnection, rhs: SavedConnection) -> Bool {
        lhs.id == rhs.id
    }
}
```

- [ ] **Step 2: Update SavedConnectionStorage for deduplication**

Replace `SavedConnectionStorage.swift` content:

```swift
import Foundation

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
        if let existingIndex = connections.firstIndex(where: { $0.ip == connection.ip && $0.port == connection.port }) {
            var existing = connections[existingIndex]
            existing.name = connection.name
            if existing.source == .manual {
                existing.source = .discovered
            }
            connections[existingIndex] = existing
        } else {
            connections.append(connection)
        }
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

    func updateSource(ip: String, port: UInt16, source: ConnectionSource) {
        var connections = load()
        if let idx = connections.firstIndex(where: { $0.ip == ip && $0.port == port }) {
            connections[idx].source = source
            save(connections)
        }
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add AirShout/Core/Models/SavedConnection.swift && git commit -m "feat: add ConnectionSource enum and deduplication to SavedConnection"
```

---

## Task 2: Add deviceName to UserPreferences

**Files:**
- Modify: `AirShout/Shared/Preferences/UserPreferences.swift`

- [ ] **Step 1: Add deviceName property**

Replace content of `UserPreferences.swift`:

```swift
import Foundation
import AVFAudio
import UIKit

final class UserPreferences {
    static let shared = UserPreferences()

    private enum Keys {
        static let lastDeviceUID = "com.airshout.lastDeviceUID"
        static let hasCompletedOnboarding = "com.airshout.hasCompletedOnboarding"
        static let p2pNickname = "com.airshout.p2pNickname"
        static let deviceName = "com.airshout.deviceName"
        static let lastTCPPort = "com.airshout.lastTCPPort"
    }

    private let defaultDeviceName: String

    private init() {
        defaultDeviceName = UIDevice.current.name
    }

    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.object(forKey: Keys.hasCompletedOnboarding) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }

    var p2pNickname: String {
        get { UserDefaults.standard.string(forKey: Keys.p2pNickname) ?? defaultDeviceName }
        set { UserDefaults.standard.set(newValue, forKey: Keys.p2pNickname) }
    }

    var deviceName: String {
        get { UserDefaults.standard.string(forKey: Keys.deviceName) ?? defaultDeviceName }
        set { UserDefaults.standard.set(newValue, forKey: Keys.deviceName) }
    }

    var lastTCPPort: UInt16? {
        get { UserDefaults.standard.object(forKey: Keys.lastTCPPort) as? UInt16 }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastTCPPort) }
    }

    func save(deviceUID: String) {
        UserDefaults.standard.set(deviceUID, forKey: Keys.lastDeviceUID)
    }

    func loadDeviceUID() -> String? {
        UserDefaults.standard.string(forKey: Keys.lastDeviceUID)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: Keys.lastDeviceUID)
    }

    func saveCurrentDeviceUID() {
        guard let deviceUID = AVAudioSession.sharedInstance().currentRoute.outputs.first?.uid else { return }
        save(deviceUID: deviceUID)
    }

    func restoreDeviceIfNeeded() -> Bool {
        guard let savedUID = loadDeviceUID() else { return false }
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute

        return currentRoute.outputs.contains { $0.uid == savedUID }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AirShout/Shared/Preferences/UserPreferences.swift && git commit -m "feat: add deviceName and lastTCPPort to UserPreferences"
```

---

## Task 3: Create MultipeerManager

**Files:**
- Create: `AirShout/Core/Network/MultipeerManager.swift`

- [ ] **Step 1: Create MultipeerManager**

```swift
import Foundation
import MultipeerConnectivity
import Combine

struct DeviceInfo: Codable {
    let ip: String
    let port: UInt16
    let deviceName: String
}

final class MultipeerManager: NSObject, ObservableObject {
    static let shared = MultipeerManager()

    @Published private(set) var discoveredDevices: [String: DeviceInfo] = [:]

    private let serviceType = "airshout-disc"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    private let mcQueue = DispatchQueue(label: "com.airshout.multipeer")
    private let storage = SavedConnectionStorage.shared

    var localIP: String = ""
    var localPort: UInt16 = 0

    private override init() {
        super.init()
    }

    func setup(deviceName: String) {
        myPeerID = MCPeerID(displayName: deviceName)

        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        let discoveryInfo: [String: String]? = nil

        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    func updateLocalInfo(ip: String, port: UInt16) {
        mcQueue.async { [weak self] in
            guard let self = self else { return }
            self.localIP = ip
            self.localPort = port
            self.broadcastLocalInfo()
        }
    }

    private func broadcastLocalInfo() {
        guard !session.connectedPeers.isEmpty else { return }
        guard !localIP.isEmpty, localPort > 0 else { return }

        let info = DeviceInfo(ip: localIP, port: localPort, deviceName: UserPreferences.shared.deviceName)

        do {
            let data = try JSONEncoder().encode(info)
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
        } catch {
            print("Failed to broadcast local info: \(error)")
        }
    }

    private func sendLocalInfo(to peer: MCPeerID) {
        guard !localIP.isEmpty, localPort > 0 else { return }

        let info = DeviceInfo(ip: localIP, port: localPort, deviceName: UserPreferences.shared.deviceName)

        do {
            let data = try JSONEncoder().encode(info)
            try session.send(data, toPeers: [peer], with: .reliable)
        } catch {
            print("Failed to send local info to \(peer.displayName): \(error)")
        }
    }

    func shutdown() {
        advertiser?.delegate = nil
        advertiser?.stopAdvertisingPeer()
        browser?.delegate = nil
        browser?.stopBrowsingForPeers()
        session?.disconnect()
    }
}

extension MultipeerManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .connected:
                self?.sendLocalInfo(to: peerID)
            case .notConnected:
                self?.discoveredDevices.removeValue(forKey: peerID.displayName)
            default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do {
            let info = try JSONDecoder().decode(DeviceInfo.self, from: data)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.discoveredDevices[peerID.displayName] = info

                let connection = SavedConnection(
                    name: info.deviceName,
                    ip: info.ip,
                    port: info.port,
                    source: .discovered
                )
                self.storage.add(connection)
            }
        } catch {
            print("Failed to decode DeviceInfo: \(error)")
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MultipeerManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to advertise: \(error)")
    }
}

extension MultipeerManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredDevices.removeValue(forKey: peerID.displayName)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Failed to browse: \(error)")
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AirShout/Core/Network/MultipeerManager.swift && git commit -m "feat: add MultipeerManager for MC-based device discovery"
```

---

## Task 4: Update NetworkViewModel

**Files:**
- Modify: `AirShout/Features/Network/NetworkViewModel.swift`

- [ ] **Step 1: Update NetworkViewModel to integrate MultipeerManager**

Replace content of `NetworkViewModel.swift`:

```swift
import Foundation
import Combine
import Network

final class NetworkViewModel: ObservableObject {
    @Published var localIP: String = ""
    @Published var localPort: String = ""
    @Published var deviceName: String = ""
    @Published var savedConnections: [SavedConnection] = []
    @Published var selectedConnection: SavedConnection?
    @Published var isListening: Bool = false
    @Published var isTransmitting: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var audioLevel: Float = 0
    @Published var showAddConnection: Bool = false
    @Published var showSettings: Bool = false
    @Published var errorMessage: String?

    private let networkManager = NetworkManager.shared
    private let multipeerManager = MultipeerManager.shared
    private let storage = SavedConnectionStorage.shared
    private let preferences = UserPreferences.shared
    private var cancellables = Set<AnyCancellable>()
    private var pendingStartTransmission: Bool = false
    private var connectingTimer: Timer?
    private let connectingTimeout: TimeInterval = 3.0
    private var currentConnectingId: Int = 0

    init() {
        setupBindings()
        loadConnections()
        detectLocalIP()
        startMC()
        startListening()
    }

    private func setupBindings() {
        multipeerManager.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadConnections()
            }
            .store(in: &cancellables)

        networkManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        networkManager.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isTransmitting)

        networkManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                self.connectionStatus = status

                switch status {
                case .connected:
                    self.connectingTimer?.invalidate()
                    self.connectingTimer = nil
                    if self.pendingStartTransmission {
                        self.pendingStartTransmission = false
                        self.performStartTransmission()
                    }
                    self.updateConnectionSource(ip: self.localIP, port: UInt16(self.localPort) ?? 0)
                case .error(let message):
                    self.errorMessage = message
                    self.pendingStartTransmission = false
                    self.connectingTimer?.invalidate()
                    self.connectingTimer = nil
                case .disconnected:
                    self.pendingStartTransmission = false
                    self.connectingTimer?.invalidate()
                    self.connectingTimer = nil
                case .connecting:
                    self.startConnectingTimer()
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }

    private func updateConnectionSource(ip: String, port: UInt16) {
        if let conn = savedConnections.first(where: { $0.ip == ip && $0.port == port }) {
            storage.updateSource(ip: ip, port: port, source: .connected)
            loadConnections()
        }
    }

    private func startMC() {
        deviceName = preferences.deviceName
        multipeerManager.setup(deviceName: deviceName)
    }

    private func startConnectingTimer() {
        connectingTimer?.invalidate()
        let timerConnectingId = currentConnectingId
        connectingTimer = Timer.scheduledTimer(withTimeInterval: connectingTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            if self.connectionStatus == .connecting && self.currentConnectingId == timerConnectingId {
                self.connectionStatus = .disconnected
                self.errorMessage = "连接超时"
                self.pendingStartTransmission = false
            }
        }
    }

    private func loadConnections() {
        savedConnections = storage.load()
    }

    func detectLocalIP() {
        var address: String = "无法获取"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return }
        guard let firstAddr = ifaddr else { return }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "pdp_ip0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)

        localIP = address
        multipeerManager.updateLocalInfo(ip: address, port: UInt16(localPort) ?? 0)
    }

    func startListening() {
        if localPort.isEmpty {
            localPort = String(preferences.lastTCPPort ?? 0)
        }

        let port: UInt16
        if localPort.isEmpty || localPort == "0" {
            port = 0
        } else if let p = UInt16(localPort) {
            port = p
        } else {
            errorMessage = "无效的端口号"
            return
        }

        do {
            try networkManager.startListening(port: port)
            isListening = true
            errorMessage = nil

            if port == 0 {
                localPort = String(networkManager.currentPort)
                preferences.lastTCPPort = networkManager.currentPort
            }

            multipeerManager.updateLocalInfo(ip: localIP, port: UInt16(localPort) ?? 0)
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopListening() {
        networkManager.stopListening()
        isListening = false
    }

    func addConnection(name: String, ip: String, port: String) {
        guard let portNum = UInt16(port), !name.isEmpty, !ip.isEmpty else {
            errorMessage = "请填写完整信息"
            return
        }

        let connection = SavedConnection(name: name, ip: ip, port: portNum, source: .manual)
        storage.add(connection)
        savedConnections = storage.load()
        showAddConnection = false
    }

    func removeConnection(at offsets: IndexSet) {
        for index in offsets {
            storage.remove(at: index)
        }
        savedConnections = storage.load()
    }

    func selectConnection(_ connection: SavedConnection) {
        selectedConnection = connection
    }

    func connect() {
        guard let connection = selectedConnection else {
            errorMessage = "请先选择一个连接"
            return
        }

        networkManager.connect(ip: connection.ip, port: connection.port)

        var updated = connection
        updated.lastConnected = Date()
        storage.update(updated)
        savedConnections = storage.load()
    }

    func disconnect() {
        networkManager.disconnect()
        selectedConnection = nil
    }

    func startTransmission() {
        switch connectionStatus {
        case .disconnected, .error:
            if selectedConnection != nil {
                currentConnectingId += 1
                pendingStartTransmission = true
                connect()
            } else {
                errorMessage = "请先选择一个连接"
            }
        case .connecting:
            currentConnectingId += 1
            pendingStartTransmission = true
            networkManager.disconnect()
            connect()
        case .connected:
            performStartTransmission()
        case .transmitting:
            break
        }
    }

    private func performStartTransmission() {
        Task { @MainActor in
            do {
                try await networkManager.start()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopTransmission() {
        networkManager.disconnect()
    }

    func refreshDeviceName() {
        deviceName = preferences.deviceName
    }

    deinit {
        connectingTimer?.invalidate()
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AirShout/Features/Network/NetworkViewModel.swift && git commit -m "feat: integrate MultipeerManager into NetworkViewModel, auto-start listener"
```

---

## Task 5: Update NetworkManager for dynamic port

**Files:**
- Modify: `AirShout/Core/Network/NetworkManager.swift`

- [ ] **Step 1: Add currentPort property to NetworkManager**

Add after `private var localPort: UInt16 = 8080`:

```swift
private(set) var currentPort: UInt16 = 0
```

- [ ] **Step 2: Update startListening to capture assigned port**

In `startListening(port:)` method, after listener is ready:

```swift
case .ready:
    Swift.print("TCP Listener ready on port \(port)")
    self.currentPort = port
```

And update `stopListening()` to also set `currentPort = 0`:

```swift
func stopListening() {
    listener?.cancel()
    listener = nil
    currentPort = 0
    // ... rest unchanged
}
```

- [ ] **Step 3: Commit**

```bash
git add AirShout/Core/Network/NetworkManager.swift && git commit -m "feat: add currentPort property to NetworkManager for dynamic port detection"
```

---

## Task 6: Update LocalInfoView

**Files:**
- Modify: `AirShout/Views/Network/LocalInfoView.swift`

- [ ] **Step 1: Update LocalInfoView to add deviceName and settings button**

Replace content of `LocalInfoView.swift`:

```swift
import SwiftUI

struct LocalInfoView: View {
    @Binding var deviceName: String
    @Binding var localIP: String
    @Binding var localPort: String
    @Binding var isListening: Bool

    var onStartListening: () -> Void
    var onStopListening: () -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("本机信息")
                    .font(.headline)
                Spacer()
                Button(action: onOpenSettings) {
                    Image(systemName: "gear")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 4)

            HStack {
                Text("设备名:")
                    .foregroundColor(.secondary)
                Text(deviceName)
                    .fontWeight(.medium)
            }

            HStack {
                Text("IP:")
                    .foregroundColor(.secondary)
                Text(localIP)
                    .fontWeight(.medium)
            }

            HStack {
                Text("端口:")
                    .foregroundColor(.secondary)
                TextField("端口", text: $localPort)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 100)
                    .disabled(isListening)
            }

            Button(action: {
                if isListening {
                    onStopListening()
                } else {
                    onStartListening()
                }
            }) {
                HStack {
                    Image(systemName: isListening ? "stop.fill" : "play.fill")
                    Text(isListening ? "停止监听" : "开始监听")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isListening ? Color.red.opacity(0.8) : Color.green.opacity(0.8))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .disabled(localPort.isEmpty && !isListening)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AirShout/Views/Network/LocalInfoView.swift && git commit -m "feat: add deviceName and settings button to LocalInfoView"
```

---

## Task 7: Update ConnectionListView

**Files:**
- Modify: `AirShout/Views/Network/ConnectionListView.swift`

- [ ] **Step 1: Update ConnectionListView to show source indicator**

Replace content of `ConnectionListView.swift`:

```swift
import SwiftUI

struct ConnectionListView: View {
    @Binding var savedConnections: [SavedConnection]
    @Binding var selectedConnection: SavedConnection?
    @Binding var showAddConnection: Bool

    var onSelect: (SavedConnection) -> Void
    var onDelete: (IndexSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("已保存的连接")
                    .font(.headline)
                Spacer()
                Button(action: {
                    showAddConnection = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding(.bottom, 4)

            if savedConnections.isEmpty {
                Text("暂无保存的连接")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(savedConnections) { connection in
                    ConnectionItemView(
                        connection: connection,
                        isSelected: selectedConnection?.id == connection.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedConnection = connection
                        onSelect(connection)
                    }
                }
                .onDelete(perform: onDelete)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
    }
}

struct ConnectionItemView: View {
    let connection: SavedConnection
    let isSelected: Bool

    var sourceIcon: String {
        switch connection.source {
        case .manual:
            return "link"
        case .discovered:
            return "wifi"
        case .connected:
            return "checkmark.circle"
        }
    }

    var body: some View {
        HStack {
            Image(systemName: sourceIcon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(connection.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(connection.ip):\(connection.port)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct AddConnectionSheet: View {
    @Binding var isPresented: Bool
    @State private var name: String = ""
    @State private var ip: String = ""
    @State private var port: String = ""

    var onSave: (String, String, String) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("连接信息") {
                    TextField("名称", text: $name)
                    TextField("IP地址", text: $ip)
                        .keyboardType(.decimalPad)
                    TextField("端口", text: $port)
                        .keyboardType(.numberPad)
                }
            }
            .navigationTitle("添加连接")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(name, ip, port)
                        isPresented = false
                    }
                    .disabled(name.isEmpty || ip.isEmpty || port.isEmpty)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AirShout/Views/Network/ConnectionListView.swift && git commit -m "feat: add source indicator icons to ConnectionListView"
```

---

## Task 8: Create SettingsView

**Files:**
- Create: `AirShout/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Create SettingsView**

```swift
import SwiftUI

struct SettingsView: View {
    @State private var deviceName: String = UserPreferences.shared.deviceName
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("设备信息") {
                    TextField("设备名", text: $deviceName)
                        .onChange(of: deviceName) { _, newValue in
                            UserPreferences.shared.deviceName = newValue
                            MultipeerManager.shared.updateLocalInfo(
                                ip: MultipeerManager.shared.localIP,
                                port: MultipeerManager.shared.localPort
                            )
                        }
                }

                Section {
                    Text("设备名将通过 MultipeerConnectivity 广播给局域网内的其他设备。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                deviceName = UserPreferences.shared.deviceName
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AirShout/Views/Settings/SettingsView.swift && git commit -m "feat: add SettingsView for device name configuration"
```

---

## Task 9: Update NetworkView

**Files:**
- Modify: `AirShout/Views/Network/NetworkView.swift`

- [ ] **Step 1: Update NetworkView to pass new parameters**

Replace content of `NetworkView.swift`:

```swift
import SwiftUI

struct NetworkView: View {
    @StateObject private var viewModel = NetworkViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                LocalInfoView(
                    deviceName: $viewModel.deviceName,
                    localIP: $viewModel.localIP,
                    localPort: $viewModel.localPort,
                    isListening: $viewModel.isListening,
                    onStartListening: { viewModel.startListening() },
                    onStopListening: { viewModel.stopListening() },
                    onOpenSettings: { viewModel.showSettings = true }
                )

                ConnectionListView(
                    savedConnections: $viewModel.savedConnections,
                    selectedConnection: $viewModel.selectedConnection,
                    showAddConnection: $viewModel.showAddConnection,
                    onSelect: { _ in },
                    onDelete: { viewModel.removeConnection(at: $0) }
                )

                Spacer()

                VStack(spacing: 16) {
                    WaveformView(audioLevel: viewModel.audioLevel)
                        .frame(height: 60)

                    ConnectionStatusView(status: viewModel.connectionStatus)
                        .padding(.bottom, 8)

                    HStack(spacing: 16) {
                        Button(action: {
                            if viewModel.isTransmitting {
                                viewModel.stopTransmission()
                            } else {
                                viewModel.startTransmission()
                            }
                        }) {
                            HStack {
                                Image(systemName: viewModel.isTransmitting ? "stop.fill" : "play.fill")
                                Text(viewModel.isTransmitting ? "停止传输" : "开始传输")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(viewModel.isTransmitting ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!viewModel.isTransmitting && viewModel.selectedConnection == nil)
                        .disabled(viewModel.connectionStatus == .connecting)
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            .navigationTitle("网络")
            .sheet(isPresented: $viewModel.showAddConnection) {
                AddConnectionSheet(
                    isPresented: $viewModel.showAddConnection,
                    onSave: { name, ip, port in
                        viewModel.addConnection(name: name, ip: ip, port: port)
                    }
                )
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView()
            }
            .alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("确定") {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AirShout/Views/Network/NetworkView.swift && git commit -m "feat: update NetworkView to integrate settings sheet"
```

---

## Task 10: Update MainTabView

**Files:**
- Modify: `AirShout/Views/MainTabView.swift`

- [ ] **Step 1: Add Settings tab**

Replace content of `MainTabView.swift`:

```swift
import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("AirPlay", systemImage: "airplayaudio")
                }

            P2PView()
                .tabItem {
                    Label("AirShout", systemImage: "wave.3.right")
                }

            NetworkView()
                .tabItem {
                    Label("网络", systemImage: "network")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AirShout/Views/MainTabView.swift && git commit -m "feat: add Settings tab to MainTabView"
```

---

## Task 11: Update AirShoutApp

**Files:**
- Modify: `AirShout/AirShoutApp.swift`

- [ ] **Step 1: Initialize MultipeerManager on app launch**

Replace content of `AirShoutApp.swift`:

```swift
import SwiftUI

@main
struct AirShoutApp: App {
    init() {
        _ = P2PAudioManager.shared
        _ = MultipeerManager.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AirShout/AirShoutApp.swift && git commit -m "feat: initialize MultipeerManager on app launch"
```

---

## Task 12: Build and Verify

- [ ] **Step 1: Build the project**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build
```

- [ ] **Step 2: If build fails, fix errors and rebuild**

---

## Plan Summary

| Task | Description |
|------|-------------|
| 1 | Add `ConnectionSource` enum and deduplication to `SavedConnection` |
| 2 | Add `deviceName` and `lastTCPPort` to `UserPreferences` |
| 3 | Create `MultipeerManager` for MC discovery |
| 4 | Update `NetworkViewModel` to integrate MultipeerManager |
| 5 | Add `currentPort` property to `NetworkManager` |
| 6 | Update `LocalInfoView` with device name and settings button |
| 7 | Update `ConnectionListView` with source indicator icons |
| 8 | Create `SettingsView` |
| 9 | Update `NetworkView` to show settings sheet |
| 10 | Add Settings tab to `MainTabView` |
| 11 | Initialize `MultipeerManager` on app launch |
| 12 | Build and verify |

---

## Spec Coverage Check

- [x] MC discovers devices and exchanges `{ip, port, deviceName}` - Task 3 (MultipeerManager)
- [x] Discovered devices appear in "Saved Connections" with `source = .discovered` - Task 1 (SavedConnection deduplication)
- [x] User manually selects a device and connects via TCP - Task 4 (NetworkViewModel integration)
- [x] Device name configurable in Settings (defaults to `UIDevice.current.name`) - Tasks 2, 8
- [x] Deduplicate by `ip + port` - Task 1 (SavedConnectionStorage.add with deduplication)
- [x] MC starts on app launch - Task 11
- [x] Auto-start TCP listener - Task 4
- [x] Port strategy (0 for system-assigned, with user override) - Tasks 4, 5
- [x] UI changes (LocalInfoView, ConnectionListView, SettingsView) - Tasks 6, 7, 8
