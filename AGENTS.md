# AirShout - 隔空喊话 iOS App

## 项目概述

AirShout 是一款 iOS 应用，实现实时隔空喊话功能：用户按住说话按钮时，麦克风音频实时传输到用户选择的 AirPlay 设备上播放。

## 功能特性

- **实时传输**：按住说话按钮期间，麦克风音频实时流式传输到 AirPlay 设备
- **设备选择**：通过 AVRoutePickerView 选择可用的 AirPlay 设备
- **音量反馈**：实时显示麦克风音量波形
- **权限管理**：麦克风权限请求
- **Haptic 反馈**：按住按钮时触发触觉反馈
- **设备记忆**：记住上次使用的 AirPlay 设备
- **后台音频**：App 进入后台时继续传输音频
- **错误提示**：麦克风权限被拒绝时显示友好的引导提示

## 技术架构

### 核心组件

| 文件 | 职责 |
|------|------|
| `AudioManager.swift` | 管理 AVAudioEngine，处理音频采集和播放 |
| `DevicePreferences.swift` | 设备记忆：存储和恢复上次使用的 AirPlay 设备 |
| `ShoutViewModel.swift` | 连接 UI 和音频管理层 |
| `ContentView.swift` | 主界面 |
| `AirPlayPicker.swift` | AVRoutePickerView 的 SwiftUI 包装 |
| `ShoutButton.swift` | 按住说话按钮（含 Haptic 反馈） |
| `WaveformView.swift` | 音量波形显示 |
| `DeviceListView.swift` | 设备选择列表 |
| `NetworkManager.swift` | TCP Server/Client，音频收发 |
| `PacketProcessor.swift` | TCP 粘包/拆包处理，协议解析 |
| `JitterBuffer.swift` | 音频包缓冲，抗抖动播放 |
| `SavedConnection.swift` | TCP 连接数据结构与持久化 |

### 音频流程

```
麦克风 → AVAudioEngine.inputNode → AVAudioPlayerNode → 扬声器/AirPlay
              ↓
         音量计算 → audioLevel → WaveformView
```

### 设计文档

- `docs/superpowers/specs/2026-04-12-airshout-design.md` - 设计规格
- `docs/superpowers/plans/2026-04-12-airshout-implementation.md` - 实现计划

## 开发规范

### 线程安全

- **禁止在主线程执行业务代码**：所有业务逻辑（音频处理、网络请求、数据存储等）必须在后台队列执行，只允许在主线程更新 UI
- **异步优先**：使用 `async/await`、`DispatchQueue.async` 或 `withCheckedContinuation` 避免阻塞主线程
- **高频更新需节流**：音频/传感器等高频数据更新主线程 UI 时，必须添加节流机制（建议 50-100ms 间隔）

### 常见错误

| 错误模式 | 正确做法 |
|---------|---------|
| `engineQueue.sync { ... }` 在主线程调用 | 使用 `engineQueue.async` + `withCheckedContinuation` |
| 每次 buffer 都更新 UI | 添加时间间隔节流 |
| 在 `receive(on:)` 回调中直接处理业务 | 业务在后台执行，只在 UI 更新时回到主线程 |

## 当前状态

### 已完成

- ✅ 核心音频架构（AVAudioEngine + AVAudioPlayerNode）
- ✅ 麦克风权限请求
- ✅ UI 组件实现
- ✅ AirPlay 设备选择器
- ✅ 音频引擎生命周期管理（每次启动重建引擎）
- ✅ 路由变化监听器（自动重连 AirPlay 设备）
- ✅ UI 冻结问题修复（engineQueue 异步调用 + 音频级别节流）
- ✅ Haptic 反馈（按下按钮时触发）
- ✅ 设备记忆（记住上次使用的 AirPlay 设备）
- ✅ 后台音频（App 在后台时继续传输）
- ✅ 麦克风权限错误提示 UI
- ✅ 单元测试（AudioManager + DevicePreferences）
- ✅ 编译通过
- ✅ Network Tab（TCP 直接连接功能）
  - TCP Server/Client 架构
  - 协议头设计（Magic + Version + Type + Timestamp + Length）
  - PacketProcessor 粘包/拆包处理
  - JitterBuffer 抗抖动播放
  - 线程安全（connectionsQueue + audioEngineQueue）
  - Retain cycle 防护（[weak self]）

### 待验证

- ⏳ 真机测试

## 常见问题

### Q: 为什么用模拟器测试不行？
A: 模拟器不支持 AirPlay 功能和麦克风输入，必须使用真机测试。

### Q: 为什么 AirPlay 设备找不到？
A: 确保 AirPlay 设备（Apple TV / HomePod）和 iPhone 在同一 WiFi 网络。

## 经验教训

### AVAudioEngine 格式问题

**问题**：当没有选择有效输出设备时，`AVAudioEngine` 的输入/输出格式采样率为 0 Hz，导致 `installTap` 和 `connect` 时断言失败。

**错误信息**：
```
required condition is false: IsFormatSampleRateAndChannelCountValid(format)
Failed to create tap due to format mismatch
Error: input hw format invalid
```

**原因**：当 AirPlay 作为输出设备时，如果 iOS 系统还没有准备好输入硬件，格式查询会返回 0 Hz。

**解决方案**：
1. 在 `configureAudioSession` 中使用 `setPreferredSampleRate()` 设置首选采样率
2. 在 `setupAndStartEngine` 中优先使用 `inputNode.outputFormat(forBus: 0).sampleRate`，而不是 `audioSession.sampleRate`
3. 如果采样率为 0，抛出 `noInputAvailable` 错误而不是尝试强制使用 44100 Hz

**正确顺序**：
```swift
// 1. 先配置 AudioSession
try configureAudioSession()  // 这会设置 setPreferredSampleRate 和 setActive

// 2. 然后再查询格式
let inputFormat = inputNode.outputFormat(forBus: 0)

// 3. 验证格式有效性
guard inputFormat.sampleRate > 0 else {
    throw AudioError.noInputAvailable
}
```

### AudioSession 配置顺序

1. `setCategory()` - 设置类别和选项
2. `setPreferredSampleRate()` - 设置首选采样率（可选）
3. `setActive(true)` - 激活会话

**注意**：必须在激活会话之前设置首选采样率，否则可能不生效。

### 状态管理

当发生错误时，必须同时重置所有相关状态：
- `isRunning` - 引擎运行状态
- `audioLevel` - 波形显示
- `connectionStatus` - 连接状态指示

推荐使用关联值枚举（如 `ConnectionStatus.error(String)`）来显示具体错误信息。

### 枚举比较

带有关联值的枚举不能直接使用 `!=` 比较，应该添加辅助属性：
```swift
enum ConnectionStatus {
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
```

### 并发重启导致 UI 卡住

**问题**：音频路由快速变化时，`handleRouteChange` 可能同时触发多个 `restartEngineInternal()` 调用，导致并发访问 `playerNode` 和 `audioEngine`，造成死锁或资源竞争，UI 线程被阻塞。

**症状**：说话过程中所有按钮都无法按下，UI 完全冻结。

**解决方案**：添加 `isRestarting` 标志防止并发重启。

```swift
private var isRestarting = false

private func handleRouteChange(_ notification: Notification) {
    // ...
    case .newDeviceAvailable, .oldDeviceUnavailable, .override, .routeConfigurationChange:
        let running = isRunning
        if running && !isRestarting {
            isRestarting = true
            engineQueue.async { [weak self] in
                self?.restartEngineInternal()
                self?.isRestarting = false
            }
        }
    // ...
}
```

### 音频线程与状态同步

**问题**：`processAudioBuffer` 回调在音频线程上运行，可能与 `stop()` 同时执行导致竞争。

**原则**：
- 音频回调（`installTap`）和状态操作必须在同一个串行队列中执行
- 使用 `DispatchQueue` 的串行队列保护共享状态
- UI 更新必须在主线程，使用 `DispatchQueue.main.async`

### scheduleBuffer 在已停止节点上被调用

**问题**：Tap 回调中的 `scheduleBuffer` 可能在 `stopEngineOnly()` 执行期间被调用，此时 `playerNode` 可能处于停止状态，导致音频线程阻塞。

**症状**：点击"停止"按钮后 UI 冻结。

**解决方案**：在 tap 回调中添加 `isRunning` 检查，确保引擎还在运行时才 schedule buffer：

```swift
inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
    guard let self = self else { return }
    self.processAudioBuffer(buffer)
    guard self.isRunning else { return }
    self.playerNode?.scheduleBuffer(buffer, completionHandler: nil)
}
```

### 时间戳溢出问题

**问题**：`Date().timeIntervalSince1970 * 1000` 转换为 UInt32 时会溢出崩溃。

**崩溃信息**：
```
Fatal error: Double value cannot be converted to UInt32 because the result would be greater than UInt32.max
```

**原因**：
- `Date().timeIntervalSince1970` 返回从 1970 年到现在的秒数（2026 年约 1.7 × 10⁹）
- 乘以 1000 转换为毫秒后约 1.7 × 10¹²
- UInt32.max 约 4.3 × 10⁹
- Swift 的强制转换会对溢出进行 trap

**解决方案**：使用设备 uptime（相对时间）代替 wall-clock time：

```swift
// 错误 ❌
let timestamp = UInt32(Date().timeIntervalSince1970 * 1000)  // 会崩溃！

// 正确 ✅
let uptimeMs = UInt64(DispatchTime.now().uptimeNanoseconds / 1_000_000)
let timestamp = UInt32(truncatingIfNeeded: uptimeMs)
```

**注意**：设备 uptime 在约 49.7 天后溢出 UInt32，生产环境应考虑使用 UInt64 或添加 session ID 处理回绕。

### TCP/Network 线程安全要点

**问题**：TCP 连接和音频处理涉及多线程访问共享状态。

**关键原则**：
1. 所有对 `serverConnections` 和 `activeConnection` 的修改必须在同一个串行队列（`connectionsQueue`）中执行
2. 读取 `activeConnection` 时使用 `connectionsQueue.sync`
3. 写 `activeConnection` 时使用 `connectionsQueue.async`
4. NWConnection/NWListener 的 state handler 必须使用 `[weak self]` 避免 retain cycle
5. 音频 tap callback 必须调度到 `audioEngineQueue`，避免与 `stopSenderEngine()` 竞争

**正确模式**：
```swift
// 读取共享状态
var connectionToSend: NWConnection?
connectionsQueue.sync {
    connectionToSend = self.activeConnection
}

// 修改共享状态
connectionsQueue.async { [weak self] in
    guard let self = self else { return }
    self.serverConnections.append(conn)
    self.activeConnection = conn
}
```

### TCP 粘包/拆包处理

**问题**：TCP 是流式协议，不保留消息边界，需要自定义协议和状态机解析。

**协议设计**：使用固定长度 Header + 变长 Payload：
```
[Magic: 2 bytes][Version: 1 byte][Type: 1 byte][Timestamp: 4 bytes][Length: 2 bytes][Payload: n bytes]
```

**状态机解析**：
```swift
enum State {
    case waitingForHeader
    case waitingForPayload(length: UInt16)
}
```

**错误同步**：当 magic 校验失败时，逐字节查找下一个有效 magic 位置重新同步。

### Jitter Buffer 时间基一致性

**问题**：发送端和接收端必须使用相同的时间基计算 timestamp 和 playbackTime。

**关键点**：
- Sender 和 Receiver 都使用 `DispatchTime.now().uptimeNanoseconds` 作为时间源
- 发送时记录：packet.timestamp = 发送时刻 uptime
- 接收时判断：currentTimeMs >= packet.timestamp + targetDelayMs
- 绝对时间（如 Date）不适合跨设备同步，但适合单设备内相对排序

**错误示例**：
```swift
// Sender 使用 uptime，Receiver 使用 Date - 时间基不一致！
let timestamp = UInt32(DispatchTime.now().uptimeNanoseconds / 1_000_000)
let currentTimeMs = UInt64(Date().timeIntervalSince1970 * 1000)  // 错误！
```

### Retain Cycle 防护

**问题**：NWConnection/NWListener 的回调闭包可能捕获 `self`，导致循环引用。

**必须使用 `[weak self]` 的位置**：
- `listener?.stateUpdateHandler`
- `listener?.newConnectionHandler`
- `conn.stateUpdateHandler`
- `clientConnection?.stateUpdateHandler`
- `connection.receive(...)` 的 completion handler
- `connection.send(...)` 的 completion handler
- `inputNode.installTap(...)` 的 callback
- `Timer.scheduledTimer(...)` 的 callback

**模式**：
```swift
listener?.stateUpdateHandler = { [weak self] state in
    guard let self = self else { return }
    // 安全使用 self
}
```

## 开发命令

```bash
# 编译项目
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build

# 真机编译（需要 Xcode 连接真机设备）
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Device' build
```

## Git 提交历史

```
xxxxxxx feat: add Phase 1 enhancements - Haptic, permission alert, device memory, background audio, unit tests
144dd3e fix: use device uptime instead of Date for timestamps
873daa6 fix: critical retain cycles, race conditions, and memory safety
965de54 fix: critical thread safety and protocol parsing issues
ccebef0 fix: NetworkManager additional thread safety and logic issues
486b5c9 fix: NetworkManager thread safety and audio format issues
b68e144 engineQueue 非阻塞调用，修复UI冻结问题
41f73cd change mode to default
c8bc475 禁止 restartEngine 在主线程运行
0ef3e78 fix: simplify engine lifecycle - rebuild engine each time
0594e05 fix: change AudioSession mode from .voiceChat to .measurement
2a9bfc2 fix: remove .defaultToSpeaker from AudioSession options
f36c2a5 feat: implement Plan A+ - audio engine reuse
89bb3de feat: update DeviceListView to reflect system route changes
c3ec6c1 fix: skip AudioSession configuration on subsequent start() calls
216e98c feat: add route change listener to auto-reconnect to AirPlay devices
```
