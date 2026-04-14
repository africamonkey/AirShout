# P2P 对讲功能设计文档

## 概述

AirShout 新增局域网 P2P 对讲功能：用户在同一个局域网内，无需服务器即可实现实时语音对讲。设备自动发现，用户按住说话按钮即可向所有在线设备广播音频。

## 用户场景

- 用户打开 AirShout app，切换到 "AirShout" Tab
- 自动发现局域网内其他在线的 AirShout 用户
- 按住说话按钮，其他用户立即听到用户的声音
- 松开按钮，停止传输

## 技术架构

### 框架选择

使用 **Multipeer Connectivity** 框架实现 P2P 通信：
- 自动发现：设备上线后自动被其他节点发现
- 无需服务器：纯局域网 P2P 连接
- 内置加密：mcsession 默认加密

### 音频流程

```
麦克风 → AVAudioEngine.inputNode → 分 chunk (每 50ms) →
→ MCSession.send() unreliable → 其他设备接收 →
→ AVAudioPlayerNode → 扬声器
```

### 延迟目标

端到端延迟 < 100ms（可接受少量丢包）

## 文件结构

```
AirShout/
├── Managers/
│   ├── AudioManager.swift      # 现有，AirPlay 功能
│   └── P2PAudioManager.swift  # 新增，P2P 音频管理
├── ViewModels/
│   ├── ShoutViewModel.swift   # 现有，AirPlay ViewModel
│   └── P2PViewModel.swift     # 新增，P2P ViewModel
├── Views/
│   ├── ContentView.swift      # 现有，主界面（重命名为 MainTabView）
│   ├── P2PView.swift          # 新增，P2P 界面
│   └── ...
├── App/
│   └── AirShoutApp.swift      # 修改，添加 TabView
```

## 组件设计

### P2PAudioManager

**职责：**
- 管理 MCSession（发起会话、接受连接）
- 监听 `MCSessionDelegate` 事件（节点发现、连接状态变化）
- 音频采集（通过 `AVAudioEngine.inputNode.installTap`）
- 音频播放（通过 `AVAudioEngine` + `AVAudioPlayerNode`）
- 音频数据收发

**状态：**
- `isRunning`: 是否正在传输
- `peers`: 在线节点列表 `[MCPeerID]`
- `audioLevel`: 当前麦克风音量（用于波形显示）

**错误处理：**
- 麦克风权限拒绝：提示用户设置
- 连接断开：自动重连（暂不实现，待观察是否需要）
- 无可用输入设备：提示错误

### P2PViewModel

**职责：**
- 连接 P2PAudioManager 和 UI
- 管理 UI 状态（设备列表、连接状态、说话状态）
- 处理用户交互（按住说话按钮）

**状态：**
- `devices: [Device]`: 在线设备列表
- `isSpeaking`: 当前是否正在说话
- `connectionStatus`: 连接状态
- `audioLevel`: 音量级别

**Device 模型：**
```swift
struct Device: Identifiable {
    let id: MCPeerID
    var displayName: String  // 自定义昵称，优先于 peerID.displayName
    var isConnected: Bool
}
```

### P2PView

**UI 结构：**
```
VStack {
    // 设备列表
    ScrollView {
        LazyVStack {
            ForEach(viewModel.devices) { device in
                DeviceRow(device: device)
            }
        }
    }

    Spacer()

    // 说话按钮 + 波形
    HStack {
        WaveformView(level: viewModel.audioLevel)
        ShoutButton(
            isPressed: $viewModel.isSpeaking,
            onPress: { viewModel.startSpeaking() },
            onRelease: { viewModel.stopSpeaking() }
        )
    }
}
```

### MainTabView

**Tab 结构：**
```swift
TabView {
    AirPlayView()      // 现有 AirPlay 功能
        .tabItem {
            Label("AirPlay", systemImage: "airplayaudio")
        }

    P2PView()          // 新增 P2P 对讲功能
        .tabItem {
            Label("AirShout", systemImage: "wave.3.right")
        }
}
```

## 音频格式

| 参数 | 值 |
|------|-----|
| 采样率 | 44100 Hz |
| 声道 | 单声道 |
| 位深 | 16-bit |
| 分块大小 | 50ms (2205 samples) |
| 传输格式 | Raw PCM Data |

## 数据格式

音频数据直接以 `Data` 形式通过 `MCSession.send()` 发送，无需额外编码。

**分块逻辑：**
- `AVAudioPCMBuffer` 包含完整的音频帧
- 直接提取 `floatChannelData` 转为 `Data`
- 每次 `installTap` 回调发送一个 chunk

## 状态管理

### 枚举定义

```swift
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
```

### 状态转换

```
disconnected → connecting → connected
                          ↓
                      speaking (用户按住说话)
                          ↓
                       connected
```

## 用户设置

用户可在 P2P 设置中自定义昵称：
- 存储位置：`UserDefaults`
- Key：`"p2p_nickname"`
- 默认值：设备名称 `UIDevice.current.name`

## 测试场景

1. **单设备测试**：启动 app，验证自动开始广播（无需手动操作）
2. **双设备测试**：两台设备在同一局域网，验证互相发现和语音传输
3. **多设备测试**：3+ 设备，验证广播到所有设备
4. **延迟测试**：测量端到端延迟是否 < 100ms
5. **断开重连**：一台设备离线后重新上线，验证自动重连

## 风险与注意事项

1. **NAT 穿透**：Multipeer Connectivity 自动处理局域网内的设备发现，无需额外配置
2. **防火墙**：需要允许本地网络访问，iOS 默认允许
3. **音频冲突**：同时使用 AirPlay 和 P2P 时，音频输出可能冲突，需考虑是否同时支持
4. **后台运行**：P2P 功能是否支持后台运行？（建议暂不支持，简化实现）

## 后续扩展（暂不实现）

- 私聊功能：选择特定设备一对一通话
- 静音列表：屏蔽某些设备
- 设备分组：创建群组
