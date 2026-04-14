import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = ShoutViewModel()
    @State private var showingAirPlayPicker = false
    @State private var showOnboarding = !AppPreferences.hasCompletedOnboarding

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Text("AirShout")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                ConnectionStatusView(status: viewModel.connectionStatus)
            }
            .padding(.top, 20)

            DeviceListView {
                showingAirPlayPicker = true
            }

            Spacer()

            WaveformView(audioLevel: viewModel.audioLevel)
                .frame(height: 60)

            Spacer()

            ShoutButton(isActive: viewModel.isShouting) {
                if viewModel.isShouting {
                    viewModel.stopShout()
                } else {
                    viewModel.startShout()
                }
            }

            Spacer()
        }
        .padding()
        .alert("麦克风权限被拒绝", isPresented: $viewModel.showPermissionAlert) {
            Button("打开设置") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("取消", role: .cancel) { }
        } message: {
            Text("请在设置中开启麦克风权限以使用隔空喊话功能")
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
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .onDisappear {
                    AppPreferences.hasCompletedOnboarding = true
                }
        }
    }
}
