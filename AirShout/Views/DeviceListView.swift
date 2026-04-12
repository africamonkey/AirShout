import SwiftUI
import AVFAudio

struct DeviceListView: View {
    let onSelectTapped: () -> Void
    @State private var currentRouteName: String = "未选择设备"
    
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
        .onAppear {
            updateRouteName()
            setupRouteObserver()
        }
    }
    
    private func updateRouteName() {
        let session = AVAudioSession.sharedInstance()
        currentRouteName = session.currentRoute.outputs.first?.portName ?? "未选择设备"
    }
    
    private func setupRouteObserver() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            updateRouteName()
        }
    }
}

#Preview {
    DeviceListView {
        print("Select tapped")
    }
}
