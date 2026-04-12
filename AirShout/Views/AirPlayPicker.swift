import SwiftUI
import MediaPlayer

struct AirPlayPicker: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView()
        volumeView.showsVolumeSlider = false
        return volumeView
    }

    func updateUIView(_ uiView: MPVolumeView, context: Context) {}
}
