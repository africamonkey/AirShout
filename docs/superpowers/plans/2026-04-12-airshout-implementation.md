# AirShout 隔空喊话实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现实时隔空喊话功能 - 用户按住说话按钮时，麦克风音频实时传输到选定的 AirPlay 设备播放。

**Architecture:** 使用 AVAudioEngine 采集麦克风音频，通过 AVAudioPlayerNode 播放到输出设备。音频路由通过 AVAudioSession 和 MPVolumeView 处理。

**Tech Stack:** Swift, AVFAudio, AVFoundation, MediaPlayer, SwiftUI

---

## 文件结构

```
AirShout/
├── Managers/
│   ├── AudioManager.swift      # 音频采集和播放核心
│   ├── AudioRouter.swift       # AirPlay 路由选择
│   └── DeviceDiscoveryManager.swift  # 设备发现
├── Models/
│   └── Device.swift           # 设备模型
├── ViewModels/
│   └── ShoutViewModel.swift   # 视图模型
└── Views/
    ├── ContentView.swift      # 主界面
    ├── DeviceListView.swift   # 设备选择列表
    ├── WaveformView.swift     # 音量波形
    └── ShoutButton.swift      # 按住说话按钮
```

---

## Task 1: 修复 AudioManager

**Files:**
- Modify: `AirShout/Managers/AudioManager.swift`

当前实现使用了不存在的 API（`enableManualRoutingMode`、`manualRoutingRoute`、`AVAudioRoutingRoute`），需要重写为正确的 AVAudioEngine 音频循环方案。

- [ ] **Step 1: 重写 AudioManager 使用正确的 AVAudioEngine 架构**

```swift
import Foundation
import AVFAudio
import Combine

final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var audioLevel: Float = 0
    @Published var isRunning: Bool = false

    private var audioEngine: AVAudioEngine?
    private let audioSession = AVAudioSession.sharedInstance()
    private var playerNode: AVAudioPlayerNode?

    var audioLevelPublisher: AnyPublisher<Float, Never> {
        $audioLevel.eraseToAnyPublisher()
    }

    private init() {}

    func start() throws {
        try configureAudioSession()

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let outputNode = audioEngine.outputNode
        let mainMixer = audioEngine.mainMixerNode

        playerNode = AVAudioPlayerNode()
        guard let playerNode = playerNode else { return }
        audioEngine.attach(playerNode)

        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = outputNode.inputFormat(forBus: 0)

        audioEngine.connect(playerNode, to: mainMixer, format: inputFormat)
        audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
            self?.playerNode?.scheduleBuffer(buffer, completionHandler: nil)
        }

        audioEngine.prepare()
        try audioEngine.start()
        try playerNode.play()

        isRunning = true
    }

    func stop() {
        playerNode?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        isRunning = false
        audioLevel = 0
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth, .allowAirPlay])
        try audioSession.setActive(true)
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }

        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = normalizedLevel
        }
    }
}
```

- [ ] **Step 2: 验证代码语法正确**

在 Xcode 中编译确认无语法错误。

- [ ] **Step 3: 提交**

```bash
git add AirShout/Managers/AudioManager.swift
git commit -m "fix: rewrite AudioManager with correct AVAudioEngine architecture"
```

---

## Task 2: 修复 ShoutViewModel

**Files:**
- Modify: `AirShout/ViewModels/ShoutViewModel.swift`

当前 ShoutViewModel 中的 `onRelease` 闭包不存在于 ShoutButton，需要更新接口保持一致。

- [ ] **Step 1: 检查 ShoutButton 接口**

```swift
// ShoutButton 当前接口：
struct ShoutButton: View {
    let isPressed: Bool
    let onPress: () -> Void
    let onRelease: () -> Void
    // ...
}
```

接口已正确，有 `onRelease`。检查 ShoutViewModel 是否正确调用。

- [ ] **Step 2: 验证 ShoutViewModel 代码**

读取 `AirShout/ViewModels/ShoutViewModel.swift` 确认实现正确。

- [ ] **Step 3: 提交**

```bash
git add AirShout/ViewModels/ShoutViewModel.swift
git commit -m "chore: verify ShoutViewModel implementation"
```

---

## Task 3: 修复 ContentView

**Files:**
- Modify: `AirShout/Views/ContentView.swift`

ShoutButton 需要两个闭包参数，当前只传了一个。

- [ ] **Step 1: 更新 ContentView 调用 ShoutButton**

```swift
ShoutButton(isPressed: viewModel.isShouting) {
    viewModel.startShout()
} onRelease: {
    viewModel.stopShout()
}
```

- [ ] **Step 2: 验证 ContentView 编译通过**

- [ ] **Step 3: 提交**

```bash
git add AirShout/Views/ContentView.swift
git commit -m "fix: pass both onPress and onRelease to ShoutButton"
```

---

## Task 4: 添加后台音频能力（可选但推荐）

**Files:**
- Modify: `AirShout.xcodeproj/project.pbxproj`

需要启用后台音频模式才能在某些场景下保持音频传输。

- [ ] **Step 1: 添加 UIBackgroundModes 到 Info.plist 设置**

在 project.pbxproj 的 INFOPLIST_KEY 设置中添加：
```
INFOPLIST_KEY_UIBackgroundModes = "audio"
```

注意：这需要手动在 Xcode 中设置或创建 Info.plist 文件。暂时跳过，在 Xcode 中手动配置。

- [ ] **Step 2: 提交说明**

```bash
git commit -m "chore: note to enable background audio mode in Xcode"
```

---

## Task 5: 添加麦克风权限请求

**Files:**
- Modify: `AirShout/Managers/AudioManager.swift`

在 start() 方法中添加麦克风权限检查和请求。

- [ ] **Step 1: 添加权限请求代码到 AudioManager**

```swift
import AVFAudio

func requestMicrophonePermission() async -> Bool {
    return await withCheckedContinuation { continuation in
        AVAudioApplication.requestRecordPermission { granted in
            continuation.resume(returning: granted)
        }
    }
}

func start() throws {
    // 在 configureAudioSession 之前检查权限
    let granted = await requestMicrophonePermission()
    guard granted else {
        throw AudioError.microphonePermissionDenied
    }
    try configureAudioSession()
    // ... rest of implementation
}
```

添加 `enum AudioError: Error` 类型处理权限拒绝情况。

- [ ] **Step 2: 提交**

```bash
git add AirShout/Managers/AudioManager.swift
git commit -m "feat: add microphone permission request"
```

---

## Task 6: 测试与调试

**Files:**
- Test on physical iOS device (模拟器不支持 AirPlay)

- [ ] **Step 1: 在真机上编译运行**

```bash
# 在 Xcode 中选择真机设备并运行
xcodebuild -scheme AirShout -destination 'platform=iOS Device' build
```

- [ ] **Step 2: 验证功能**
- [ ] 验证设备列表显示可用 AirPlay 设备
- [ ] 验证按住说话时波形显示
- [ ] 验证音频传输到 AirPlay 设备
- [ ] 验证进入后台时自动停止

---

## Task 7: 清理 DeviceDiscoveryManager（如果不需要可删除）

当前实现中 DeviceDiscoveryManager 未被使用，AudioRouter 已处理设备选择。可以选择保留或删除。

- [ ] **Step 1: 评估是否需要 DeviceDiscoveryManager**

如果不需要可删除：
```bash
git rm AirShout/Managers/DeviceDiscoveryManager.swift
git rm AirShout/Models/Device.swift
git commit -m "chore: remove unused DeviceDiscoveryManager"
```

---

## 实施顺序

1. Task 1: 修复 AudioManager（核心功能）
2. Task 2: 验证 ShoutViewModel
3. Task 3: 修复 ContentView
4. Task 5: 添加麦克风权限请求
5. Task 6: 测试与调试
6. Task 7（可选）: 清理

---

## 验证清单

- [ ] 麦克风权限弹窗正常显示
- [ ] AirPlay 设备列表正确显示（通过 MPVolumeView picker）
- [ ] 按住说话时波形实时更新
- [ ] 音频实时传输到 AirPlay 设备
- [ ] 松开按钮停止传输
- [ ] 进入后台自动停止
