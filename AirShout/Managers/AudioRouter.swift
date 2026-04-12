import SwiftUI
import Combine
import AVFAudio
import MediaPlayer
import UIKit

final class AudioRouter: ObservableObject {
    static let shared = AudioRouter()

    @Published var currentRoute: String = ""

    private init() {
        updateCurrentRoute()
        setupRouteChangeObserver()
    }

    private func setupRouteChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    @objc private func handleRouteChange() {
        updateCurrentRoute()
    }

    private func updateCurrentRoute() {
        let session = AVAudioSession.sharedInstance()
        currentRoute = session.currentRoute.outputs.first?.portName ?? "未选择设备"
    }

    func showAirPlayPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootVC = window.rootViewController else { return }

        let volumeView = MPVolumeView(frame: .zero)
        volumeView.showsVolumeSlider = false

        if let airPlayButton = volumeView.subviews.first(where: { $0 is UIButton }) as? UIButton {
            airPlayButton.sendActions(for: .touchUpInside)
        }

        rootVC.view.addSubview(volumeView)
        volumeView.alpha = 0.01

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            volumeView.removeFromSuperview()
        }
    }
}
