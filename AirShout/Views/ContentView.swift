import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AirPlayViewModel()
    @State private var showOnboarding = !UserPreferences.shared.hasCompletedOnboarding

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.3)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Text("向 AirPlay 设备喊话")
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()

                    ConnectionStatusView(status: viewModel.connectionStatus)
                }
                .padding(.top, 20)

                DeviceListView()

                Spacer()

                WaveformView(audioLevel: viewModel.audioLevel)
                    .frame(height: 60)

                Spacer()

                ShoutButton(
                    isActive: viewModel.isShouting,
                    onTap: {
                        if viewModel.isShouting {
                            viewModel.stopShout()
                        } else {
                            viewModel.startShout()
                        }
                    }
                )

                Spacer()
            }
            .padding()
        }
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
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .onDisappear {
                    UserPreferences.shared.hasCompletedOnboarding = true
                }
        }
    }
}
