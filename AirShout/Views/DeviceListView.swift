import SwiftUI

struct DeviceListView: View {
    @ObservedObject var deviceManager = DeviceDiscoveryManager.shared
    let onSelectTapped: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "airplayaudio")
                    .foregroundColor(.accentColor)
                Text("选择设备")
                    .font(.headline)
                Spacer()
                Button("选择") {
                    onSelectTapped()
                }
                .font(.subheadline)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(8)

            Text(deviceManager.selectedDevice?.name ?? "未选择设备")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }
}

#Preview {
    DeviceListView {
        print("Select tapped")
    }
}
