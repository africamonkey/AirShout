import Foundation
import MultipeerConnectivity
import AVFAudio
import Combine

struct P2PDevice: Identifiable, Equatable {
    let id: MCPeerID
    var displayName: String
    var isConnected: Bool
    
    static func == (lhs: P2PDevice, rhs: P2PDevice) -> Bool {
        lhs.id == rhs.id
    }
}

final class P2PAudioManager: NSObject, AudioManaging {
    static let shared = P2PAudioManager()
    
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected
    @Published private(set) var peers: [MCPeerID] = []
    
    private let serviceType = "airshout-p2p"
    private var myPeerID: MCPeerID!
    private var session: MCSession!
    private var advertiser: MCNearbyServiceAdvertiser!
    private var browser: MCNearbyServiceBrowser!
    
    private let audioSession = AVAudioSession.sharedInstance()
    
    private var receiverEngine: AVAudioEngine?
    private var receiverPlayerNode: AVAudioPlayerNode?
    private let receiverQueue = DispatchQueue(label: "com.airshout.p2p.receiver")
    
    private var senderEngine: AVAudioEngine?
    private let senderQueue = DispatchQueue(label: "com.airshout.p2p.sender")
    
    private let levelProcessor = AudioLevelProcessor()
    private var invitedPeers: Set<MCPeerID> = []
    private let invitedPeersQueue = DispatchQueue(label: "com.airshout.p2pinvitedpeers")
    
    private override init() {
        super.init()
        setupMultipeer()
    }
    
    private func setupMultipeer() {
        let nickname = UserPreferences.shared.p2pNickname
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
    
    var devices: [P2PDevice] {
        peers.map { peerID in
            P2PDevice(
                id: peerID,
                displayName: peerID.displayName,
                isConnected: true
            )
        }
    }
    
    func start() async throws {
        let granted = await AudioSessionConfig.requestMicrophonePermission()
        guard granted else {
            throw AudioError.microphonePermissionDenied
        }
        
        guard !session.connectedPeers.isEmpty else {
            throw P2PError.notConnected
        }
        
        do {
            try AudioSessionConfig.configure(audioSession)
        } catch {
            throw AudioError.engineSetupFailed
        }
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            senderQueue.async {
                do {
                    try self.setupSenderEngine()
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
    
    private func setupSenderEngine() throws {
        senderEngine?.inputNode.removeTap(onBus: 0)
        senderEngine?.stop()
        senderEngine = nil
        
        senderEngine = AVAudioEngine()
        guard let senderEngine = senderEngine else {
            throw AudioError.engineSetupFailed
        }
        
        let inputNode = senderEngine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        guard inputFormat.sampleRate > 0 else {
            throw AudioError.engineSetupFailed
        }
        
        let connectedPeers = session.connectedPeers
        let levelProcessor = self.levelProcessor
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            guard !connectedPeers.isEmpty else { return }
            
            self.processAudioLevel(buffer, processor: levelProcessor)
            
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            
            let dataSize = frameLength * MemoryLayout<Float>.size
            let data = Data(bytes: channelData[0], count: dataSize)
            
            do {
                try self.session.send(data, toPeers: connectedPeers, with: .unreliable)
            } catch {
                print("Failed to send audio data: \(error)")
            }
        }
        
        senderEngine.prepare()
        try senderEngine.start()
    }
    
    private func stopSenderEngine() {
        senderEngine?.inputNode.removeTap(onBus: 0)
        senderEngine?.stop()
        senderEngine = nil
    }
    
    private func processAudioLevel(_ buffer: AVAudioPCMBuffer, processor: AudioLevelProcessor) {
        let now = Date().timeIntervalSinceReferenceDate
        guard processor.shouldUpdate(now: now) else { return }
        
        guard let level = processor.calculateLevel(from: buffer) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = level
            if level > 0.01 {
                self?.connectionStatus = .transmitting
            }
        }
    }
    
    func stop() {
        senderQueue.async { [weak self] in
            self?.stopSenderEngine()
            
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
    
    func shutdown() {
        stop()
        stopReceiverEngine()
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        invitedPeersQueue.async { [weak self] in
            self?.invitedPeers.removeAll()
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.peers = []
            self?.connectionStatus = .disconnected
        }
    }
    
    func restartBrowsing() {
        browser?.stopBrowsingForPeers()
        advertiser?.stopAdvertisingPeer()
        session?.disconnect()
        invitedPeersQueue.async { [weak self] in
            self?.invitedPeers.removeAll()
        }
        peers.removeAll()
        
        setupMultipeer()
    }
    
    private func startReceiverEngine() {
        receiverQueue.async { [weak self] in
            guard let self = self else { return }
            guard self.receiverEngine == nil else { return }
            
            do {
                try AudioSessionConfig.configure(self.audioSession)
            } catch {
                print("Failed to configure audio session for receiving: \(error)")
                return
            }
            
            self.receiverEngine = AVAudioEngine()
            guard let receiverEngine = self.receiverEngine else { return }
            
            let outputNode = receiverEngine.outputNode
            let mainMixer = receiverEngine.mainMixerNode
            
            self.receiverPlayerNode = AVAudioPlayerNode()
            guard let receiverPlayerNode = self.receiverPlayerNode else { return }
            receiverEngine.attach(receiverPlayerNode)
            
            let outputFormat = outputNode.inputFormat(forBus: 0)
            
            receiverEngine.connect(receiverPlayerNode, to: mainMixer, format: outputFormat)
            receiverEngine.connect(mainMixer, to: outputNode, format: outputFormat)
            
            receiverEngine.prepare()
            do {
                try receiverEngine.start()
            } catch {
                print("Failed to start receiver engine: \(error)")
                return
            }
            receiverPlayerNode.play()
        }
    }
    
    private func stopReceiverEngine() {
        receiverQueue.sync { [weak self] in
            self?.receiverPlayerNode?.stop()
            self?.receiverEngine?.stop()
            self?.receiverEngine = nil
            self?.receiverPlayerNode = nil
        }
    }
    
    private func playAudioData(_ data: Data) {
        receiverQueue.async { [weak self] in
            guard let self = self else { return }
            guard let receiverEngine = self.receiverEngine else {
                return
            }
            guard let receiverPlayerNode = self.receiverPlayerNode else { return }
            
            let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Float>.size)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: receiverEngine.mainMixerNode.outputFormat(forBus: 0), frameCapacity: frameCount) else {
                return
            }
            
            buffer.frameLength = frameCount
            
            data.withUnsafeBytes { rawBufferPointer in
                guard let baseAddress = rawBufferPointer.baseAddress else { return }
                memcpy(buffer.floatChannelData?[0], baseAddress, data.count)
            }
            
            receiverPlayerNode.scheduleBuffer(buffer, completionHandler: nil)
            if !receiverPlayerNode.isPlaying {
                receiverPlayerNode.play()
            }
        }
    }
}

enum P2PError: Error, LocalizedError {
    case notConnected
    
    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "没有连接到任何设备"
        }
    }
}

extension P2PAudioManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .notConnected:
                self?.peers.removeAll { $0 == peerID }
                self?.invitedPeersQueue.async {
                    self?.invitedPeers.remove(peerID)
                }
                if self?.peers.isEmpty == true {
                    self?.connectionStatus = .disconnected
                    self?.stopReceiverEngine()
                }
            case .connecting:
                self?.connectionStatus = .connecting
            case .connected:
                if !(self?.peers.contains(peerID) ?? false) {
                    self?.peers.append(peerID)
                }
                self?.connectionStatus = .connected
                self?.startReceiverEngine()
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        playAudioData(data)
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
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
        invitedPeersQueue.async { [weak self] in
            guard let self = self else { return }
            guard !self.invitedPeers.contains(peerID) && self.session.connectedPeers.isEmpty else { return }
            self.invitedPeers.insert(peerID)
            browser.invitePeer(peerID, to: self.session, withContext: nil, timeout: 30)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.peers.removeAll { $0 == peerID }
            self?.invitedPeersQueue.async {
                self?.invitedPeers.remove(peerID)
            }
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
