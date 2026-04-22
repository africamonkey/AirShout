# AirShout 本地化设计规格

## 概述

为 AirShout iOS App 添加中英文本地化支持，使用 App 跟随 iOS 系统语言设置，无需手动切换。

## 技术方案

- **格式**: `.xcstrings`（Xcode 现代本地化格式）
- **语言**: 中文（zh-Hans）、英文（en）
- **机制**: SwiftUI 内置本地化，`Text("key")` 和 `String(localized:)` 宏

## 需要本地化的文件

| 文件 | 翻译键数量 |
|------|-----------|
| ContentView.swift | 4 |
| OnboardingView.swift | 9 |
| DeviceListView.swift | 2 |
| ConnectionStatusView.swift | 5 |
| NetworkView.swift | 3 |
| LocalInfoView.swift | 5 |
| ConnectionListView.swift | 5 |
| P2PView.swift | 3 |
| ShoutButton.swift | 2 |
| MainTabView.swift | 3 |
| **总计** | **~41** |

## 翻译键规范

### 标签页
- `tab.airplay` → 中文: "AirPlay 喊话", 英文: "AirPlay Shout"
- `tab.nearby` → 中文: "附近设备", 英文: "Nearby"
- `tab.manual` → 中文: "手动连接", 英文: "Manual Connect"

### 主界面 (ContentView)
- `content.airplay.title` → 中文: "向 AirPlay 设备喊话", 英文: "Shout to AirPlay"
- `content.airplay.permission.title` → 中文: "麦克风权限被拒绝", 英文: "Microphone Access Denied"
- `content.airplay.permission.message` → 中文: "请在设置中开启麦克风权限以使用隔空喊话功能", 英文: "Please enable microphone access in Settings to use AirShout"
- `content.airplay.permission.settings` → 中文: "打开设置", 英文: "Open Settings"

### 引导页 (OnboardingView)
- `onboarding.welcome` → 中文: "欢迎使用 %@", 英文: "Welcome to %@"
- `onboarding.step.1.title` → 中文: "AirPlay 设备喊话", 英文: "AirPlay Shout"
- `onboarding.step.1.desc` → 中文: "选择 AirPlay 或蓝牙设备，将声音无线传输到电视、音响等设备", 英文: "Select AirPlay or Bluetooth device to stream audio wirelessly to TV, speakers, etc."
- `onboarding.step.2.title` → 中文: "发现附近设备", 英文: "Discover Nearby"
- `onboarding.step.2.desc` → 中文: "自动搜索同样运行了 %@ 的 iOS 设备，将声音传输到对方设备", 英文: "Automatically discover iOS devices running %@ and stream audio to them"
- `onboarding.step.3.title` → 中文: "手动 IP 连接", 英文: "Manual IP Connection"
- `onboarding.step.3.desc` → 中文: "输入对方 iOS 设备的 IP 地址，在对方设备上点击「开始接收」后，将声音传输到对方设备", 英文: "Enter the IP address of another iOS device, tap 'Start Receiving' on that device, then stream audio to it"
- `onboarding.step.4.title` → 中文: "按下说话", 英文: "Press to Speak"
- `onboarding.step.4.desc` → 中文: "按下按钮开始传输，再次按下停止，波形图实时反馈音量", 英文: "Press button to start transmitting, press again to stop. Waveform shows real-time audio levels"
- `onboarding.start` → 中文: "开始使用", 英文: "Get Started"

### 设备列表 (DeviceListView)
- `device.select` → 中文: "选择设备", 英文: "Select Device"
- `device.none` → 中文: "未选择设备", 英文: "No Device Selected"

### 连接状态 (ConnectionStatusView)
- `status.disconnected` → 中文: "未连接", 英文: "Disconnected"
- `status.connecting` → 中文: "连接中...", 英文: "Connecting..."
- `status.connected` → 中文: "已连接", 英文: "Connected"
- `status.transmitting` → 中文: "传输中", 英文: "Transmitting"
- `status.error` → 中文: "错误", 英文: "Error"

### 网络视图 (NetworkView)
- `network.title` → 中文: "手动输入 IP 地址连接", 英文: "Enter IP Address to Connect"
- `network.pro` → 中文: "（专业版）", 英文: "(Pro)"
- `network.start.send` → 中文: "开始发送", 英文: "Start Sending"
- `network.stop.send` → 中文: "停止发送", 英文: "Stop Sending"
- `network.error` → 中文: "错误", 英文: "Error"

### 本机信息 (LocalInfoView)
- `local.ip` → 中文: "本机IP:", 英文: "Local IP:"
- `local.port` → 中文: "接收端口:", 英文: "Receive Port:"
- `local.port.placeholder` → 中文: "端口", 英文: "Port"
- `local.start.receive` → 中文: "开始接收", 英文: "Start Receiving"
- `local.stop.receive` → 中文: "停止接收", 英文: "Stop Receiving"

### 连接列表 (ConnectionListView)
- `connections.title` → 中文: "已保存的连接", 英文: "Saved Connections"
- `connections.empty` → 中文: "暂无保存的连接", 英文: "No Saved Connections"
- `connections.add` → 中文: "添加连接", 英文: "Add Connection"
- `connections.name.placeholder` → 中文: "名称", 英文: "Name"
- `connections.ip.placeholder` → 中文: "IP地址", 英文: "IP Address"
- `connections.port.placeholder` → 中文: "端口", 英文: "Port"
- `connections.cancel` → 中文: "取消", 英文: "Cancel"
- `connections.save` → 中文: "保存", 英文: "Save"

### P2P 视图 (P2PView)
- `p2p.title` → 中文: "局域网内的在线设备", 英文: "Online Devices in LAN"
- `p2p.connected` → 中文: "已连接", 英文: "Connected"
- `p2p.disconnected` → 中文: "未连接", 英文: "Disconnected"

### 喊话按钮 (ShoutButton)
- `shout.start` → 中文: "开始", 英文: "Start"
- `shout.stop` → 中文: "停止", 英文: "Stop"

## 实现步骤

1. 创建 `AirShout/Resources/Localizable.xcstrings`
2. 替换所有硬编码字符串为 `Text("key")` 格式
3. 验证编译通过
4. 测试中英文切换

## 注意事项

- 引导页中的 `%@` 是动态参数（App 名称），需使用 `String(localized:key:table:)` 并传参
- `onDisappear` 回调中的 `Button("取消", role: .cancel)` 使用系统标准按钮，自动本地化，无需修改
