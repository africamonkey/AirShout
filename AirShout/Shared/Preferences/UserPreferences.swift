import Foundation
import AVFAudio
import UIKit

final class UserPreferences {
    static let shared = UserPreferences()
    
    private enum Keys {
        static let lastDeviceUID = "com.airshout.lastDeviceUID"
        static let hasCompletedOnboarding = "com.airshout.hasCompletedOnboarding"
        static let p2pNickname = "com.airshout.p2pNickname"
    }
    
    private init() {}
    
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.hasCompletedOnboarding) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
    
    var p2pNickname: String {
        get { UserDefaults.standard.string(forKey: Keys.p2pNickname) ?? UIDevice.current.name }
        set { UserDefaults.standard.set(newValue, forKey: Keys.p2pNickname) }
    }
    
    func save(deviceUID: String) {
        UserDefaults.standard.set(deviceUID, forKey: Keys.lastDeviceUID)
    }
    
    func loadDeviceUID() -> String? {
        UserDefaults.standard.string(forKey: Keys.lastDeviceUID)
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: Keys.lastDeviceUID)
    }
    
    func saveCurrentDeviceUID() {
        guard let deviceUID = AVAudioSession.sharedInstance().currentRoute.outputs.first?.uid else { return }
        save(deviceUID: deviceUID)
    }
    
    func restoreDeviceIfNeeded() async -> Bool {
        guard let savedUID = loadDeviceUID() else { return false }
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        
        return currentRoute.outputs.contains { $0.uid == savedUID }
    }
}
