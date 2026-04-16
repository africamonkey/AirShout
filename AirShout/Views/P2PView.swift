import SwiftUI

struct P2PView: View {
    @StateObject private var viewModel = P2PViewModel()

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("设备列表")
                    .font(.headline)
                Spacer()
                connectionStatusBadge
            }

            deviceList

            Spacer()

            WaveformView(audioLevel: viewModel.audioLevel)
                .frame(height: 60)

            Spacer()

            statusText

            ShoutButton(
                isActive: viewModel.isShouting,
                onTap: {
                    if viewModel.isShouting {
                        viewModel.stopShout()
                    } else {
                        viewModel.startShout()
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
    
    @ViewBuilder
    private var connectionStatusBadge: some View {
        switch viewModel.connectionState {
        case .disconnected:
            Label("未连接", systemImage: "circle.fill")
                .foregroundColor(.gray)
                .font(.caption)
        case .discovering:
            Label("发现中", systemImage: "magnifyingglass")
                .foregroundColor(.orange)
                .font(.caption)
        case .connected:
            Label("已连接", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .speaking:
            Label("说话中", systemImage: "mic.fill")
                .foregroundColor(.blue)
                .font(.caption)
        case .receiving:
            Label("接收中", systemImage: "speaker.wave.2.fill")
                .foregroundColor(.green)
                .font(.caption)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.caption)
                .lineLimit(1)
        }
    }

    private var statusText: some View {
        Group {
            switch viewModel.connectionState {
            case .disconnected:
                Text("等待发现设备...")
                    .foregroundColor(.secondary)
            case .discovering:
                Text("正在搜索附近设备...")
                    .foregroundColor(.orange)
            case .connected:
                Text("准备就绪，点击开始说话")
                    .foregroundColor(.green)
            case .speaking:
                Text("正在传输音频...")
                    .foregroundColor(.blue)
            case .receiving:
                Text("正在接收音频...")
                    .foregroundColor(.green)
            case .error(let message):
                Text("错误: \(message)")
                    .foregroundColor(.red)
            }
        }
        .font(.body)
    }
}

struct DeviceRow: View {
    let device: PeerInfo

    var body: some View {
        HStack {
            Image(systemName: "iphone")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(device.displayName)
                    .font(.body)
                if let ip = device.ip, let port = device.port {
                    Text("\(ip):\(port)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("等待连接...")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if device.isComplete {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
