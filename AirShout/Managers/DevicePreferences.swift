import Foundation
import AVFAudio

final class DevicePreferences {
    private static let lastDeviceUIDKey = "com.airshout.lastDeviceUID"

    static func save(deviceUID: String) {
        UserDefaults.standard.set(deviceUID, forKey: lastDeviceUIDKey)
    }

    static func load() -> String? {
        UserDefaults.standard.string(forKey: lastDeviceUIDKey)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: lastDeviceUIDKey)
    }

    static func restoreIfNeeded() async -> Bool {
        guard let savedUID = load() else { return false }

        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute

        if let savedDevice = currentRoute.outputs.first(where: { $0.uid == savedUID }) {
            return true
        }

        for output in currentRoute.outputs {
            if output.uid == savedUID {
                return true
            }
        }

        return false
    }
}
