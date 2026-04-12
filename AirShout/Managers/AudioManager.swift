import Foundation
import AVFAudio
import Combine

final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var audioLevel: Float = 0
    @Published var isRunning: Bool = false

    private var audioEngine: AVAudioEngine?
    private let audioSession = AVAudioSession.sharedInstance()
    private var levelTimer: Timer?

    var audioLevelPublisher: AnyPublisher<Float, Never> {
        $audioLevel.eraseToAnyPublisher()
    }

    private init() {}

    func start() throws {
        try configureAudioSession()

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let inputNode = audioEngine.inputNode
        let outputNode = audioEngine.outputNode
        let mainMixer = audioEngine.mainMixerNode

        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer)
        }

        let inputDevice = inputNode.device
        let outputDevice = outputNode.device

        audioEngine.connect(inputNode, to: mainMixer, format: format)

        if let inputDevice = inputDevice {
            audioEngine.enableManualRoutingMode = true
            let route = AVAudioRoutingRoute(input: inputDevice, output: outputDevice, inputFormat: format, outputFormat: format)
            do {
                try audioEngine.manualRoutingRoute = route
            } catch {
                print("Manual routing failed: \(error)")
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRunning = true
        startLevelTimer()
    }

    func stop() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRunning = false
        audioLevel = 0
        stopLevelTimer()
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try audioSession.setActive(true)
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride).map { channelDataValue[$0] }

        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = normalizedLevel
        }
    }

    private func startLevelTimer() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, self.isRunning else { return }
        }
    }

    private func stopLevelTimer() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
}
