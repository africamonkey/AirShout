import Foundation
import MultipeerConnectivity
import AVFAudio
import Combine

struct Device: Identifiable, Equatable {
    let id: MCPeerID
    var displayName: String
    var isConnected: Bool

    static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id
    }
}

final class P2PAudioManager: NSObject, ObservableObject {
    static let shared = P2PAudioManager()

    @Published var audioLevel: Float = 0
    @Published var isRunning: Bool = false
    @Published var connectionStatus: P2PConnectionStatus = .disconnected
    @Published var peers: [MCPeerID] = []

    enum P2PConnectionStatus {
        case disconnected
        case connecting
        case connected
        case speaking
        case error(String)

        var isTransmitting: Bool {
            if case .speaking = self { return true }
            return false
        }
    }

    enum P2PError: Error, LocalizedError {
        case microphonePermissionDenied
        case engineSetupFailed
        case notConnected

        var errorDescription: String? {
            switch self {
            case .microphonePermissionDenied:
                return "麦克风权限被拒绝"
            case .engineSetupFailed:
                return "音频引擎设置失败"
            case .notConnected:
                return "没有连接到任何设备"
            }
        }
    }

    private let serviceType = "airshout-p2p"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!

    private var audioEngine: AVAudioEngine?
    private let audioSession = AVAudioSession.sharedInstance()
    private var playerNode: AVAudioPlayerNode?
    private let engineQueue = DispatchQueue(label: "com.airshout.p2paudioengine")
    private var lastAudioLevelUpdate: TimeInterval = 0
    private let audioLevelUpdateInterval: TimeInterval = 0.05
    
    private var _audioEngineRunning = false
    private let stateQueue = DispatchQueue(label: "com.airshout.p2pstate")
    private var invitedPeers: Set<MCPeerID> = []

    private override init() {
        super.init()
        setupMultipeer()
    }

    private func setupMultipeer() {
        let nickname = UserDefaults.standard.string(forKey: "p2p_nickname") ?? UIDevice.current.name
        myPeerID = MCPeerID(displayName: nickname)

        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self

        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()

        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    private func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func configureAudioSession() throws {
        try audioSession.setCategory(
            .playAndRecord,
            mode: .default,
            options: [.allowBluetoothA2DP, .allowBluetoothHFP, .allowAirPlay])

        let preferredSampleRate: Double = 44100
        try audioSession.setPreferredSampleRate(preferredSampleRate)

        try audioSession.setActive(true)
    }

    private func setupAudioEngineForSpeaking() throws {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw P2PError.engineSetupFailed
        }

        let inputNode = audioEngine.inputNode
        let outputNode = audioEngine.outputNode
        let mainMixer = audioEngine.mainMixerNode

        playerNode = AVAudioPlayerNode()
        guard let playerNode = playerNode else {
            throw P2PError.engineSetupFailed
        }
        audioEngine.attach(playerNode)

        let inputFormat = inputNode.outputFormat(forBus: 0)
        let outputFormat = outputNode.inputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0 else {
            throw P2PError.engineSetupFailed
        }

        audioEngine.connect(playerNode, to: mainMixer, format: inputFormat)
        audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)

        let connectedPeers = session.connectedPeers
        let isEngineRunning = _audioEngineRunning

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            guard isEngineRunning else { return }
            guard !connectedPeers.isEmpty else { return }

            self.processAudioLevel(buffer)

            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)

            let dataSize = frameLength * MemoryLayout<Float>.size
            let data = Data(bytes: channelData[0], count: dataSize)

            do {
                try self.session.send(data, toPeers: connectedPeers, with: .unreliable)
            } catch {
                print("Failed to send audio data: \(error)")
            }

            self.playerNode?.scheduleBuffer(buffer, completionHandler: nil)
        }

        audioEngine.prepare()
        try audioEngine.start()
        playerNode.play()
    }

    private func setupAudioEngineForReceiving() {
        guard audioEngine == nil else { return }

        do {
            try configureAudioSession()
        } catch {
            print("Failed to configure audio session for receiving: \(error)")
            return
        }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else { return }

        let outputNode = audioEngine.outputNode
        let mainMixer = audioEngine.mainMixerNode

        playerNode = AVAudioPlayerNode()
        guard let playerNode = playerNode else { return }
        audioEngine.attach(playerNode)

        let outputFormat = outputNode.inputFormat(forBus: 0)

        audioEngine.connect(playerNode, to: mainMixer, format: outputFormat)
        audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine for receiving: \(error)")
            return
        }
        playerNode.play()
    }

    private func stopAudioEngineForReceiving() {
        playerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
    }

    private func processAudioLevel(_ buffer: AVAudioPCMBuffer) {
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
            if normalizedLevel > 0.01 {
                self?.connectionStatus = .speaking
            }
        }
    }

    func startSpeaking() async throws {
        let granted = await requestMicrophonePermission()
        guard granted else {
            throw P2PError.microphonePermissionDenied
        }

        guard !session.connectedPeers.isEmpty else {
            throw P2PError.notConnected
        }

        do {
            try configureAudioSession()
        } catch {
            throw P2PError.engineSetupFailed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            engineQueue.async {
                self.stateQueue.async {
                    self._audioEngineRunning = true
                }
                do {
                    try self.setupAudioEngineForSpeaking()
                    continuation.resume()
                } catch {
                    self.stateQueue.async {
                        self._audioEngineRunning = false
                    }
                    continuation.resume(throwing: error)
                }
            }
        }

        DispatchQueue.main.async { [weak self] in
            self?.isRunning = true
            self?.connectionStatus = .speaking
        }
    }

    func stopSpeaking() {
        engineQueue.async { [weak self] in
            self?.stateQueue.async {
                self?._audioEngineRunning = false
            }
            self?.playerNode?.stop()
            self?.audioEngine?.inputNode.removeTap(onBus: 0)
            self?.audioEngine?.stop()
            self?.audioEngine = nil
            self?.playerNode = nil

            DispatchQueue.main.async { [weak self] in
                self?.isRunning = false
                self?.audioLevel = 0
                if self?.peers.isEmpty == true {
                    self?.connectionStatus = .disconnected
                } else {
                    self?.connectionStatus = .connected
                }
            }
        }
    }

    func stop() {
        stopSpeaking()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        invitedPeers.removeAll()

        DispatchQueue.main.async { [weak self] in
            self?.peers = []
            self?.connectionStatus = .disconnected
        }
    }

    func restartBrowsing() {
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        session?.disconnect()
        invitedPeers.removeAll()
        peers.removeAll()

        setupMultipeer()
    }

    private func playAudioData(_ data: Data) {
        engineQueue.async { [weak self] in
            guard let self = self, let audioEngine = self.audioEngine else { return }
            guard let playerNode = self.playerNode else { return }

            let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Float>.size)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: audioEngine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else {
                return
            }

            buffer.frameLength = frameCount

            data.withUnsafeBytes { rawBufferPointer in
                guard let baseAddress = rawBufferPointer.baseAddress else { return }
                memcpy(buffer.floatChannelData?[0], baseAddress, data.count)
            }

            playerNode.scheduleBuffer(buffer, completionHandler: nil)
            if !playerNode.isPlaying {
                playerNode.play()
            }
        }
    }
}

extension P2PAudioManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .notConnected:
                self?.peers.removeAll { $0 == peerID }
                self?.invitedPeers.remove(peerID)
                if self?.peers.isEmpty == true {
                    self?.connectionStatus = .disconnected
                    self?.stopAudioEngineForReceiving()
                }
            case .connecting:
                self?.connectionStatus = .connecting
            case .connected:
                if !(self?.peers.contains(peerID) ?? false) {
                    self?.peers.append(peerID)
                }
                self?.connectionStatus = .connected
                self?.setupAudioEngineForReceiving()
            @unknown default:
                break
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        playAudioData(data)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    }
}

extension P2PAudioManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to advertise: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = .error("广播失败: \(error.localizedDescription)")
        }
    }
}

extension P2PAudioManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        if !invitedPeers.contains(peerID) && session.connectedPeers.isEmpty {
            invitedPeers.insert(peerID)
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.peers.removeAll { $0 == peerID }
            self?.invitedPeers.remove(peerID)
            if self?.peers.isEmpty == true {
                self?.connectionStatus = .disconnected
            }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        print("Failed to browse: \(error)")
        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = .error("浏览失败: \(error.localizedDescription)")
        }
    }
}

extension P2PAudioManager {
    var devices: [Device] {
        peers.map { peerID in
            Device(
                id: peerID,
                displayName: peerID.displayName,
                isConnected: true
            )
        }
    }
}
