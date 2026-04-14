# AirShout - 隔空喊话 iOS App

## 项目概述

AirShout 是一款 iOS 应用，实现实时隔空喊话功能：用户按住说话按钮时，麦克风音频实时传输到用户选择的 AirPlay 设备上播放。

## 功能特性

- **实时传输**：按住说话按钮期间，麦克风音频实时流式传输到 AirPlay 设备
- **设备选择**：通过 AVRoutePickerView 选择可用的 AirPlay 设备
- **音量反馈**：实时显示麦克风音量波形
- **权限管理**：麦克风权限请求

## 技术架构

### 核心组件

| 文件 | 职责 |
|------|------|
| `AudioManager.swift` | 管理 AVAudioEngine，处理音频采集和播放 |
| `DeviceDiscoveryManager.swift` | 发现和管理 AirPlay 设备 |
| `ShoutViewModel.swift` | 连接 UI 和音频管理层 |
| `ContentView.swift` | 主界面 |
| `AirPlayPicker.swift` | AVRoutePickerView 的 SwiftUI 包装 |
| `ShoutButton.swift` | 按住说话按钮 |
| `WaveformView.swift` | 音量波形显示 |
| `DeviceListView.swift` | 设备选择列表 |

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
- ✅ 编译通过

### 待验证

- ⏳ 真机测试

## 常见问题

### Q: 为什么用模拟器测试不行？
A: 模拟器不支持 AirPlay 功能和麦克风输入，必须使用真机测试。

### Q: 为什么 AirPlay 设备找不到？
A: 确保 AirPlay 设备（Apple TV / HomePod）和 iPhone 在同一 WiFi 网络。

## 开发命令

```bash
# 编译项目
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build

# 真机编译（需要 Xcode 连接真机设备）
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Device' build
```

## Git 提交历史

```
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
