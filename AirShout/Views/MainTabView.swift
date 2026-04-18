import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("AirPlay", systemImage: "airplayaudio")
                }

            P2PView()
                .tabItem {
                    Label("AirShout", systemImage: "wave.3.right")
                }

            NetworkView()
                .tabItem {
                    Label("网络", systemImage: "network")
                }
        }
    }
}
