# AirShout 本地化实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 AirShout 添加中英文本地化支持，所有 UI 文本使用 `Localizable.xcstrings` 管理

**Architecture:** 使用 SwiftUI 内置本地化机制，App 跟随 iOS 系统语言设置。创建 `.xcstrings` 文件存储翻译键值对，替换所有硬编码字符串。

**Tech Stack:** SwiftUI, .xcstrings (Xcode 现代本地化格式)

---

## 文件结构

- 创建: `AirShout/Resources/Localizable.xcstrings`
- 修改: `AirShout/Views/ContentView.swift`
- 修改: `AirShout/Views/OnboardingView.swift`
- 修改: `AirShout/Views/DeviceListView.swift`
- 修改: `AirShout/Views/ConnectionStatusView.swift`
- 修改: `AirShout/Views/Network/NetworkView.swift`
- 修改: `AirShout/Views/Network/LocalInfoView.swift`
- 修改: `AirShout/Views/Network/ConnectionListView.swift`
- 修改: `AirShout/Views/P2PView.swift`
- 修改: `AirShout/Views/ShoutButton.swift`
- 修改: `AirShout/Views/MainTabView.swift`

---

## Task 1: 创建 Localizable.xcstrings 文件

**Files:**
- 创建: `AirShout/Resources/Localizable.xcstrings`

- [ ] **Step 1: 创建目录结构**

```bash
mkdir -p AirShout/Resources
```

- [ ] **Step 2: 创建 Localizable.xcstrings 文件**

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "tab.airplay" : {
      "en" : "AirPlay Shout",
      "zh-Hans" : "AirPlay 喊话"
    },
    "tab.nearby" : {
      "en" : "Nearby",
      "zh-Hans" : "附近设备"
    },
    "tab.manual" : {
      "en" : "Manual Connect",
      "zh-Hans" : "手动连接"
    },
    "content.airplay.title" : {
      "en" : "Shout to AirPlay",
      "zh-Hans" : "向 AirPlay 设备喊话"
    },
    "content.airplay.permission.title" : {
      "en" : "Microphone Access Denied",
      "zh-Hans" : "麦克风权限被拒绝"
    },
    "content.airplay.permission.message" : {
      "en" : "Please enable microphone access in Settings to use AirShout",
      "zh-Hans" : "请在设置中开启麦克风权限以使用隔空喊话功能"
    },
    "content.airplay.permission.settings" : {
      "en" : "Open Settings",
      "zh-Hans" : "打开设置"
    },
    "device.select" : {
      "en" : "Select Device",
      "zh-Hans" : "选择设备"
    },
    "device.none" : {
      "en" : "No Device Selected",
      "zh-Hans" : "未选择设备"
    },
    "status.disconnected" : {
      "en" : "Disconnected",
      "zh-Hans" : "未连接"
    },
    "status.connecting" : {
      "en" : "Connecting...",
      "zh-Hans" : "连接中..."
    },
    "status.connected" : {
      "en" : "Connected",
      "zh-Hans" : "已连接"
    },
    "status.transmitting" : {
      "en" : "Transmitting",
      "zh-Hans" : "传输中"
    },
    "shout.start" : {
      "en" : "Start",
      "zh-Hans" : "开始"
    },
    "shout.stop" : {
      "en" : "Stop",
      "zh-Hans" : "停止"
    },
    "network.title" : {
      "en" : "Enter IP Address to Connect",
      "zh-Hans" : "手动输入 IP 地址连接"
    },
    "network.pro" : {
      "en" : "(Pro)",
      "zh-Hans" : "（专业版）"
    },
    "network.start.send" : {
      "en" : "Start Sending",
      "zh-Hans" : "开始发送"
    },
    "network.stop.send" : {
      "en" : "Stop Sending",
      "zh-Hans" : "停止发送"
    },
    "network.error" : {
      "en" : "Error",
      "zh-Hans" : "错误"
    },
    "local.ip" : {
      "en" : "Local IP:",
      "zh-Hans" : "本机IP:"
    },
    "local.port" : {
      "en" : "Receive Port:",
      "zh-Hans" : "接收端口:"
    },
    "local.port.placeholder" : {
      "en" : "Port",
      "zh-Hans" : "端口"
    },
    "local.start.receive" : {
      "en" : "Start Receiving",
      "zh-Hans" : "开始接收"
    },
    "local.stop.receive" : {
      "en" : "Stop Receiving",
      "zh-Hans" : "停止接收"
    },
    "connections.title" : {
      "en" : "Saved Connections",
      "zh-Hans" : "已保存的连接"
    },
    "connections.empty" : {
      "en" : "No Saved Connections",
      "zh-Hans" : "暂无保存的连接"
    },
    "connections.add" : {
      "en" : "Add Connection",
      "zh-Hans" : "添加连接"
    },
    "connections.name.placeholder" : {
      "en" : "Name",
      "zh-Hans" : "名称"
    },
    "connections.ip.placeholder" : {
      "en" : "IP Address",
      "zh-Hans" : "IP地址"
    },
    "connections.port.placeholder" : {
      "en" : "Port",
      "zh-Hans" : "端口"
    },
    "connections.cancel" : {
      "en" : "Cancel",
      "zh-Hans" : "取消"
    },
    "connections.save" : {
      "en" : "Save",
      "zh-Hans" : "保存"
    },
    "p2p.title" : {
      "en" : "Online Devices in LAN",
      "zh-Hans" : "局域网内的在线设备"
    },
    "p2p.connected" : {
      "en" : "Connected",
      "zh-Hans" : "已连接"
    },
    "p2p.disconnected" : {
      "en" : "Disconnected",
      "zh-Hans" : "未连接"
    },
    "onboarding.welcome" : {
      "en" : "Welcome to %@",
      "zh-Hans" : "欢迎使用 %@"
    },
    "onboarding.step.1.title" : {
      "en" : "AirPlay Shout",
      "zh-Hans" : "AirPlay 设备喊话"
    },
    "onboarding.step.1.desc" : {
      "en" : "Select AirPlay or Bluetooth device to stream audio wirelessly to TV, speakers, etc.",
      "zh-Hans" : "选择 AirPlay 或蓝牙设备，将声音无线传输到电视、音响等设备"
    },
    "onboarding.step.2.title" : {
      "en" : "Discover Nearby",
      "zh-Hans" : "发现附近设备"
    },
    "onboarding.step.2.desc" : {
      "en" : "Automatically discover iOS devices running %@ and stream audio to them",
      "zh-Hans" : "自动搜索同样运行了 %@ 的 iOS 设备，将声音传输到对方设备"
    },
    "onboarding.step.3.title" : {
      "en" : "Manual IP Connection",
      "zh-Hans" : "手动 IP 连接"
    },
    "onboarding.step.3.desc" : {
      "en" : "Enter the IP address of another iOS device, tap 'Start Receiving' on that device, then stream audio to it",
      "zh-Hans" : "输入对方 iOS 设备的 IP 地址，在对方设备上点击「开始接收」后，将声音传输到对方设备"
    },
    "onboarding.step.4.title" : {
      "en" : "Press to Speak",
      "zh-Hans" : "按下说话"
    },
    "onboarding.step.4.desc" : {
      "en" : "Press button to start transmitting, press again to stop. Waveform shows real-time audio levels",
      "zh-Hans" : "按下按钮开始传输，再次按下停止，波形图实时反馈音量"
    },
    "onboarding.start" : {
      "en" : "Get Started",
      "zh-Hans" : "开始使用"
    }
  },
  "version" : "1.0"
}
```

---

## Task 2: 替换 ContentView.swift 中的硬编码字符串

**Files:**
- Modify: `AirShout/Views/ContentView.swift`

- [ ] **Step 1: 替换硬编码字符串**

```swift
// 第 21 行
Text("向 AirPlay 设备喊话")
// 替换为
Text("content.airplay.title")

// 第 56 行
Button("打开设置") {
// 替换为
Button("content.airplay.permission.settings") {

// 第 63 行
Text("请在设置中开启麦克风权限以使用隔空喊话功能")
// 替换为
Text("content.airplay.permission.message")
```

---

## Task 3: 替换 OnboardingView.swift 中的硬编码字符串

**Files:**
- Modify: `AirShout/Views/OnboardingView.swift`

- [ ] **Step 1: 替换硬编码字符串**

OnboardingView 中的字符串较复杂，包含动态参数，需要使用 `String(localized:)`:

```swift
// 第 23 行
Text("欢迎使用 \(appName)")
// 替换为
Text(String(localized: "onboarding.welcome", table: "Localizable", arguments: [appName]))

// 第 30-32 行
StepView(
    number: 1,
    title: "AirPlay 设备喊话",
    description: "选择 AirPlay 或蓝牙设备，将声音无线传输到电视、音响等设备"
)
// 替换为
StepView(
    number: 1,
    title: String(localized: "onboarding.step.1.title"),
    description: String(localized: "onboarding.step.1.desc")
)

// 第 34-37 行 类似替换
StepView(
    number: 2,
    title: "发现附近设备",
    description: "自动搜索同样运行了 \(appName) 的 iOS 设备，将声音传输到对方设备"
)
// 替换为
StepView(
    number: 2,
    title: String(localized: "onboarding.step.2.title"),
    description: String(localized: "onboarding.step.2.desc", arguments: [appName])
)

// 第 40-44 行 类似替换
StepView(
    number: 3,
    title: "手动 IP 连接",
    description: "输入对方 iOS 设备的 IP 地址，在对方设备上点击「开始接收」后，将声音传输到对方设备"
)
// 替换为
StepView(
    number: 3,
    title: String(localized: "onboarding.step.3.title"),
    description: String(localized: "onboarding.step.3.desc")
)

// 第 46-50 行 类似替换
StepView(
    number: 4,
    title: "按下说话",
    description: "按下按钮开始传输，再次按下停止，波形图实时反馈音量"
)
// 替换为
StepView(
    number: 4,
    title: String(localized: "onboarding.step.4.title"),
    description: String(localized: "onboarding.step.4.desc")
)

// 第 56 行
Button("开始使用") {
// 替换为
Button("onboarding.start") {
```

---

## Task 4: 替换 DeviceListView.swift 中的硬编码字符串

**Files:**
- Modify: `AirShout/Views/DeviceListView.swift`

- [ ] **Step 1: 替换硬编码字符串**

```swift
// 第 12 行
Text("选择设备")
// 替换为
Text("device.select")

// 第 52 行
currentRouteName = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? "未选择设备"
// 替换为
currentRouteName = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? String(localized: "device.none")
```

---

## Task 5: 替换 ConnectionStatusView.swift 中的硬编码字符串

**Files:**
- Modify: `AirShout/Views/ConnectionStatusView.swift`

- [ ] **Step 1: 替换 statusText 计算属性中的字符串**

```swift
// 第 44-51 行
case .disconnected:
    return "未连接"
case .connecting:
    return "连接中..."
case .connected:
    return "已连接"
case .transmitting:
    return "传输中"
case .error(let message):
    return message
// 替换为
case .disconnected:
    return String(localized: "status.disconnected")
case .connecting:
    return String(localized: "status.connecting")
case .connected:
    return String(localized: "status.connected")
case .transmitting:
    return String(localized: "status.transmitting")
case .error(let message):
    return message
```

---

## Task 6: 替换 NetworkView.swift 中的硬编码字符串

**Files:**
- Modify: `AirShout/Views/Network/NetworkView.swift`

- [ ] **Step 1: 替换硬编码字符串**

```swift
// 第 19 行
Text("手动输入 IP 地址连接")
// 替换为
Text("network.title")

// 第 21 行
Text("（专业版）")
// 替换为
Text("network.pro")

// 第 59 行
Text(viewModel.isTransmitting ? "停止发送" : "开始发送")
// 替换为
Text(viewModel.isTransmitting ? "network.stop.send" : "network.start.send")

// 第 82 行
.alert("错误", isPresented: .constant(viewModel.errorMessage != nil)) {
// 替换为
.alert("network.error", isPresented: .constant(viewModel.errorMessage != nil)) {
```

---

## Task 7: 替换 LocalInfoView.swift 中的硬编码字符串

**Files:**
- Modify: `AirShout/Views/Network/LocalInfoView.swift`

- [ ] **Step 1: 替换硬编码字符串**

```swift
// 第 15 行
Text("本机IP:")
// 替换为
Text("local.ip")

// 第 22 行
Text("接收端口:")
// 替换为
Text("local.port")

// 第 24 行
TextField("端口", text: $localPort)
// 替换为
TextField("local.port.placeholder", text: $localPort)

// 第 43 行
Text(isListening ? "停止接收" : "开始接收")
// 替换为
Text(isListening ? "local.stop.receive" : "local.start.receive")
```

---

## Task 8: 替换 ConnectionListView.swift 中的硬编码字符串

**Files:**
- Modify: `AirShout/Views/Network/ConnectionListView.swift`

- [ ] **Step 1: 替换 ConnectionListView 中的字符串**

```swift
// 第 14 行
Text("已保存的连接")
// 替换为
Text("connections.title")

// 第 28 行
Text("暂无保存的连接")
// 替换为
Text("connections.empty")
```

- [ ] **Step 2: 替换 AddConnectionSheet 中的字符串**

```swift
// 第 98 行
Section("连接信息") {
// 替换为
Section("connections.title") {

// 第 99-103 行
TextField("名称", text: $name)
TextField("IP地址", text: $ip)
TextField("端口", text: $port)
// 替换为
TextField("connections.name.placeholder", text: $name)
TextField("connections.ip.placeholder", text: $ip)
TextField("connections.port.placeholder", text: $port)

// 第 106 行
.navigationTitle("添加连接")
// 替换为
.navigationTitle("connections.add")

// 第 110 行
Button("取消") {
// 替换为
Button("connections.cancel") {

// 第 115 行
Button("保存") {
// 替换为
Button("connections.save") {
```

---

## Task 9: 替换 P2PView.swift 中的硬编码字符串

**Files:**
- Modify: `AirShout/Views/P2PView.swift`

- [ ] **Step 1: 替换硬编码字符串**

```swift
// 第 9 行
Text("局域网内的在线设备")
// 替换为
Text("p2p.title")

// 第 69 行
Text(device.isConnected ? "已连接" : "未连接")
// 替换为
Text(device.isConnected ? "p2p.connected" : "p2p.disconnected")
```

---

## Task 10: 替换 ShoutButton.swift 中的硬编码字符串

**Files:**
- Modify: `AirShout/Views/ShoutButton.swift`

- [ ] **Step 1: 替换硬编码字符串**

```swift
// 第 39 行
Text(isActive ? "停止" : "开始")
// 替换为
Text(isActive ? "shout.stop" : "shout.start")
```

---

## Task 11: 替换 MainTabView.swift 中的硬编码字符串

**Files:**
- Modify: `AirShout/Views/MainTabView.swift`

- [ ] **Step 1: 替换硬编码字符串**

```swift
// 第 8 行
Label("AirPlay 喊话", systemImage: "airplayaudio")
// 替换为
Label("tab.airplay", systemImage: "airplayaudio")

// 第 13 行
Label("附近设备", systemImage: "antenna.radiowaves.left.and.right")
// 替换为
Label("tab.nearby", systemImage: "antenna.radiowaves.left.and.right")

// 第 18 行
Label("手动连接", systemImage: "link")
// 替换为
Label("tab.manual", systemImage: "link")
```

---

## Task 12: 验证编译

- [ ] **Step 1: 运行编译验证**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: 提交代码**

```bash
git add AirShout/Resources/Localizable.xcstrings AirShout/Views/*.swift
git commit -m "feat: add Chinese and English localization"
```
