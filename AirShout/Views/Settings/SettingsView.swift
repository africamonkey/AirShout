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
                        WaveformStylePickerView(style: $waveformStyleRaw)
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
    @Binding var style: String

    private func selectedStyle() -> WaveformStyle {
        WaveformStyle(rawValue: style) ?? .classic
    }

    var body: some View {
        List {
            ForEach(WaveformStyle.allCases, id: \.self) { option in
                Button {
                    style = option.rawValue
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(option.displayName)
                                .foregroundColor(.primary)
                            Text(descriptionFor(option))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if selectedStyle() == option {
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