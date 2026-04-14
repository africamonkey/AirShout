# P2P 对讲功能实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现局域网 P2P 对讲功能，用户可以在同一局域网内无需服务器进行实时语音通信。

**Architecture:** 使用 Multipeer Connectivity 框架实现 P2P 发现和连接，音频通过 AVAudioEngine 采集后分 chunk 通过 MCSession 广播到所有已连接节点。

**Tech Stack:** Multipeer Connectivity, AVAudioEngine, SwiftUI

---

## 文件结构

```
AirShout/
├── Managers/
│   ├── AudioManager.swift      # 现有，AirPlay 功能
│   └── P2PAudioManager.swift   # 新增，P2P 音频管理
├── ViewModels/
│   ├── ShoutViewModel.swift   # 现有，AirPlay ViewModel
│   └── P2PViewModel.swift     # 新增，P2P ViewModel
├── Views/
│   ├── ContentView.swift      # 修改为 MainTabView
│   ├── P2PView.swift          # 新增，P2P 界面
│   └── ...
├── App/
│   └── AirShoutApp.swift      # 修改，添加 TabView
```

---

## Task 1: 创建 P2PAudioManager

**Files:**
- Create: `AirShout/Managers/P2PAudioManager.swift`
- Test: `AirShoutTests/AirShoutTests.swift`

- [ ] **Step 1: 创建 P2PAudioManager.swift 基础结构**

```swift
import Foundation
import MultipeerConnectivity
import AVFAudio
import Combine

final class P2PAudioManager: NSObject, ObservableObject {
    static let shared = P2PAudioManager()

    @Published var audioLevel: Float = 0
    @Published var isRunning: Bool = false
    @Published var connectionStatus: P2PConnectionStatus = .disconnected
    @Published var peers: [MCPeerID] = []

    enum P2PConnectionStatus {
        case disconnected
        case connecting
        case connected
        case speaking
        case error(String)

        var isTransmitting: Bool {
            if case .speaking = self { return true }
            return false
        }
    }

    enum P2PError: Error, LocalizedError {
        case microphonePermissionDenied
        case engineSetupFailed
        case notConnected

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "麦克风权限被拒绝"
            case .engineSetupFailed:
                return "音频引擎设置失败"
            case .notConnected:
                return "没有连接到任何设备"
            }
        }
    }

    private let serviceType = "airshout-p2p"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    private var audioEngine: AVAudioEngine?
    private let audioSession = AVAudioSession.sharedInstance()
    private var playerNode: AVAudioPlayerNode?
    private let engineQueue = DispatchQueue(label: "com.airshout.p2paudioengine")
    private var lastAudioLevelUpdate: TimeInterval = 0
    private let audioLevelUpdateInterval: TimeInterval = 0.05

    private override init() {
        super.init()
        setupMultipeer()
    }
}
```

- [ ] **Step 2: 添加 Multipeer 设置方法**

在 `P2PAudioManager.swift` 中添加：

```swift
private func setupMultipeer() {
    let nickname = UserDefaults.standard.string(forKey: "p2p_nickname") ?? UIDevice.current.name
    myPeerID = MCPeerID(displayName: nickname)

    session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
    session.delegate = self

    advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
    advertiser.delegate = self
    advertiser.startAdvertisingPeer()

    browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
    browser.delegate = self
    browser.startBrowsingForPeers()
}
```

- [ ] **Step 3: 添加 MCSessionDelegate 实现**

```swift
extension P2PAudioManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch state {
            case .connected:
                if !self.peers.contains(peerID) {
                    self.peers.append(peerID)
                }
                self.connectionStatus = .connected
            case .notConnected:
                self.peers.removeAll { $0 == peerID }
                if self.peers.isEmpty {
                    self.connectionStatus = .disconnected
                }
            case .connecting:
                self.connectionStatus = .connecting
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // 收到音频数据，播放
        engineQueue.async { [weak self] in
            self?.playAudioData(data)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}
```

- [ ] **Step 4: 添加 MCNearbyServiceAdvertiserDelegate 和 MCNearbyServiceBrowserDelegate**

```swift
extension P2PAudioManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // 自动接受所有邀请
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to advertise: \(error)")
    }
}

extension P2PAudioManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        // 自动连接到发现的节点
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // 节点丢失
        DispatchQueue.main.async { [weak self] in
            self?.peers.removeAll { $0 == peerID }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Failed to browse: \(error)")
    }
}
```

- [ ] **Step 5: 添加音频采集和发送逻辑**

```swift
func startSpeaking() async throws {
    guard !peers.isEmpty else {
        throw P2PError.notConnected
    }

    let granted = await withCheckedContinuation { continuation in
        AVAudioApplication.requestRecordPermission { granted in
            continuation.resume(returning: granted)
        }
    }
    guard granted else {
        throw P2PError.microphonePermissionDenied
    }

    try configureAudioSession()

    try engineQueue.sync {
        try setupAudioEngineForSpeaking()
    }

    DispatchQueue.main.async { [weak self] in
        self?.isRunning = true
        self?.connectionStatus = .speaking
    }
}

private func setupAudioEngineForSpeaking() throws {
    audioEngine = AVAudioEngine()
    guard let audioEngine = audioEngine else {
        throw P2PError.engineSetupFailed
    }

    let inputNode = audioEngine.inputNode
    let outputNode = audioEngine.outputNode
    let mainMixer = audioEngine.mainMixerNode

    playerNode = AVAudioPlayerNode()
    guard let playerNode = playerNode else {
        throw P2PError.engineSetupFailed
    }
    audioEngine.attach(playerNode)

    let inputFormat = inputNode.outputFormat(forBus: 0)
    let outputFormat = outputNode.inputFormat(forBus: 0)

    guard inputFormat.sampleRate > 0 else {
        throw P2PError.engineSetupFailed
    }

    audioEngine.connect(playerNode, to: mainMixer, format: inputFormat)
    audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)

    inputNode.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
        guard let self = self else { return }
        self.processAndSendAudioBuffer(buffer)
        self.processAudioLevel(buffer)
    }

    audioEngine.prepare()
    try audioEngine.start()
    playerNode.play()
}

private func processAndSendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData else { return }
    let channelDataValue = channelData.pointee
    let frameLength = Int(buffer.frameLength)

    // Convert to Data
    let data = Data(bytes: channelDataValue, count: frameLength * MemoryLayout<Float>.size)

    // Send to all peers
    guard !session.connectedPeers.isEmpty else { return }
    do {
        try session.send(data, toPeers: session.connectedPeers, with: .unreliable)
    } catch {
        print("Failed to send audio data: \(error)")
    }
}

private func processAudioLevel(_ buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData else { return }
    let channelDataValue = channelData.pointee

    var sum: Float = 0
    for i in stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride) {
        let sample = channelDataValue[i]
        sum += sample * sample
    }
    let rms = sqrt(sum / Float(buffer.frameLength))
    let avgPower = 20 * log10(max(rms, 0.000001))
    let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))

    let now = Date().timeIntervalSinceReferenceDate
    guard now - lastAudioLevelUpdate >= audioLevelUpdateInterval else { return }
    lastAudioLevelUpdate = now

    DispatchQueue.main.async { [weak self] in
        self?.audioLevel = normalizedLevel
    }
}
```

- [ ] **Step 6: 添加音频播放逻辑**

```swift
private func playAudioData(_ data: Data) {
    guard let playerNode = playerNode, audioEngine?.isRunning == true else { return }

    let frameCount = UInt32(data.count / MemoryLayout<Float>.size)
    guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine!.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else { return }

    buffer.frameLength = frameCount
    let channelData = buffer.floatChannelData!
    data.copyBytes(to: UnsafeMutableBufferPointer(start: channelData[0], count: data.count))

    playerNode.scheduleBuffer(buffer, completionHandler: nil)
}
```

- [ ] **Step 7: 添加 stopSpeaking 和 stop 方法**

```swift
func stopSpeaking() {
    engineQueue.async { [weak self] in
        self?.audioEngine?.inputNode.removeTap(onBus: 0)
        self?.audioEngine?.stop()
        self?.audioEngine = nil
        self?.playerNode = nil

        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
            self?.audioLevel = 0
            self?.connectionStatus = self?.peers.isEmpty == false ? .connected : .disconnected
        }
    }
}

func stop() {
    stopSpeaking()
    advertiser?.stopAdvertisingPeer()
    browser?.stopBrowsingForPeers()
    session?.disconnect()
}
```

- [ ] **Step 8: 添加 AudioSession 配置**

```swift
private func configureAudioSession() throws {
    try audioSession.setCategory(
        .playAndRecord,
        mode: .default,
        options: [.allowBluetoothA2DP, .allowBluetoothHFP, .allowAirPlay])

    let preferredSampleRate: Double = 44100
    try audioSession.setPreferredSampleRate(preferredSampleRate)

    try audioSession.setActive(true)
}
```

- [ ] **Step 9: 提交代码**

```bash
git add AirShout/Managers/P2PAudioManager.swift
git commit -m "feat: add P2PAudioManager for P2P intercom"
```

---

## Task 2: 创建 P2PViewModel

**Files:**
- Create: `AirShout/ViewModels/P2PViewModel.swift`
- Modify: `AirShout/Managers/P2PAudioManager.swift` (添加 Device 模型)

- [ ] **Step 1: 在 P2PAudioManager 中添加 Device 模型**

在 `P2PAudioManager.swift` 中添加：

```swift
struct Device: Identifiable, Equatable {
    let id: MCPeerID
    var displayName: String
    var isConnected: Bool

    static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id
    }
}

extension P2PAudioManager {
    var devices: [Device] {
        peers.map { peerID in
            Device(
                id: peerID,
                displayName: peerID.displayName,
                isConnected: true
            )
        }
    }
}
```

- [ ] **Step 2: 创建 P2PViewModel**

```swift
import Foundation
import Combine

@MainActor
final class P2PViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var isSpeaking: Bool = false
    @Published var audioLevel: Float = 0
    @Published var connectionStatus: P2PAudioManager.P2PConnectionStatus = .disconnected
    @Published var errorMessage: String?

    private let audioManager = P2PAudioManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        audioManager.$peers
            .receive(on: DispatchQueue.main)
            .assign(to: &$devices)

        audioManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        audioManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.connectionStatus = status
                if case .error(let message) = status {
                    self?.errorMessage = message
                }
            }
            .store(in: &cancellables)

        audioManager.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSpeaking)
    }

    func startSpeaking() {
        Task {
            do {
                errorMessage = nil
                try await audioManager.startSpeaking()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopSpeaking() {
        audioManager.stopSpeaking()
    }
}
```

- [ ] **Step 3: 提交代码**

```bash
git add AirShout/Managers/P2PAudioManager.swift AirShout/ViewModels/P2PViewModel.swift
git commit -m "feat: add P2PViewModel"
```

---

## Task 3: 创建 P2PView

**Files:**
- Create: `AirShout/Views/P2PView.swift`

- [ ] **Step 1: 创建 P2PView**

```swift
import SwiftUI

struct P2PView: View {
    @StateObject private var viewModel = P2PViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // 设备列表
            deviceListSection

            Spacer()

            // 错误提示
            if let error = viewModel.errorMessage {
                errorBanner(message: error)
            }

            // 说话按钮
            speakingSection
        }
        .background(Color(.systemBackground))
    }

    private var deviceListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("在线设备")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            if viewModel.devices.isEmpty {
                emptyStateView
            } else {
                deviceList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("等待发现其他设备...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("确保其他设备也打开了 AirShout")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.devices) { device in
                    DeviceRow(device: device)
                }
            }
            .padding(.horizontal)
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    private var speakingSection: some View {
        HStack(spacing: 20) {
            WaveformView(level: viewModel.audioLevel)
                .frame(width: 60, height: 60)

            ShoutButton(
                isPressed: $viewModel.isSpeaking,
                onPress: { viewModel.startSpeaking() },
                onRelease: { viewModel.stopSpeaking() }
            )

            WaveformView(level: viewModel.audioLevel)
                .frame(width: 60, height: 60)
        }
        .padding(.vertical, 30)
        .padding(.horizontal)
        .background(Color(.systemGray6))
    }
}

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack {
            Image(systemName: "iphone")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.body)
                Text(device.isConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(device.isConnected ? .green : .secondary)
            }

            Spacer()

            if device.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
```

- [ ] **Step 2: 提交代码**

```bash
git add AirShout/Views/P2PView.swift
git commit -m "feat: add P2PView for intercom UI"
```

---

## Task 4: 添加 TabView

**Files:**
- Modify: `AirShout/AirShoutApp.swift`

- [ ] **Step 1: 创建 ContentView 重构为 MainTabView**

将 `ContentView.swift` 重命名为 `MainTabView.swift`，内容保持不变：

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
        }
    }
}
```

- [ ] **Step 2: 更新 AirShoutApp**

```swift
import SwiftUI

@main
struct AirShoutApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
```

- [ ] **Step 3: 提交代码**

```bash
git add AirShout/AirShoutApp.swift AirShout/Views/ContentView.swift
git mv AirShout/Views/ContentView.swift AirShout/Views/MainTabView.swift
git commit -m "feat: add TabView for AirPlay and P2P modes"
```

---

## Task 5: 编译验证

- [ ] **Step 1: 运行编译命令**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: 提交**

```bash
git add -A
git commit -m "chore: verify build succeeds"
```

---

## 依赖关系

```
Task 1 (P2PAudioManager)
    ↓
Task 2 (P2PViewModel) ← 依赖 Task 1
    ↓
Task 3 (P2PView) ← 依赖 Task 2
    ↓
Task 4 (TabView) ← 依赖 Task 3
    ↓
Task 5 (Build) ← 验证所有任务
```

---

## 注意事项

1. **真机测试必需**：Multipeer Connectivity 在模拟器上无法正常工作，必须使用真机测试
2. **网络权限**：需要确保 Info.plist 中包含 `NSLocalNetworkUsageDescription`
3. **Bonjour 服务**：Multipeer Connectivity 使用 Bonjour，需要在 Info.plist 中声明 `NSBonjourServices`
