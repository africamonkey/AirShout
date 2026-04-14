import SwiftUI

struct P2PView: View {
    @StateObject private var viewModel = P2PViewModel()

    var body: some View {
        VStack(spacing: 0) {
            deviceListSection

            Spacer()

            if let error = viewModel.errorMessage {
                errorBanner(message: error)
            }

            speakingSection
        }
        .background(Color(.systemBackground))
    }

    private var deviceListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("在线设备")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)

            if viewModel.devices.isEmpty {
                emptyStateView
            } else {
                deviceList
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("等待发现其他设备...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("确保其他设备也打开了 AirShout")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var deviceList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(viewModel.devices) { device in
                    DeviceRow(device: device)
                }
            }
            .padding(.horizontal)
        }
    }

    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
            Spacer()
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    }

    private var speakingSection: some View {
        HStack(spacing: 20) {
            WaveformView(audioLevel: viewModel.audioLevel)
                .frame(width: 60, height: 60)

            ShoutButton(
                isPressed: $viewModel.isSpeaking,
                onPress: { viewModel.startSpeaking() },
                onRelease: { viewModel.stopSpeaking() }
            )

            WaveformView(audioLevel: viewModel.audioLevel)
                .frame(width: 60, height: 60)
        }
        .padding(.vertical, 30)
        .padding(.horizontal)
        .background(Color(.systemGray6))
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
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
