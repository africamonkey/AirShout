# AirShout - 隔空喊话

实时将麦克风音频传输到 AirPlay 设备播放的 iOS 应用。

## 功能特性

- **实时传输** - 点击说话按钮，麦克风音频实时流式传输到 AirPlay 设备
- **设备选择** - 通过系统 AirPlay  picker 选择目标设备
- **音量反馈** - 实时显示麦克风音量波形
- **后台音频** - App 进入后台时继续传输
- **设备记忆** - 自动记住上次使用的 AirPlay 设备
- **Haptic 反馈** - 按下按钮时触发触觉反馈

## 系统要求

- iOS 16.0+
- 真机设备（模拟器不支持 AirPlay 和麦克风）
- AirPlay 设备（Apple TV / HomePod）与 iPhone 在同一 WiFi 网络

## 构建

```bash
# 克隆项目
git clone https://github.com/yourusername/AirShout.git
cd AirShout

# 使用 Xcode 打开
open AirShout.xcodeproj

# 或命令行编译
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Device' build
```

## 使用方法

1. 打开 App
2. 点击 AirPlay 图标选择目标设备
3. **点击**说话按钮开始传输
4. **再次点击**按钮停止传输

## 技术架构

| 组件 | 职责 |
|------|------|
| AudioManager | 管理 AVAudioEngine，处理音频采集和播放 |
| NetworkManager | TCP Server/Client，TCP 直接连接功能 |
| ShoutViewModel | 连接 UI 和音频管理层 |
| JitterBuffer | 音频包缓冲，抗抖动播放 |

## 项目结构

```
AirShout/
├── AirShout/
│   ├── App/
│   │   └── AirShoutApp.swift
│   ├── Models/
│   │   ├── Device.swift
│   │   └── SavedConnection.swift
│   ├── Managers/
│   │   ├── AudioManager.swift
│   │   ├── DevicePreferences.swift
│   │   └── NetworkManager.swift
│   ├── ViewModels/
│   │   └── ShoutViewModel.swift
│   ├── Views/
│   │   ├── ContentView.swift
│   │   ├── AirPlayPicker.swift
│   │   ├── ShoutButton.swift
│   │   ├── WaveformView.swift
│   │   └── DeviceListView.swift
│   ├── Audio/
│   │   ├── PacketProcessor.swift
│   │   └── JitterBuffer.swift
│   └── Resources/
│       └── Info.plist
└── AirShoutTests/
    └── AudioManagerTests.swift
```

## License

MIT