# AirShout - 隔空喊话功能设计文档

**日期：** 2026-04-12  
**状态：** 已批准

---

## 概述

iOS App "AirShout" 实现实时隔空喊话功能：用户对着 iOS 设备说话，声音实时传输到用户选择的 AirPlay 设备上播放。

---

## 交互设计

### 核心交互
- **实时传输模式**：用户按住说话按钮期间，麦克风音频实时流式传输到选定的 AirPlay 设备
- **设备选择**：用户从发现的所有 AirPlay 设备列表中选择目标设备
- **音量反馈**：实时显示麦克风音量波形

### App 状态
- **前台运行**：App 必须在前台运行才能进行喊话
- **后台停止**：进入后台时自动停止传输

---

## 技术架构

### 核心组件

#### 1. AudioManager（单例）
- 管理 `AVAudioEngine` 生命周期
- 配置 `AVAudioSession`（category: `.playAndRecord`，mode: `.voiceChat`）
- 处理音频路由到选定 AirPlay 设备
- 实时传递音频 buffer

**接口：**
```swift
class AudioManager {
    static let shared = AudioManager()
    
    func start()
    func stop()
    func setOutputDevice(deviceID: String)
    var audioLevelPublisher: AnyPublisher<Float, Never>  // 实时音量
    var isRunning: Bool
}
```

#### 2. DeviceDiscoveryManager（单例）
- 使用 `AVRouteDetector` 发现 AirPlay 设备
- 发布设备列表变化
- 提供设备选择

**接口：**
```swift
class DeviceDiscoveryManager {
    static let shared = DeviceDiscoveryManager()
    
    var availableDevices: [AVAudioSessionPortDescription]
    var selectedDevice: AVAudioSessionPortDescription?
    
    func selectDevice(_ device: AVAudioSessionPortDescription)
}
```

#### 3. ShoutViewModel
- 连接 UI 和 AudioManager
- 管理按住说话的状态
- 发布音量级别用于 UI 显示

**接口：**
```swift
class ShoutViewModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isShouting: Bool = false
    @Published var availableDevices: [Device] = []
    @Published var selectedDevice: Device?
    
    func startShout()
    func stopShout()
    func selectDevice(_ device: Device)
}
```

### 数据流

```
[麦克风] → [AVAudioEngine.inputNode] → [AudioManager] → [AVAudioEngine.outputNode] → [AirPlay设备]
                                    ↓
                              [音量计算] → [ViewModel] → [UI波形显示]
```

### 路由选择
- 使用 `AVAudioSession.sharedInstance().currentRoute` 获取当前输出设备
- 使用 `AVAudioSession.sharedInstance().overrideOutputAudioPort(.airPlay)` 路由到 AirPlay（注意：这是私有 API）
- **替代方案**：使用 `MPVolumeView` 的 `airPlayVolumeControl` 让用户手动选择 AirPlay 设备

> **注**：Apple 对直接路由音频到 AirPlay 的 API 有限制。实际实现可能需要使用 `MPVolumeView` 配合音频路由。

---

## UI 设计

### 主屏幕布局

```
┌─────────────────────────────────┐
│        AirShout                 │
├─────────────────────────────────┤
│  📢 选择设备                    │
│  ┌─────────────────────────┐   │
│  │ Apple TV (Living Room)  │   │
│  │ HomePod (Bedroom)       │   │
│  └─────────────────────────┘   │
│                                 │
│  ┌─────────────────────────┐   │
│  │ ▁▂▄▆█▇▅▃▁▂▄▆█▇▅▃▁▂▄▆  │   │  ← 实时波形
│  └─────────────────────────┘   │
│                                 │
│       ┌───────────────┐        │
│       │               │        │
│       │    按住说话    │        │  ← 主按钮
│       │               │        │
│       └───────────────┘        │
│                                 │
└─────────────────────────────────┘
```

### 设备选择列表
- 显示设备名称（`routeName`）
- 当前选中设备高亮
- 点击选择

### 波形显示
- 横向条形图
- 根据 `audioLevel` 实时更新
- 颜色：`tint` 颜色

### 说话按钮
- 圆形按钮，直径 120pt
- 按住时：`scale(0.95)` + 高亮
- 松开时恢复正常

---

## 错误处理

| 场景 | 处理 |
|------|------|
| 无麦克风权限 | 弹窗请求权限，拒绝时显示提示 |
| 无 AirPlay 设备 | 显示"未发现 AirPlay 设备" |
| 音频会话配置失败 | 打印错误，不崩溃 |
| 进入后台 | 自动停止喊话 |

---

## 文件结构

```
AirShout/
├── App/
│   └── AirShoutApp.swift
├── Models/
│   └── Device.swift
├── Managers/
│   ├── AudioManager.swift
│   └── DeviceDiscoveryManager.swift
├── ViewModels/
│   └── ShoutViewModel.swift
├── Views/
│   ├── ContentView.swift
│   ├── DeviceListView.swift
│   ├── WaveformView.swift
│   └── ShoutButton.swift
└── Resources/
    └── Info.plist
```

---

## 依赖

- **系统框架**：AVFoundation, AVFAudio, MediaPlayer, SwiftUI
- **无第三方依赖**

---

## 实现步骤概要

1. 配置 `Info.plist` 麦克风权限
2. 实现 `DeviceDiscoveryManager` 设备发现
3. 实现 `AudioManager` 音频管理
4. 实现 `ShoutViewModel` 视图模型
5. 实现 UI 组件（DeviceListView、WaveformView、ShoutButton）
6. 集成到 `ContentView`
7. 测试与调试
