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

## 当前状态

### 已完成

- ✅ 核心音频架构（AVAudioEngine + AVAudioPlayerNode）
- ✅ 麦克风权限请求
- ✅ UI 组件实现
- ✅ AirPlay 设备选择器
- ✅ 编译通过

### 待验证

- ⏳ 真机测试（UI 冻结问题调查中）

## 常见问题

### Q: 为什么用模拟器测试不行？
A: 模拟器不支持 AirPlay 功能和麦克风输入，必须使用真机测试。

### Q: 为什么 AirPlay 设备找不到？
A: 确保 AirPlay 设备（Apple TV / HomePod）和 iPhone 在同一 WiFi 网络。

### Q: UI 冻结如何处理？
A: 目前正在调试中，已禁用路由变化监听器以隔离问题。

## 开发命令

```bash
# 编译项目
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build

# 真机编译（需要 Xcode 连接真机设备）
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Device' build
```

## Git 提交历史

```
2f747d4 debug: temporarily disable route change observer to isolate UI freeze
76a29ad fix: ensure route change notifications are processed on main thread
934c58d chore: update AirPlayPicker with AVRoutePickerView
e763274 fix: properly integrate MPVolumeView via UIViewRepresentable
f48d402 fix: resolve compilation errors
e9ecb42 feat: add microphone permission request
48b681e perf: optimize audio buffer processing
7002bab fix: rewrite AudioManager with correct AVAudioEngine
a7b17f5 refactor: replace template with AirShout implementation
fc48c86 docs: add AirShout design spec
```
