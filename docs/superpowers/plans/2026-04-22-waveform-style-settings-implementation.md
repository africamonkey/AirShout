# Waveform Style Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Settings view with Appearance → Waveform Style option, allowing users to choose between Classic Bar, Circular Pulse, and Wave Line styles.

**Architecture:** Store waveform style preference in UserDefaults, pass style to WaveformView which renders differently based on style. Settings accessible via new tab in MainTabView.

**Tech Stack:** SwiftUI, UserDefaults

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `AirShout/Views/WaveformView.swift` | Modify | Add WaveformStyle enum, support 3 render styles |
| `AirShout/Shared/Preferences/UserPreferences.swift` | Modify | Add waveformStyle property with persistence |
| `AirShout/Views/Settings/SettingsView.swift` | Create | Settings hierarchy with Appearance section |
| `AirShout/Views/MainTabView.swift` | Modify | Add Settings tab |
| `AirShout/Views/ContentView.swift` | Modify | Pass style to WaveformView |

---

## Tasks

### Task 1: Add WaveformStyle Enum and Update WaveformView

**Files:**
- Modify: `AirShout/Views/WaveformView.swift`

- [ ] **Step 1: Add WaveformStyle enum at top of file**

Add after imports:
```swift
enum WaveformStyle: String, CaseIterable, Codable {
    case classic = "classic"
    case pulse = "pulse"
    case wave = "wave"

    var displayName: String {
        switch self {
        case .classic: return "经典条形"
        case .pulse: return "圆形脉冲"
        case .wave: return "波浪线"
        }
    }
}
```

- [ ] **Step 2: Add style property to WaveformView**

Replace `WaveformView` struct:
```swift
struct WaveformView: View {
    let audioLevel: Float
    var style: WaveformStyle = .classic
    let barCount: Int = 30

    var body: some View {
        switch style {
        case .classic:
            classicWaveform
        case .pulse:
            pulseWaveform
        case .wave:
            waveWaveform
        }
    }

    private var classicWaveform: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    level: levelForBar(at: index),
                    isHighlighted: isBarHighlighted(at: index)
                )
            }
        }
        .padding(.horizontal)
    }

    private var pulseWaveform: some View {
        ZStack {
            ForEach(0..<barCount, id: \.self) { index in
                PulseBar(
                    index: index,
                    total: barCount,
                    level: audioLevel,
                    maxRadius: 100
                )
            }
        }
    }

    private var waveWaveform: some View {
        WaveLineView(audioLevel: audioLevel, barCount: barCount)
    }

    private func levelForBar(at index: Int) -> Float {
        let centerIndex = barCount / 2
        let distanceFromCenter = abs(index - centerIndex)
        let falloff = 1.0 - (Float(distanceFromCenter) / Float(centerIndex))
        return audioLevel * falloff
    }

    private func isBarHighlighted(at index: Int) -> Bool {
        let centerIndex = barCount / 2
        let distanceFromCenter = abs(index - centerIndex)
        return Float(distanceFromCenter) / Float(centerIndex) < 0.5
    }
}
```

- [ ] **Step 3: Add PulseBar view (for .pulse style)**

Add after `WaveformBar` struct:
```swift
struct PulseBar: View {
    let index: Int
    let total: Int
    let level: Float
    let maxRadius: CGFloat

    private var angle: Double {
        Double(index) / Double(total) * 2 * .pi - .pi / 2
    }

    private var barLength: CGFloat {
        CGFloat(max(0.1, level)) * maxRadius * 0.4
    }

    var body: some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    colors: [.blue.opacity(0.8), .purple.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                ))
                .frame(width: 4, height: barLength)
                .offset(y: -maxRadius / 2 + barLength / 2)
                .rotationEffect(.radians(angle))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 4: Add WaveLineView (for .wave style)**

Add after `PulseBar`:
```swift
struct WaveLineView: View {
    let audioLevel: Float
    let barCount: Int

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2
                let stepX = width / CGFloat(barCount - 1)

                path.move(to: CGPoint(x: 0, y: midY))

                for i in 0..<barCount {
                    let x = CGFloat(i) * stepX
                    let amplitude = CGFloat(audioLevel) * midY * 0.8
                    let frequency = sin(Double(i) / Double(barCount) * .pi * 2)
                    let y = midY - amplitude * CGFloat(frequency)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [.blue.opacity(0.9), .purple.opacity(0.9)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
            )
        }
    }
}
```

- [ ] **Step 5: Run build to verify**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add AirShout/Views/WaveformView.swift && git commit -m "feat: add WaveformStyle enum and three waveform render styles"
```

---

### Task 2: Add waveformStyle to UserPreferences

**Files:**
- Modify: `AirShout/Shared/Preferences/UserPreferences.swift`

- [ ] **Step 1: Add waveformStyle property**

Add to `Keys` enum:
```swift
static let waveformStyle = "com.airshout.waveformStyle"
```

Add new property after `p2pNickname`:
```swift
var waveformStyle: WaveformStyle {
    get {
        guard let rawValue = UserDefaults.standard.string(forKey: Keys.waveformStyle),
              let style = WaveformStyle(rawValue: rawValue) else {
            return .classic
        }
        return style
    }
    set { UserDefaults.standard.set(newValue.rawValue, forKey: Keys.waveformStyle) }
}
```

- [ ] **Step 2: Run build to verify**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add AirShout/Shared/Preferences/UserPreferences.swift && git commit -m "feat: add waveformStyle to UserPreferences"
```

---

### Task 3: Create SettingsView

**Files:**
- Create: `AirShout/Views/Settings/SettingsView.swift`

- [ ] **Step 1: Create Settings directory and file**

```bash
mkdir -p AirShout/Views/Settings
```

- [ ] **Step 2: Write SettingsView.swift**

```swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("com.airshout.waveformStyle", store: UserDefaults(suiteName: "com.airshout"))
    private var waveformStyleRaw: String = WaveformStyle.classic.rawValue

    private var waveformStyle: WaveformStyle {
        get { WaveformStyle(rawValue: waveformStyleRaw) ?? .classic }
        set { waveformStyleRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("外观") {
                    NavigationLink {
                        WaveformStylePickerView(style: $waveformStyle)
                    } label: {
                        HStack {
                            Text("波形样式")
                            Spacer()
                            Text(waveformStyle.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

struct WaveformStylePickerView: View {
    @Binding var style: WaveformStyle

    var body: some View {
        List {
            ForEach(WaveformStyle.allCases, id: \.self) { option in
                Button {
                    style = option
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.displayName)
                                .foregroundColor(.primary)
                            Text(descriptionFor(option))
                                . .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if style == option {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("波形样式")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func descriptionFor(_ style: WaveformStyle) -> String {
        switch style {
        case .classic: return "中央发光，渐变紫色条形柱"
        case .pulse: return "环形雷达式波形"
        case .wave: return "平滑曲线连接，现代流线风格"
        }
    }
}

#Preview {
    SettingsView()
}
```

- [ ] **Step 3: Run build to verify**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -30
```
Expected: BUILD SUCCEEDED (errors about WaveformStyle in WaveformView.swift are normal if Task 1 not completed)

- [ ] **Step 4: Commit**

```bash
git add AirShout/Views/Settings/SettingsView.swift && git commit -m "feat: add SettingsView with Appearance section"
```

---

### Task 4: Add Settings tab to MainTabView

**Files:**
- Modify: `AirShout/Views/MainTabView.swift`

- [ ] **Step 1: Add Settings tab**

Replace `MainTabView` body:
```swift
struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("tab.airplay", systemImage: "airplayaudio")
                }

            P2PView()
                .tabItem {
                    Label("tab.nearby", systemImage: "antenna.radiowaves.left.and.right")
                }

            NetworkView()
                .tabItem {
                    Label("tab.manual", systemImage: "link")
                }

            SettingsView()
                .tabItem {
                    Label("tab.settings", systemImage: "gear")
                }
        }
    }
}
```

- [ ] **Step 2: Run build to verify**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add AirShout/Views/MainTabView.swift && git commit -m "feat: add Settings tab to MainTabView"
```

---

### Task 5: Connect WaveformView to UserPreferences in ContentView

**Files:**
- Modify: `AirShout/Views/ContentView.swift`

- [ ] **Step 1: Pass waveformStyle to WaveformView**

Replace WaveformView usage in ContentView:
```swift
WaveformView(
    audioLevel: viewModel.audioLevel,
    style: UserPreferences.shared.waveformStyle
)
    .frame(height: 60)
```

- [ ] **Step 2: Run build to verify**

```bash
xcodebuild -scheme AirShout -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16e' build 2>&1 | tail -20
```
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add AirShout/Views/ContentView.swift && git commit -m "feat: connect WaveformView to UserPreferences waveformStyle"
```

---

## Verification

After all tasks:
1. Open Simulator and navigate to Settings tab
2. Tap "外观" → "波形样式"
3. Select each style and verify preview updates
4. Return to AirPlay tab and verify waveform changes when speaking