import SwiftUI

struct P2PView: View {
    @StateObject private var viewModel = P2PViewModel()

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("在线设备")
                    .font(.headline)
                Spacer()
            }

            deviceList

            Spacer()

            WaveformView(audioLevel: viewModel.audioLevel)
                .frame(height: 60)

            Spacer()

            ShoutButton(
                isActive: viewModel.isSpeaking,
                onTap: {
                    if viewModel.isSpeaking {
                        viewModel.stopSpeaking()
                    } else {
                        viewModel.startSpeaking()
                    }
                }
            )

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.devices) { device in
                    DeviceRow(device: device)
                }
            }
        }
    }
}

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack {
            Image(systemName: "iphone")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.body)
                Text(device.isConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(device.isConnected ? .green : .secondary)
            }

            Spacer()

            if device.isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
