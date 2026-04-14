import SwiftUI

@main
struct AirShoutApp: App {
    init() {
        _ = P2PAudioManager.shared
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
    }
}
