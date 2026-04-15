import SwiftUI
import AVKit
import AVFAudio

struct DeviceListView: View {
    @State private var currentRouteName: String = "未选择设备"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("选择设备")
                    .font(.headline)
                Spacer()
                AirPlayPicker()
                    .frame(width: 44, height: 32)
            }
            .padding(.horizontal)
            .padding(.top, 4)

            Text(currentRouteName)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 4)
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
        )
        .onAppear {
            updateRouteName()
        }
    }

    private func updateRouteName() {
        currentRouteName = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? "未选择设备"
    }
}

#Preview {
    DeviceListView()
        .padding()
}
