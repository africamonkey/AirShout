import SwiftUI
import AVKit
import AVFAudio

struct DeviceListView: View {
    @State private var currentRouteName: String = String(localized: "device.none")
    @State private var routeChangeObserver: NSObjectProtocol?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("device.select")
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
            routeChangeObserver = NotificationCenter.default.addObserver(
                forName: AVAudioSession.routeChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                updateRouteName()
            }
        }
        .onDisappear {
            if let observer = routeChangeObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }

    private func updateRouteName() {
        currentRouteName = AVAudioSession.sharedInstance().currentRoute.outputs.first?.portName ?? String(localized: "device.none")
    }
}

#Preview {
    DeviceListView()
        .padding()
}
