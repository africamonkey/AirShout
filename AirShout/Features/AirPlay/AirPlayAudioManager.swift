import Foundation
import AVFAudio
import Combine

final class AirPlayAudioManager: AudioManaging {
    static let shared = AirPlayAudioManager()
    
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    
    private var audioEngine: AVAudioEngine?
    private let audioSession = AVAudioSession.sharedInstance()
    private var playerNode: AVAudioPlayerNode?
    private var routeChangeObserver: NSObjectProtocol?
    private var isSessionConfigured = false
    private var isRestarting = false
    
    private let engineQueue = DispatchQueue(label: "com.airshout.airplay.audioengine")
    private let stateQueue = DispatchQueue(label: "com.airshout.airplay.state")
    
    private let levelProcessor = AudioLevelProcessor()
    
    private init() {
        setupRouteChangeObserver()
    }
    
    deinit {
        if let observer = routeChangeObserver {
            NotificationCenter.default.removeObserver(observer)
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
        } catch AudioError.noInputAvailable {
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
        
        let granted = await AudioSessionConfig.requestMicrophonePermission()
        guard granted else {
            connectionStatus = .disconnected
            throw AudioError.microphonePermissionDenied
        }
        
        if !isSessionConfigured {
            try AudioSessionConfig.configure(audioSession)
            isSessionConfigured = true
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            engineQueue.async {
                do {
                    try self.setupAndStartEngine()
                    // TODO: UserPreferences will be implemented in Task 4
                    // UserPreferences.shared.saveCurrentDeviceUID()
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
    }
    
    private func setupAndStartEngine() throws {
        playerNode?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        
        guard let availableInputs = audioSession.availableInputs, !availableInputs.isEmpty else {
            throw AudioError.noInputAvailable
        }
        
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
        
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = outputNode.inputFormat(forBus: 0)
        
        guard inputFormat.sampleRate > 0 else {
            throw AudioError.noInputAvailable
        }
        
        audioEngine.connect(playerNode, to: mainMixer, format: inputFormat)
        audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)
        
        let levelProcessor = self.levelProcessor
        let isRunning = self.isRunning
        let capturedPlayerNode = self.playerNode
        let connectionStatus = self.connectionStatus
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.engineQueue.async {
                self.processAudioBuffer(buffer, processor: levelProcessor, isTransmitting: connectionStatus.isTransmitting)
                guard isRunning else { return }
                capturedPlayerNode?.scheduleBuffer(buffer, completionHandler: nil)
            }
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
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, processor: AudioLevelProcessor, isTransmitting: Bool) {
        let now = Date().timeIntervalSinceReferenceDate
        guard processor.shouldUpdate(now: now) else { return }
        
        guard let level = processor.calculateLevel(from: buffer) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = level
            if !isTransmitting && level > 0.01 {
                self?.connectionStatus = .transmitting
            }
        }
    }
}
