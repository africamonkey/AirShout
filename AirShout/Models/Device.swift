import Foundation
import AVFAudio

struct Device: Identifiable, Hashable {
    let id: String
    let name: String
    let portType: AVAudioSession.Port
    let portDescription: AVAudioSessionPortDescription?

    init(description: AVAudioSessionPortDescription) {
        self.id = description.uid
        self.name = description.portName
        self.portType = description.portType
        self.portDescription = description
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id
    }
}
