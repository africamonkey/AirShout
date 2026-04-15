import Foundation
import AVFAudio

struct AudioSessionConfig {
    static func configure(_ session: AVAudioSession) throws {
        try session.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetoothA2DP, .allowBluetoothHFP, .allowAirPlay]
        )
        
        let preferredSampleRate: Double = 44100
        try session.setPreferredSampleRate(preferredSampleRate)
        
        try session.setActive(true)
    }
    
    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}