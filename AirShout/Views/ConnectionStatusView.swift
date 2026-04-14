import SwiftUI

struct ConnectionStatusView: View {
    let status: AudioManager.ConnectionStatus
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color(.systemGray6))
        .cornerRadius(16)
    }

    private var statusColor: Color {
        switch status {
        case .disconnected:
            return .gray
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .transmitting:
            return .blue
        case .error:
            return .red
        }
    }

    private var statusText: String {
        switch status {
        case .disconnected:
            return "未连接"
        case .connecting:
            return "连接中..."
        case .connected:
            return "已连接"
        case .transmitting:
            return "传输中"
        case .error(let message):
            return message
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ConnectionStatusView(status: .disconnected)
        ConnectionStatusView(status: .connecting)
        ConnectionStatusView(status: .connected)
        ConnectionStatusView(status: .transmitting)
    }
}
