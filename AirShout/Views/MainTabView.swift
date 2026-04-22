import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("AirPlay 喊话", systemImage: "airplayaudio")
                }

            P2PView()
                .tabItem {
                    Label("附近设备", systemImage: "antenna.radiowaves.left.and.right")
                }

            NetworkView()
                .tabItem {
                    Label("手动连接", systemImage: "link")
                }
        }
    }
}
