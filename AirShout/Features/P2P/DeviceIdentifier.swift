import Foundation

final class DeviceIdentifier {
    static let shared = DeviceIdentifier()
    
    private enum Keys {
        static let deviceID = "com.airshout.p2p.deviceID"
    }
    
    private init() {}
    
    var currentDeviceID: String {
        if let existingID = UserDefaults.standard.string(forKey: Keys.deviceID) {
            return existingID
        }
        let newID = UUID().uuidString
        UserDefaults.standard.set(newID, forKey: Keys.deviceID)
        return newID
    }
}
