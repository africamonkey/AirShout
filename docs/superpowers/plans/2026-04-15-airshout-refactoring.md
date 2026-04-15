# AirShout 重构计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除 AudioManager 和 P2PAudioManager 之间的代码重复，统一架构模式，增强线程安全性，优化文件组织。

**Architecture:** 提取公共 `AudioEngineProtocol` 协议和 `BaseAudioManager` 基类，将 Manager 单例改为依赖注入，分离关注点。

**Tech Stack:** Swift, AVFAudio, AVFoundation, SwiftUI, Combine

---

## 文件结构

```
AirShout/
├── Core/
│   ├── Audio/
│   │   ├── AudioEngineCore.swift       # 公共音频引擎逻辑
│   │   ├── AudioSessionConfig.swift    # AudioSession 配置
│   │   └── AudioLevelProcessor.swift   # 音量计算逻辑
│   ├── Protocols/
│   │   └── AudioManaging.swift        # 公共协议
│   └── Extensions/
│       └── Publishers+Extensions.swift # Combine 扩展
├── Features/
│   ├── AirPlay/
│   │   ├── AirPlayAudioManager.swift    # AirPlay 功能
│   │   └── AirPlayViewModel.swift       # AirPlay 视图模型
│   └── P2P/
│       ├── P2PAudioManager.swift        # P2P 功能
│       └── P2PViewModel.swift           # P2P 视图模型
├── Shared/
│   ├── Models/
│   │   └── ConnectionStatus.swift      # 共享状态枚举
│   └── Preferences/
│       └── UserPreferences.swift        # 统一 preferences
├── Managers/  # 旧文件，待删除
│   ├── AudioManager.swift              # DELETE
│   ├── P2PAudioManager.swift           # DELETE
│   ├── DevicePreferences.swift          # MOVE to Shared/Preferences
│   └── AppPreferences.swift            # MOVE to Shared/Preferences
├── ViewModels/  # 旧文件，待删除
│   └── ShoutViewModel.swift            # DELETE
├── Views/  # 保留但需修改
│   ├── ContentView.swift               # MODIFY
│   ├── P2PView.swift                   # MODIFY
│   ├── MainTabView.swift               # MODIFY
│   ├── DeviceListView.swift            # MODIFY
│   ├── AirPlayPicker.swift             # KEEP
│   ├── ShoutButton.swift               # KEEP
│   ├── WaveformView.swift             # KEEP
│   ├── ConnectionStatusView.swift     # KEEP
│   └── OnboardingView.swift            # KEEP
└── App/
    └── AirShoutApp.swift               # MODIFY
```

---

## Task 1: 创建公共协议 AudioManaging

**Files:**
- Create: `AirShout/Core/Protocols/AudioManaging.swift`
- Create: `AirShout/Core/Models/ConnectionStatus.swift`

```swift
import Foundation
import Combine

protocol AudioManaging: ObservableObject {
    var audioLevel: Float { get }
    var isRunning: Bool { get }
    var connectionStatus: ConnectionStatus { get }
    
    func start() async throws
    func stop()
}

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case transmitting
    case error(String)
    
    var isTransmitting: Bool {
        if case .transmitting = self { return true }
        return false
    }
}

enum AudioError: Error, LocalizedError {
    case microphonePermissionDenied
    case engineSetupFailed
    case noInputAvailable
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "麦克风权限被拒绝"
        case .engineSetupFailed:
            return "音频引擎设置失败"
        case .noInputAvailable:
            return "没有可用的输入设备"
        }
    }
}
```

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p AirShout/Core/Protocols
mkdir -p AirShout/Core/Models
mkdir -p AirShout/Features/AirPlay
mkdir -p AirShout/Features/P2P
mkdir -p AirShout/Shared/Models
mkdir -p AirShout/Shared/Preferences
```

- [ ] **Step 2: 创建 ConnectionStatus.swift**

```swift
import Foundation

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case transmitting
    case error(String)
    
    var isTransmitting: Bool {
        if case .transmitting = self { return true }
        return false
    }
}

enum AudioError: Error, LocalizedError {
    case microphonePermissionDenied
    case engineSetupFailed
    case noInputAvailable
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "麦克风权限被拒绝"
        case .engineSetupFailed:
            return "音频引擎设置失败"
        case .noInputAvailable:
            return "没有可用的输入设备，请确保已选择音频输出设备"
        }
    }
}
```

- [ ] **Step 3: 创建 AudioManaging.swift**

```swift
import Foundation
import Combine

protocol AudioManaging: ObservableObject {
    var audioLevel: Float { get }
    var isRunning: Bool { get }
    var connectionStatus: ConnectionStatus { get }
    
    func start() async throws
    func stop()
}
```

- [ ] **Step 4: 提交**

```bash
git add AirShout/Core/Protocols/AudioManaging.swift
git add AirShout/Core/Models/ConnectionStatus.swift
git commit -m "feat: add AudioManaging protocol and ConnectionStatus enum"
```

---

## Task 2: 创建音频核心处理模块

**Files:**
- Create: `AirShout/Core/Audio/AudioLevelProcessor.swift`
- Create: `AirShout/Core/Audio/AudioSessionConfig.swift`

```swift
import Foundation
import AVFAudio

struct AudioLevelProcessor {
    private var lastUpdateTime: TimeInterval = 0
    private let updateInterval: TimeInterval = 0.05
    
    func calculateLevel(from buffer: AVAudioPCMBuffer) -> Float? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let channelDataValue = channelData.pointee
        
        var sum: Float = 0
        for i in stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride) {
            let sample = channelDataValue[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        let avgPower = 20 * log10(max(rms, 0.000001))
        return max(0, min(1, (avgPower + 50) / 50))
    }
    
    func shouldUpdate(now: TimeInterval) -> Bool {
        guard now - lastUpdateTime >= updateInterval else { return false }
        lastUpdateTime = now
        return true
    }
}

struct AudioSessionConfig {
    static func configure(_ session: AVAudioSession) throws {
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetoothA2DP, .allowBluetoothHFP, .allowAirPlay]
        )
        
        let preferredSampleRate: Double = 44100
        try session.setPreferredSampleRate(preferredSampleRate)
        
        try session.setActive(true)
    }
    
    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
```

- [ ] **Step 1: 创建 AudioLevelProcessor.swift**

```swift
import Foundation
import AVFAudio

struct AudioLevelProcessor {
    private var lastUpdateTime: TimeInterval = 0
    private let updateInterval: TimeInterval = 0.05
    
    func calculateLevel(from buffer: AVAudioPCMBuffer) -> Float? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let channelDataValue = channelData.pointee
        
        var sum: Float = 0
        for i in stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride) {
            let sample = channelDataValue[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        let avgPower = 20 * log10(max(rms, 0.000001))
        return max(0, min(1, (avgPower + 50) / 50))
    }
    
    func shouldUpdate(now: TimeInterval) -> Bool {
        guard now - lastUpdateTime >= updateInterval else { return false }
        lastUpdateTime = now
        return true
    }
}
```

- [ ] **Step 2: 创建 AudioSessionConfig.swift**

```swift
import Foundation
import AVFAudio

struct AudioSessionConfig {
    static func configure(_ session: AVAudioSession) throws {
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetoothA2DP, .allowBluetoothHFP, .allowAirPlay]
        )
        
        let preferredSampleRate: Double = 44100
        try session.setPreferredSampleRate(preferredSampleRate)
        
        try session.setActive(true)
    }
    
    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
```

- [ ] **Step 3: 提交**

```bash
git add AirShout/Core/Audio/AudioLevelProcessor.swift
git add AirShout/Core/Audio/AudioSessionConfig.swift
git commit -m "feat: add AudioLevelProcessor and AudioSessionConfig"
```

---

## Task 3: 重构 AudioManager 为 AirPlayAudioManager

**Files:**
- Create: `AirShout/Features/AirPlay/AirPlayAudioManager.swift`
- Delete: `AirShout/Managers/AudioManager.swift`

```swift
import Foundation
import AVFAudio
import Combine

final class AirPlayAudioManager: AudioManaging {
    static let shared = AirPlayAudioManager()
    
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    private var audioEngine: AVAudioEngine?
    private let audioSession = AVAudioSession.sharedInstance()
    private var playerNode: AVAudioPlayerNode?
    private var routeChangeObserver: NSObjectProtocol?
    private var isSessionConfigured = false
    private var isRestarting = false
    
    private let engineQueue = DispatchQueue(label: "com.airshout.airplay.audioengine")
    private let stateQueue = DispatchQueue(label: "com.airshout.airplay.state")
    
    private let levelProcessor = AudioLevelProcessor()
    
    private init() {
        setupRouteChangeObserver()
    }
    
    private func setupRouteChangeObserver() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }
    
    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .override, .routeConfigurationChange:
            let running = isRunning
            if running && !isRestarting {
                isRestarting = true
                engineQueue.async { [weak self] in
                    self?.restartEngineInternal()
                    self?.isRestarting = false
                }
            }
        default:
            break
        }
    }
    
    private func restartEngineInternal() {
        stopEngineOnly()
        
        do {
            try setupAndStartEngine()
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = true
            }
        } catch AudioError.noInputAvailable {
            print("Failed to restart engine: noInputAvailable")
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.audioLevel = 0
                self?.connectionStatus = .error("没有可用的输入设备")
            }
        } catch {
            print("Failed to restart engine: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.connectionStatus = .disconnected
            }
        }
    }
    
    func start() async throws {
        connectionStatus = .connecting
        
        let granted = await AudioSessionConfig.requestMicrophonePermission()
        guard granted else {
            connectionStatus = .disconnected
            throw AudioError.microphonePermissionDenied
        }
        
        if !isSessionConfigured {
            try AudioSessionConfig.configure(audioSession)
            isSessionConfigured = true
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            engineQueue.async {
                do {
                    try self.setupAndStartEngine()
                    UserPreferences.shared.saveCurrentDeviceUID()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        DispatchQueue.main.async { [weak self] in
            self?.isRunning = true
            self?.connectionStatus = .connected
        }
    }
    
    private func setupAndStartEngine() throws {
        playerNode?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        
        guard let availableInputs = audioSession.availableInputs, !availableInputs.isEmpty else {
            throw AudioError.noInputAvailable
        }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioError.engineSetupFailed
        }
        
        let inputNode = audioEngine.inputNode
        let outputNode = audioEngine.outputNode
        let mainMixer = audioEngine.mainMixerNode
        
        playerNode = AVAudioPlayerNode()
        guard let playerNode = playerNode else {
            throw AudioError.engineSetupFailed
        }
        audioEngine.attach(playerNode)
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = outputNode.inputFormat(forBus: 0)
        
        guard inputFormat.sampleRate > 0 else {
            throw AudioError.noInputAvailable
        }
        
        audioEngine.connect(playerNode, to: mainMixer, format: inputFormat)
        audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)
        
        let levelProcessor = self.levelProcessor
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processAudioBuffer(buffer, processor: levelProcessor)
            guard self.isRunning else { return }
            self.playerNode?.scheduleBuffer(buffer, completionHandler: nil)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        playerNode.play()
    }
    
    private func stopEngineOnly() {
        playerNode?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }
    
    func stop() {
        engineQueue.async { [weak self] in
            self?.stopEngineOnly()
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.audioLevel = 0
                self?.connectionStatus = .disconnected
            }
        }
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, processor: AudioLevelProcessor) {
        let now = Date().timeIntervalSinceReferenceDate
        guard processor.shouldUpdate(now: now) else { return }
        
        guard let level = processor.calculateLevel(from: buffer) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = level
            if !(self?.connectionStatus.isTransmitting ?? false) && level > 0.01 {
                self?.connectionStatus = .transmitting
            }
        }
    }
}
```

- [ ] **Step 1: 创建 AirPlayAudioManager.swift**

使用上面的完整代码创建文件。

- [ ] **Step 2: 验证编译**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | head -50
```

预期：编译警告（缺少 UserPreferences），但无语法错误。

- [ ] **Step 3: 提交**

```bash
git add AirShout/Features/AirPlay/AirPlayAudioManager.swift
git commit -m "feat: create AirPlayAudioManager using AudioManaging protocol"
```

---

## Task 4: 创建统一偏好设置管理

**Files:**
- Create: `AirShout/Shared/Preferences/UserPreferences.swift`
- Delete: `AirShout/Managers/DevicePreferences.swift`
- Delete: `AirShout/Managers/AppPreferences.swift`

```swift
import Foundation
import AVFAudio

final class UserPreferences {
    static let shared = UserPreferences()
    
    private enum Keys {
        static let lastDeviceUID = "com.airshout.lastDeviceUID"
        static let hasCompletedOnboarding = "com.airshout.hasCompletedOnboarding"
        static let p2pNickname = "com.airshout.p2pNickname"
    }
    
    private init() {}
    
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
    
    var p2pNickname: String {
        get { UserDefaults.standard.string(forKey: Keys.p2pNickname) ?? UIDevice.current.name }
        set { UserDefaults.standard.set(newValue, forKey: Keys.p2pNickname) }
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
    
    func restoreDeviceIfNeeded() async -> Bool {
        guard let savedUID = loadDeviceUID() else { return false }
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        
        return currentRoute.outputs.contains { $0.uid == savedUID }
    }
}
```

- [ ] **Step 1: 创建 UserPreferences.swift**

```bash
mkdir -p AirShout/Shared/Preferences
```

使用上面的代码创建文件。

- [ ] **Step 2: 更新引用 UserPreferences 的文件**

需要修改的文件：
- `AirShout/Features/AirPlay/AirPlayAudioManager.swift` - import 并使用

- [ ] **Step 3: 验证编译**

- [ ] **Step 4: 提交**

```bash
git add AirShout/Shared/Preferences/UserPreferences.swift
git commit -m "feat: consolidate preferences into UserPreferences"
```

---

## Task 5: 重构 P2PAudioManager

**Files:**
- Modify: `AirShout/Features/P2P/P2PAudioManager.swift` (大幅简化)
- Delete: `AirShout/Managers/P2PAudioManager.swift`

```swift
import Foundation
import MultipeerConnectivity
import AVFAudio
import Combine

struct P2PDevice: Identifiable, Equatable {
    let id: MCPeerID
    var displayName: String
    var isConnected: Bool
    
    static func == (lhs: P2PDevice, rhs: P2PDevice) -> Bool {
        lhs.id == rhs.id
    }
}

final class P2PAudioManager: NSObject, AudioManaging {
    static let shared = P2PAudioManager()
    
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    @Published private(set) var peers: [MCPeerID] = []
    
    private let serviceType = "airshout-p2p"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    private var audioEngine: AVAudioEngine?
    private let audioSession = AVAudioSession.sharedInstance()
    private var playerNode: AVAudioPlayerNode?
    private let engineQueue = DispatchQueue(label: "com.airshout.p2paudioengine")
    private let levelProcessor = AudioLevelProcessor()
    
    private var _audioEngineRunning = false
    private let stateQueue = DispatchQueue(label: "com.airshout.p2pstate")
    private var invitedPeers: Set<MCPeerID> = []
    
    private override init() {
        super.init()
        setupMultipeer()
    }
    
    private func setupMultipeer() {
        let nickname = UserPreferences.shared.p2pNickname
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
    
    var devices: [P2PDevice] {
        peers.map { peerID in
            P2PDevice(
                id: peerID,
                displayName: peerID.displayName,
                isConnected: true
            )
        }
    }
    
    func start() async throws {
        let granted = await AudioSessionConfig.requestMicrophonePermission()
        guard granted else {
            throw AudioError.microphonePermissionDenied
        }
        
        guard !session.connectedPeers.isEmpty else {
            throw P2PError.notConnected
        }
        
        do {
            try AudioSessionConfig.configure(audioSession)
        } catch {
            throw AudioError.engineSetupFailed
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            engineQueue.async {
                self.stateQueue.async {
                    self._audioEngineRunning = true
                }
                do {
                    try self.setupAudioEngineForSpeaking()
                    continuation.resume()
                } catch {
                    self.stateQueue.async {
                        self._audioEngineRunning = false
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.isRunning = true
            self?.connectionStatus = .connected
        }
    }
    
    private func setupAudioEngineForSpeaking() throws {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioError.engineSetupFailed
        }
        
        let inputNode = audioEngine.inputNode
        let outputNode = audioEngine.outputNode
        let mainMixer = audioEngine.mainMixerNode
        
        playerNode = AVAudioPlayerNode()
        guard let playerNode = playerNode else {
            throw AudioError.engineSetupFailed
        }
        audioEngine.attach(playerNode)
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = outputNode.inputFormat(forBus: 0)
        
        guard inputFormat.sampleRate > 0 else {
            throw AudioError.engineSetupFailed
        }
        
        audioEngine.connect(playerNode, to: mainMixer, format: inputFormat)
        audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)
        
        let connectedPeers = session.connectedPeers
        let levelProcessor = self.levelProcessor
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            guard self._audioEngineRunning else { return }
            guard !connectedPeers.isEmpty else { return }
            
            self.processAudioLevel(buffer, processor: levelProcessor)
            
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            
            let dataSize = frameLength * MemoryLayout<Float>.size
            let data = Data(bytes: channelData[0], count: dataSize)
            
            do {
                try self.session.send(data, toPeers: connectedPeers, with: .unreliable)
            } catch {
                print("Failed to send audio data: \(error)")
            }
            
            self.playerNode?.scheduleBuffer(buffer, completionHandler: nil)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        playerNode.play()
    }
    
    private func setupAudioEngineForReceiving() {
        guard audioEngine == nil else { return }
        
        do {
            try AudioSessionConfig.configure(audioSession)
        } catch {
            print("Failed to configure audio session for receiving: \(error)")
            return
        }
        
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }
        
        let outputNode = audioEngine.outputNode
        let mainMixer = audioEngine.mainMixerNode
        
        playerNode = AVAudioPlayerNode()
        guard let playerNode = playerNode else { return }
        audioEngine.attach(playerNode)
        
        let outputFormat = outputNode.inputFormat(forBus: 0)
        
        audioEngine.connect(playerNode, to: mainMixer, format: outputFormat)
        audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine for receiving: \(error)")
            return
        }
        playerNode.play()
    }
    
    private func stopAudioEngineForReceiving() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }
    
    private func processAudioLevel(_ buffer: AVAudioPCMBuffer, processor: AudioLevelProcessor) {
        let now = Date().timeIntervalSinceReferenceDate
        guard processor.shouldUpdate(now: now) else { return }
        
        guard let level = processor.calculateLevel(from: buffer) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = level
            if level > 0.01 {
                self?.connectionStatus = .transmitting
            }
        }
    }
    
    func stop() {
        engineQueue.async { [weak self] in
            self?.stateQueue.async {
                self?._audioEngineRunning = false
            }
            self?.playerNode?.stop()
            self?.audioEngine?.inputNode.removeTap(onBus: 0)
            self?.audioEngine?.stop()
            self?.audioEngine = nil
            self?.playerNode = nil
            
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.audioLevel = 0
                if self?.peers.isEmpty == true {
                    self?.connectionStatus = .disconnected
                } else {
                    self?.connectionStatus = .connected
                }
            }
        }
    }
    
    func shutdown() {
        stop()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        invitedPeers.removeAll()
        
        DispatchQueue.main.async { [weak self] in
            self?.peers = []
            self?.connectionStatus = .disconnected
        }
    }
    
    func restartBrowsing() {
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        session?.disconnect()
        invitedPeers.removeAll()
        peers.removeAll()
        
        setupMultipeer()
    }
    
    private func playAudioData(_ data: Data) {
        engineQueue.async { [weak self] in
            guard let self = self, let audioEngine = self.audioEngine else { return }
            guard let playerNode = self.playerNode else { return }
            
            let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Float>.size)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else {
                return
            }
            
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
}

enum P2PError: Error, LocalizedError {
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "没有连接到任何设备"
        }
    }
}

extension P2PAudioManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .notConnected:
                self?.peers.removeAll { $0 == peerID }
                self?.invitedPeers.remove(peerID)
                if self?.peers.isEmpty == true {
                    self?.connectionStatus = .disconnected
                    self?.stopAudioEngineForReceiving()
                }
            case .connecting:
                self?.connectionStatus = .connecting
            case .connected:
                if !(self?.peers.contains(peerID) ?? false) {
                    self?.peers.append(peerID)
                }
                self?.connectionStatus = .connected
                self?.setupAudioEngineForReceiving()
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        playAudioData(data)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension P2PAudioManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to advertise: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = .error("广播失败: \(error.localizedDescription)")
        }
    }
}

extension P2PAudioManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        if !invitedPeers.contains(peerID) && session.connectedPeers.isEmpty {
            invitedPeers.insert(peerID)
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.peers.removeAll { $0 == peerID }
            self?.invitedPeers.remove(peerID)
            if self?.peers.isEmpty == true {
                self?.connectionStatus = .disconnected
            }
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Failed to browse: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = .error("浏览失败: \(error.localizedDescription)")
        }
    }
}
```

- [ ] **Step 1: 创建 Features/P2P 目录**

```bash
mkdir -p AirShout/Features/P2P
```

- [ ] **Step 2: 创建 P2PAudioManager.swift**

使用上面的代码创建文件。

- [ ] **Step 3: 验证编译**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | head -100
```

- [ ] **Step 4: 提交**

```bash
git add AirShout/Features/P2P/P2PAudioManager.swift
git commit -m "refactor: rewrite P2PAudioManager to use shared AudioManaging protocol"
```

---

## Task 6: 创建 AirPlayViewModel

**Files:**
- Create: `AirShout/Features/AirPlay/AirPlayViewModel.swift`
- Delete: `AirShout/ViewModels/ShoutViewModel.swift`

```swift
import Foundation
import Combine

final class AirPlayViewModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isShouting: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private let audioManager: AudioManaging
    private var cancellables = Set<AnyCancellable>()
    
    init(audioManager: AudioManaging = AirPlayAudioManager.shared) {
        self.audioManager = audioManager
        setupBindings()
    }
    
    private func setupBindings() {
        audioManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
        
        audioManager.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isShouting)
        
        audioManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionStatus)
    }
    
    func startShout() {
        Task { @MainActor in
            do {
                try await audioManager.start()
            } catch AudioError.microphonePermissionDenied {
                showPermissionAlert = true
            } catch {
                print("Failed to start audio: \(error)")
            }
        }
    }
    
    func stopShout() {
        audioManager.stop()
    }
}
```

- [ ] **Step 1: 创建 AirPlayViewModel.swift**

使用上面的代码创建文件。

- [ ] **Step 2: 验证编译**

- [ ] **Step 3: 提交**

```bash
git add AirShout/Features/AirPlay/AirPlayViewModel.swift
git commit -m "feat: add AirPlayViewModel with dependency injection support"
```

---

## Task 7: 创建 P2PViewModel

**Files:**
- Create: `AirShout/Features/P2P/P2PViewModel.swift`

```swift
import Foundation
import Combine

final class P2PViewModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isShouting: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var devices: [P2PDevice] = []
    @Published var showPermissionAlert: Bool = false
    
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
        
        audioManager.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isShouting)
        
        audioManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionStatus)
        
        audioManager.$peers
            .receive(on: DispatchQueue.main)
            .map { peers in
                peers.map { peerID in
                    P2PDevice(
                        id: peerID,
                        displayName: peerID.displayName,
                        isConnected: true
                    )
                }
            }
            .assign(to: &$devices)
    }
    
    func startShout() {
        Task { @MainActor in
            do {
                try await audioManager.start()
            } catch AudioError.microphonePermissionDenied {
                showPermissionAlert = true
            } catch {
                print("Failed to start audio: \(error)")
            }
        }
    }
    
    func stopShout() {
        audioManager.stop()
    }
    
    func restartDiscovery() {
        audioManager.restartBrowsing()
    }
}
```

- [ ] **Step 1: 创建 P2PViewModel.swift**

使用上面的代码创建文件。

- [ ] **Step 2: 验证编译**

- [ ] **Step 3: 提交**

```bash
git add AirShout/Features/P2P/P2PViewModel.swift
git commit -m "feat: add P2PViewModel with dependency injection support"
```

---

## Task 8: 更新 Views 使用新的 ViewModels

**Files:**
- Modify: `AirShout/Views/ContentView.swift`
- Modify: `AirShout/Views/P2PView.swift`
- Modify: `AirShout/Views/MainTabView.swift`
- Modify: `AirShout/Views/DeviceListView.swift`
- Modify: `AirShout/AirShoutApp.swift`

```swift
import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AirPlayViewModel()
    @State private var showOnboarding = !UserPreferences.shared.hasCompletedOnboarding
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                HStack {
                    Text("AirShout")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    ConnectionStatusView(status: viewModel.connectionStatus)
                }
                .padding(.top, 20)
                
                DeviceListView()
                
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
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .onDisappear {
                    UserPreferences.shared.hasCompletedOnboarding = true
                }
        }
    }
}
```

- [ ] **Step 1: 更新 ContentView.swift**

将 `@StateObject private var viewModel = ShoutViewModel()` 改为 `AirPlayViewModel()`，将 `AppPreferences.hasCompletedOnboarding` 改为 `UserPreferences.shared.hasCompletedOnboarding`。

- [ ] **Step 2: 更新 P2PView.swift**

读取现有的 P2PView.swift，然后用 P2PViewModel 替换直接对 P2PAudioManager 的调用。

- [ ] **Step 3: 更新 MainTabView.swift**

保持不变，因为它是简单的 TabView。

- [ ] **Step 4: 更新 DeviceListView.swift**

```swift
import SwiftUI
import AVKit
import AVFAudio

struct DeviceListView: View {
    @State private var currentRouteName: String = "未选择设备"
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("选择设备")
                    .font(.headline)
                Spacer()
                AirPlayPicker()
                    .frame(width: 44, height: 32)
            }
            .padding(.horizontal)
            .padding(.top, 4)
            
            Text(currentRouteName)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 4)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            updateRouteName()
        }
    }
    
    private func updateRouteName() {
        let session = AVAudioSession.sharedInstance()
        currentRouteName = session.currentRoute.outputs.first?.portName ?? "未选择设备"
    }
}
```

注意移除了手动添加的 route observer，因为 AVAudioSession.currentRoute 可以在需要时直接访问。

- [ ] **Step 5: 验证编译**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | head -100
```

- [ ] **Step 6: 提交**

```bash
git add AirShout/Views/ContentView.swift
git add AirShout/Views/P2PView.swift
git add AirShout/Views/DeviceListView.swift
git commit -m "refactor: update views to use new ViewModels with dependency injection"
```

---

## Task 9: 删除旧文件

**Files:**
- Delete: `AirShout/Managers/AudioManager.swift`
- Delete: `AirShout/Managers/P2PAudioManager.swift`
- Delete: `AirShout/Managers/DevicePreferences.swift`
- Delete: `AirShout/Managers/AppPreferences.swift`
- Delete: `AirShout/ViewModels/ShoutViewModel.swift`

- [ ] **Step 1: 删除旧文件**

```bash
git rm AirShout/Managers/AudioManager.swift
git rm AirShout/Managers/P2PAudioManager.swift
git rm AirShout/Managers/DevicePreferences.swift
git rm AirShout/Managers/AppPreferences.swift
git rm AirShout/ViewModels/ShoutViewModel.swift
```

- [ ] **Step 2: 验证编译**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -50
```

- [ ] **Step 3: 提交**

```bash
git commit -m "chore: remove old Manager files after refactoring"
```

---

## Task 10: 最终验证

**Files:**
- None (verification only)

- [ ] **Step 1: 完整编译**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build
```

- [ ] **Step 2: 运行测试**

```bash
xcodebuild -scheme AirShoutTests -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' test
```

- [ ] **Step 3: 检查文件结构**

```bash
find AirShout -name "*.swift" -type f | sort
```

预期结构：
```
AirShout/
├── App/
│   └── AirShoutApp.swift
├── Core/
│   ├── Audio/
│   │   ├── AudioLevelProcessor.swift
│   │   └── AudioSessionConfig.swift
│   ├── Models/
│   │   └── ConnectionStatus.swift
│   └── Protocols/
│       └── AudioManaging.swift
├── Features/
│   ├── AirPlay/
│   │   ├── AirPlayAudioManager.swift
│   │   └── AirPlayViewModel.swift
│   └── P2P/
│       ├── P2PAudioManager.swift
│       └── P2PViewModel.swift
├── Shared/
│   └── Preferences/
│       └── UserPreferences.swift
└── Views/
    ├── AirPlayPicker.swift
    ├── ConnectionStatusView.swift
    ├── ContentView.swift
    ├── DeviceListView.swift
    ├── MainTabView.swift
    ├── OnboardingView.swift
    ├── P2PView.swift
    ├── ShoutButton.swift
    └── WaveformView.swift
```

- [ ] **Step 4: 提交**

```bash
git commit -m "chore: complete refactoring - unified architecture with dependency injection"
```

---

## 验证清单

- [ ] AudioManager 和 P2PAudioManager 共享 AudioLevelProcessor
- [ ] AudioManaging 协议统一定义接口
- [ ] AirPlayAudioManager 和 P2PAudioManager 都遵循 AudioManaging 协议
- [ ] AirPlayViewModel 和 P2PViewModel 都可以通过依赖注入替换实现
- [ ] 所有旧的 Manager 文件已删除
- [ ] UserPreferences 统一管理所有偏好设置
- [ ] 编译通过
- [ ] 测试通过

---

## 实施顺序

1. Task 1: 创建公共协议和模型
2. Task 2: 创建音频核心处理模块
3. Task 3: 创建 AirPlayAudioManager
4. Task 4: 创建统一 UserPreferences
5. Task 5: 重构 P2PAudioManager
6. Task 6: 创建 AirPlayViewModel
7. Task 7: 创建 P2PViewModel
8. Task 8: 更新 Views
9. Task 9: 删除旧文件
10. Task 10: 最终验证

**Plan complete and saved to `docs/superpowers/plans/2026-04-15-airshout-refactoring.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
