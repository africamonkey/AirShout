import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("tab.airplay", systemImage: "airplayaudio")
                }

            P2PView()
                .tabItem {
                    Label("tab.nearby", systemImage: "antenna.radiowaves.left.and.right")
                }

            NetworkView()
                .tabItem {
                    Label("tab.manual", systemImage: "link")
                }
        }
    }
}
