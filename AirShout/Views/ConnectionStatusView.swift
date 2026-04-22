import SwiftUI

struct ConnectionStatusView: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
                .shadow(color: statusColor.opacity(0.6), radius: 4)

            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
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
            return String(localized: "status.disconnected")
        case .connecting:
            return String(localized: "status.connecting")
        case .connected:
            return String(localized: "status.connected")
        case .transmitting:
            return String(localized: "status.transmitting")
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