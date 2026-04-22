import Foundation
import AVFAudio
import UIKit

final class UserPreferences {
    static let shared = UserPreferences()
    
    private enum Keys {
        static let lastDeviceUID = "com.airshout.lastDeviceUID"
        static let hasCompletedOnboarding = "com.airshout.hasCompletedOnboarding"
        static let p2pNickname = "com.airshout.p2pNickname"
        static let waveformStyle = "com.airshout.waveformStyle"
    }
    
    private let deviceName: String
    
    private init() {
        deviceName = UIDevice.current.name
    }
    
    var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.object(forKey: Keys.hasCompletedOnboarding) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
    
    var p2pNickname: String {
        get { UserDefaults.standard.string(forKey: Keys.p2pNickname) ?? deviceName }
        set { UserDefaults.standard.set(newValue, forKey: Keys.p2pNickname) }
    }

    var waveformStyle: String {
        get { UserDefaults.standard.string(forKey: Keys.waveformStyle) ?? "classic" }
        set { UserDefaults.standard.set(newValue, forKey: Keys.waveformStyle) }
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
    
    func restoreDeviceIfNeeded() -> Bool {
        guard let savedUID = loadDeviceUID() else { return false }
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        
        return currentRoute.outputs.contains { $0.uid == savedUID }
    }
}
