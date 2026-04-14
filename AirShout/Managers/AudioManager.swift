import Foundation
import AVFAudio
import Combine

final class AudioManager: ObservableObject {
    static let shared = AudioManager()

    @Published var audioLevel: Float = 0
    @Published var isRunning: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected

    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case transmitting
        case error(String)
        
        var isTransmitting: Bool {
            if case .transmitting = self { return true }
            return false
        }
    }

    private var audioEngine: AVAudioEngine?
    private let audioSession = AVAudioSession.sharedInstance()
    private var playerNode: AVAudioPlayerNode?
    private var routeChangeObserver: NSObjectProtocol?
    private var isSessionConfigured = false
    private var lastAudioLevelUpdate: TimeInterval = 0
    private let audioLevelUpdateInterval: TimeInterval = 0.05
    private var isRestarting = false

    private let engineQueue = DispatchQueue(label: "com.airshout.audioengine")
    private let stateQueue = DispatchQueue(label: "com.airshout.state")

    private init() {
        setupRouteChangeObserver()
    }

    enum AudioError: Error, LocalizedError {
        case microphonePermissionDenied
        case engineSetupFailed
        case noInputAvailable
        
        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "麦克风权限被拒绝"
            case .engineSetupFailed:
                return "音频引擎设置失败"
            case .noInputAvailable:
                return "没有可用的输入设备，请确保已选择音频输出设备"
            }
        }
    }
    
    private func hasValidInput() -> Bool {
        let availableInputs = audioSession.availableInputs
        return availableInputs != nil && !(availableInputs?.isEmpty ?? true)
    }
    
    private func checkInputAvailability() throws {
        guard hasValidInput() else {
            throw AudioError.noInputAvailable
        }
        
        let inputFormat = audioSession.inputDataSource?.dataSourceID
        print("Available inputs: \(audioSession.availableInputs?.map { $0.portName } ?? []), current input format sample rate: \(audioSession.sampleRate)")
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
            let running = isRunning
            if running && !isRestarting {
                isRestarting = true
                engineQueue.async { [weak self] in
                    self?.restartEngineInternal()
                    self?.isRestarting = false
                }
            }
        default:
            break
        }
    }

    private func restartEngineInternal() {
        stopEngineOnly()

        do {
            try setupAndStartEngine()
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = true
            }
        } catch AudioManager.AudioError.noInputAvailable {
            print("Failed to restart engine: noInputAvailable")
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.audioLevel = 0
                self?.connectionStatus = .error("没有可用的输入设备")
            }
        } catch {
            print("Failed to restart engine: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.connectionStatus = .disconnected
            }
        }
    }

    func start() async throws {
        connectionStatus = .connecting
        
        let granted = await requestMicrophonePermission()
        guard granted else {
            connectionStatus = .disconnected
            throw AudioError.microphonePermissionDenied
        }
        
        if !isSessionConfigured {
            try configureAudioSession()
            isSessionConfigured = true
        }

        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                engineQueue.async {
                    do {
                        try self.setupAndStartEngine()
                        self.saveCurrentDeviceUID()
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = true
                self?.connectionStatus = .connected
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.connectionStatus = .disconnected
            }
            throw error
        }
    }

    private func setupAndStartEngine() throws {
        // Stop existing engine if any
        playerNode?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil

        // Check for available input before setting up
        guard let availableInputs = audioSession.availableInputs, !availableInputs.isEmpty else {
            throw AudioError.noInputAvailable
        }

        // Create new engine
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioError.engineSetupFailed
        }

        let inputNode = audioEngine.inputNode
        let outputNode = audioEngine.outputNode
        let mainMixer = audioEngine.mainMixerNode

        playerNode = AVAudioPlayerNode()
        guard let playerNode = playerNode else {
            throw AudioError.engineSetupFailed
        }
        audioEngine.attach(playerNode)

        // Use the actual input format from the hardware
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = outputNode.inputFormat(forBus: 0)

        // Validate input format - if sample rate is 0, we cannot proceed
        guard inputFormat.sampleRate > 0 else {
            throw AudioError.noInputAvailable
        }

        audioEngine.connect(playerNode, to: mainMixer, format: inputFormat)
        audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.processAudioBuffer(buffer)
            self.playerNode?.scheduleBuffer(buffer, completionHandler: nil)
        }

        audioEngine.prepare()
        try audioEngine.start()
        playerNode.play()
    }

    private func stopEngineOnly() {
        playerNode?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }

    func stop() {
        engineQueue.async { [weak self] in
            self?.stopEngineOnly()
            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.audioLevel = 0
                self?.connectionStatus = .disconnected
            }
        }
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetoothA2DP, .allowBluetoothHFP, .allowAirPlay])
        
        // Set preferred sample rate before activating
        let preferredSampleRate: Double = 44100
        try audioSession.setPreferredSampleRate(preferredSampleRate)
        
        try audioSession.setActive(true)
    }

    private func saveCurrentDeviceUID() {
        guard let deviceUID = audioSession.currentRoute.outputs.first?.uid else { return }
        DevicePreferences.save(deviceUID: deviceUID)
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

        let now = Date().timeIntervalSinceReferenceDate
        guard now - lastAudioLevelUpdate >= audioLevelUpdateInterval else { return }
        lastAudioLevelUpdate = now

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = normalizedLevel
            if !(self?.connectionStatus.isTransmitting ?? false) && normalizedLevel > 0.01 {
                self?.connectionStatus = .transmitting
            }
        }
    }
}
