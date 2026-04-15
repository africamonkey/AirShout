import Foundation
import AVFAudio

final class AudioLevelProcessor {
    private var lastUpdateTime: TimeInterval = 0
    private let updateInterval: TimeInterval = 0.05
    
    func calculateLevel(from buffer: AVAudioPCMBuffer) -> Float? {
        guard let channelData = buffer.floatChannelData else { return nil }
        let channelDataValue = channelData.pointee
        
        var sum: Float = 0
        for i in stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride) {
            let sample = channelDataValue[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        let avgPower = 20 * log10(max(rms, 0.000001))
        return max(0, min(1, (avgPower + 50) / 50))
    }
    
    func shouldUpdate(now: TimeInterval) -> Bool {
        guard now - lastUpdateTime >= updateInterval else { return false }
        lastUpdateTime = now
        return true
    }
}