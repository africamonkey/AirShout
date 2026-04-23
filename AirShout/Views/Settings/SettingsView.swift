import SwiftUI

struct SettingsView: View {
    @AppStorage("com.airshout.waveformStyle")
    private var waveformStyleRaw: String = WaveformStyle.classic.rawValue

    private var waveformStyle: WaveformStyle {
        get { WaveformStyle(rawValue: waveformStyleRaw) ?? .classic }
        set { waveformStyleRaw = newValue.rawValue }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("settings.appearance") {
                    NavigationLink {
                        WaveformStylePickerView(style: $waveformStyleRaw)
                    } label: {
                        HStack {
                            Text("settings.waveform.style")
                            Spacer()
                            Text(waveformStyle.displayName)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section("settings.about") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            Text("settings.about")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("settings.title")
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
        .navigationTitle("settings.waveform.style")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func descriptionFor(_ style: WaveformStyle) -> LocalizedStringKey {
        switch style {
        case .classic: return "waveform.style.classic"
        case .pulse: return "waveform.style.pulse"
        case .wave: return "waveform.style.wave"
        }
    }
}

#Preview {
    SettingsView()
}