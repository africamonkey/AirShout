import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ShoutViewModel()
    @StateObject private var audioRouter = AudioRouter.shared

    var body: some View {
        VStack(spacing: 24) {
            Text("AirShout")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 20)

            DeviceListView {
                audioRouter.showAirPlayPicker()
            }

            Spacer()

            WaveformView(audioLevel: viewModel.audioLevel)
                .frame(height: 60)

            Spacer()

            ShoutButton(isPressed: viewModel.isShouting) {
                viewModel.startShout()
            } onRelease: {
                viewModel.stopShout()
            }

            Spacer()
        }
        .padding()
        .onReceive(audioRouter.$currentRoute) { _ in
            viewModel.refreshDevices()
        }
    }
}
