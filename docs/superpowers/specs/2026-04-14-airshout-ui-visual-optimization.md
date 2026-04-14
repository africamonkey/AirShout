# AirShout UI/UX 视觉优化设计方案

**日期：** 2026-04-14
**状态：** 待用户审批
**类型：** 视觉优化

---

## 概述

对 AirShout 进行视觉美化，采用现代渐变 + 玻璃拟态风格，在保持现有布局和功能不变的前提下，提升界面的现代感和精致度。

---

## 设计原则

1. **渐进式增强** — 不改变现有布局结构，只升级视觉表现
2. **保持可用性** — 视觉优化不影响用户操作直觉
3. **iOS 原生契合** — 使用 SwiftUI 原生修饰符，符合 Apple HIG

---

## 配色方案

### 渐变色系

| 用途 | 渐变 |
|------|------|
| 主按钮背景 | LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing) |
| 波形高亮 | 与主按钮一致 |
| 图标强调 | accentColor (保持系统自适应) |

### 背景色

| 模式 | 背景 |
|------|------|
| 浅色模式 | 渐变：Color(.systemBackground) → Color(.systemGray6).opacity(0.3) |
| 深色模式 | 渐变：Color(.systemBackground) → Color.black.opacity(0.5) |

---

## 组件优化

### 1. 主按钮 (ShoutButton)

**当前：** 纯色圆形按钮

**优化后：**
- 渐变填充背景
- 柔和投影：`shadow(color: .black.opacity(0.15), radius: 12, y: 6)`
- 按下状态：`scale(0.95)` + 亮度提升
- 文字保持白色或高对比色

```swift
// 渐变背景
.background(
    LinearGradient(
        colors: [.blue, .purple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
)

// 投影
.shadow(color: .black.opacity(0.15), radius: 12, y: 6)
```

### 2. 设备选择卡片 (DeviceListView)

**当前：** 灰色背景 + 文字

**优化后：**
- 毛玻璃效果：`.background(.ultraThinMaterial)`
- 圆角边框：`cornerRadius(16)`
- 轻微描边：`.overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1))`

### 3. 波形显示 (WaveformView)

**当前：** 30 个等宽条形，纯色填充

**优化后：**
- 高亮条形使用渐变色
- 发光效果：`.shadow(color: .accentColor.opacity(0.6), radius: 8)`
- 非激活条形保持灰阶但带透明度

```swift
// 条形渐变 + 发光
.fill(
    LinearGradient(
        colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
        startPoint: .bottom,
        endPoint: .top
    )
)
.shadow(color: .purple.opacity(0.5), radius: 6)
```

### 4. 连接状态指示器 (ConnectionStatusView)

**当前：** 灰色胶囊背景 + 圆点 + 文字

**优化后：**
- 毛玻璃背景保持一致
- 状态圆点增加脉冲动画（仅 transmitting 状态）

### 5. 页面背景

**当前：** 纯白/纯黑

**优化后：**
```swift
.background(
    LinearGradient(
        colors: [
            Color(.systemBackground),
            Color(.systemGray6).opacity(0.3)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
)
```

---

## 文件修改清单

| 文件 | 修改内容 |
|------|---------|
| `ContentView.swift` | 添加页面背景渐变 |
| `ShoutButton.swift` | 渐变背景 + 投影 + 按压缩放 |
| `WaveformView.swift` | 条形渐变色 + 发光效果 |
| `DeviceListView.swift` | 毛玻璃背景 + 圆角边框 |
| `ConnectionStatusView.swift` | 毛玻璃背景 + 脉冲动画（可选） |

---

## 预览效果

```
┌─────────────────────────────────┐
│ ▓▓▓▓▓▓ 渐变背景 ▓▓▓▓▓▓         │
│                                 │
│  AirShout           [● 已连接]  │  ← 毛玻璃状态徽章
│                                 │
│  ┌─────────────────────────┐  │  ← 毛玻璃卡片
│  │ 🔊 选择设备         [选择] │  │
│  │    Apple TV (Living)     │  │
│  └─────────────────────────┘  │
│                                 │
│  ┌─────────────────────────┐  │
│  │ ▁▂▄▆█▇▅▃▁▂▄▆█▇▅▃▁▂▄▆  │  │  ← 发光波形
│  └─────────────────────────┘  │
│                                 │
│       ┌───────────────┐        │
│       │   按住说话    │        │  ← 渐变按钮 + 投影
│       └───────────────┘        │
│                                 │
└─────────────────────────────────┘
```

---

## 兼容性

- 最低支持 iOS 15.0（`.ultraThinMaterial` 从 iOS 15 可用）
- 深色模式自动适配
- 动画使用 SwiftUI 原生修饰符，性能友好