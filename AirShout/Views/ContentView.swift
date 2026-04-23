import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AirPlayViewModel()
    @State private var showOnboarding = !UserPreferences.shared.hasCompletedOnboarding
    @AppStorage("com.airshout.waveformStyle") private var waveformStyleRaw: String = WaveformStyle.classic.rawValue

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
                    Text("content.airplay.title")
                        .font(.headline)
                        .fontWeight(.bold)

                    Spacer()

                    ConnectionStatusView(status: viewModel.connectionStatus)
                }
                .padding(.top, 20)

                DeviceListView()

                Spacer()

                WaveformView(
                    audioLevel: viewModel.audioLevel,
                    style: WaveformStyle(rawValue: waveformStyleRaw) ?? .classic
                )
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
        .alert("content.airplay.permission.title", isPresented: $viewModel.showPermissionAlert) {
            Button("content.airplay.permission.settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("alert.cancel", role: .cancel) { }
        } message: {
            Text("content.airplay.permission.message")
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingView(isPresented: $showOnboarding)
                .onDisappear {
                    UserPreferences.shared.hasCompletedOnboarding = true
                }
        }
    }
}
