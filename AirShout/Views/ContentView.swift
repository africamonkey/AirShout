import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ShoutViewModel()
    @State private var showingAirPlayPicker = false

    var body: some View {
        VStack(spacing: 24) {
            Text("AirShout")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 20)

            DeviceListView {
                showingAirPlayPicker = true
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
        .onReceive(DeviceDiscoveryManager.shared.$selectedDevice) { _ in
            viewModel.refreshDevices()
        }
        .sheet(isPresented: $showingAirPlayPicker) {
            VStack {
                Text("选择 AirPlay 设备")
                    .font(.headline)
                    .padding()
                AirPlayPicker()
                    .frame(width: 300, height: 200)
                Button("关闭") {
                    showingAirPlayPicker = false
                }
                .padding()
            }
        }
    }
}
