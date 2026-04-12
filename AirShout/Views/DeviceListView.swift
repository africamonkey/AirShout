import SwiftUI

struct DeviceListView: View {
    @ObservedObject var audioRouter = AudioRouter.shared
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

            Text(audioRouter.currentRoute)
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
