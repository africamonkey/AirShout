import Foundation
import AVFAudio
import Combine

final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var audioLevel: Float = 0
    @Published var isRunning: Bool = false

    private var audioEngine: AVAudioEngine?
    private let audioSession = AVAudioSession.sharedInstance()
    private var playerNode: AVAudioPlayerNode?
    private var routeChangeObserver: NSObjectProtocol?
    private var isSessionConfigured = false
    private var isEngineConfigured = false

    private init() {
        setupRouteChangeObserver()
    }

    enum AudioError: Error {
        case microphonePermissionDenied
    }

    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func setupRouteChangeObserver() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleRouteChange(notification)
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .newDeviceAvailable, .oldDeviceUnavailable, .override, .routeConfigurationChange:
            if isRunning {
                DispatchQueue.main.async { [weak self] in
                    self?.restartEngine()
                }
            }
        default:
            break
        }
    }

    private func restartEngine() {
        let wasRunning = isRunning
        if wasRunning {
            stopEngineOnly()
        }
        isEngineConfigured = false

        do {
            try setupAndStartEngine()
            isRunning = true
        } catch {
            print("Failed to restart engine: \(error)")
        }
    }

    func start() async throws {
        let granted = await requestMicrophonePermission()
        guard granted else {
            throw AudioError.microphonePermissionDenied
        }
        
        if !isSessionConfigured {
            try configureAudioSession()
            isSessionConfigured = true
        }

        try setupAndStartEngine()
        isRunning = true
    }

    private func setupAndStartEngine() throws {
        if isEngineConfigured {
            // Engine already configured, just start it
            try audioEngine?.start()
            playerNode?.play()
        } else {
            // First time: create engine from scratch
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else { return }

            let inputNode = audioEngine.inputNode
            let outputNode = audioEngine.outputNode
            let mainMixer = audioEngine.mainMixerNode

            playerNode = AVAudioPlayerNode()
            guard let playerNode = playerNode else { return }
            audioEngine.attach(playerNode)

            let inputFormat = inputNode.outputFormat(forBus: 0)
            let outputFormat = outputNode.inputFormat(forBus: 0)

            audioEngine.connect(playerNode, to: mainMixer, format: inputFormat)
            audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer)
                self?.playerNode?.scheduleBuffer(buffer, completionHandler: nil)
            }

            audioEngine.prepare()
            try audioEngine.start()
            playerNode.play()

            isEngineConfigured = true
        }
    }

    private func stopEngineOnly() {
        playerNode?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        // A+: Keep engine and playerNode, just stop them
        // isEngineConfigured stays true
    }

    func stop() {
        stopEngineOnly()
        isRunning = false
        audioLevel = 0
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetoothHFP, .allowAirPlay])
        try audioSession.setActive(true)
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channelDataValue = channelData.pointee
        
        var sum: Float = 0
        for i in stride(from: 0, to: Int(buffer.frameLength), by: buffer.stride) {
            let sample = channelDataValue[i]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(buffer.frameLength))
        let avgPower = 20 * log10(max(rms, 0.000001))
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = normalizedLevel
        }
    }
}
