# Waveform Style Settings - Design

## Overview

Add a Settings view with Appearance options allowing users to choose a waveform style for the audio visualizer.

## Waveform Styles

| Style | Name | Description |
|-------|------|-------------|
| `classic` | 经典条形 | Central glow, gradient purple bars, fade on sides |
| `pulse` | 圆形脉冲 | Circular radar-style waveform, distributed around center |
| `wave` | 波浪线 | Connected points forming smooth curve, modern flowing style |

## Implementation Plan

### 1. WaveformStyle Enum
Add `WaveformStyle` enum in `WaveformView.swift`:
```swift
enum WaveformStyle: String, CaseIterable {
    case classic = "classic"
    case pulse = "pulse"
    case wave = "wave"
}
```

### 2. UserPreferences Extension
Add `waveformStyle` property to `UserPreferences.swift`:
- Key: `com.airshout.waveformStyle`
- Default: `.classic`
- Persisted via UserDefaults

### 3. WaveformView Enhancement
- Accept `style: WaveformStyle` parameter
- Render differently based on style:
  - **Classic**: Current implementation (gradient bars)
  - **Pulse**: Circular/ring layout with audio-reactive segments
  - **Wave**: Smooth bezier curve connecting amplitude points

### 4. SettingsView
New view at `Views/Settings/SettingsView.swift`:
- NavigationStack with sections:
  - **外观 (Appearance)**
    - 波形样式 (Waveform Style): Picker with visual previews
- Linked from MainTabView tab item

### 5. MainTabView Update
Add Settings tab:
```swift
SettingsView()
    .tabItem {
        Label("tab.settings", systemImage: "gear")
    }
```

### 6. ContentView Integration
- Read `UserPreferences.shared.waveformStyle`
- Pass to `WaveformView(audioLevel:style:)`