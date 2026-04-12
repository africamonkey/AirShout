import SwiftUI
import AVFAudio

struct DeviceListView: View {
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

            Text(currentRouteName)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
        }
    }

    private var currentRouteName: String {
        let session = AVAudioSession.sharedInstance()
        return session.currentRoute.outputs.first?.portName ?? "未选择设备"
    }
}

#Preview {
    DeviceListView {
        print("Select tapped")
    }
}
