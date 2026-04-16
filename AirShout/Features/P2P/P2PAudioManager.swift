import Foundation
import MultipeerConnectivity
import AVFAudio
import Combine

final class P2PAudioManager: NSObject, ObservableObject {
    static let shared = P2PAudioManager()
    
    enum Role {
        case sender
        case receiver
    }
    
    enum P2PConnectionState: Equatable {
        case disconnected
        case discovering
        case connected
        case speaking
        case receiving
        case error(String)
    }
    
    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var connectionState: P2PConnectionState = .disconnected
    @Published private(set) var discoveredPeers: [PeerInfo] = []
    
    private var role: Role = .receiver
    private var session: MCSession?
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var discoveredPeerIDs: [String: MCPeerID] = [:]
    private var peerAddressInfo: [String: PeerInfo] = [:]
    
    private let audioSession = AVAudioSession.sharedInstance()
    private var tcpManager: TCPConnectionManager?
    private var listeningAddress: (ip: String, port: Int)?
    
    private let levelProcessor = AudioLevelProcessor()
    private var speakingEngineRunning = false
    private let engineQueue = DispatchQueue(label: "com.airshout.p2paudioengine")
    private let roleQueue = DispatchQueue(label: "com.airshout.p2prole")
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    
    private var audioBufferQueue: [Data] = []
    private let maxBufferedPackets = 10
    private let minBufferedPackets = 3
    private let maxScheduledBuffers = 30
    
    private var playbackReady = false
    private var scheduledBuffers: Int = 0
    private var receiveBuffer = Data()
    
    private func currentRole() -> Role {
        roleQueue.sync { role }
    }
    
    private func setRole(_ newRole: Role) {
        roleQueue.sync { role = newRole }
    }
    
    private override init() {
        super.init()
        tcpManager = TCPConnectionManager(role: .receiver)
        setupTCPCallbacks()
        startDiscovery()
    }
    
    // MARK: - TCP Callbacks
    
    private func setupTCPCallbacks() {
        tcpManager?.onAudioReceived = { [weak self] data, _ in
            self?.playAudioData(data)
        }
        
        tcpManager?.onPeerDisconnected = { [weak self] _ in
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                self?.isRunning = false
            }
        }
    }
    
    // MARK: - Discovery Mode
    
    func startDiscovery() {
        cleanupCurrentRole()
        
        tcpManager?.stopListening()
        tcpManager = TCPConnectionManager(role: .receiver)
        setupTCPCallbacks()
        
        setupMultipeerSession()
        startTCPListening()
        
        DispatchQueue.main.async {
            self.connectionState = .discovering
        }
    }
    
    private func setupMultipeerSession() {
        let myPeerID = MCPeerID(displayName: UIDevice.current.name)
        session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session?.delegate = self
        
        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: "airshout-p2p")
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: "airshout-p2p")
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }
    
    private func startTCPListening() {
        Task {
            do {
                guard let tcpManager = self.tcpManager else { return }
                let (ip, port) = try await tcpManager.startListening()
                self.listeningAddress = (ip: ip, port: port)
                print("TCP listening on \(ip):\(port)")
                
                await MainActor.run {
                    self.connectionState = .discovering
                }
            } catch {
                print("Failed to start TCP listening: \(error)")
            }
        }
    }
    
    private func sendAddressInfo(to peerID: MCPeerID) {
        guard let address = listeningAddress else { return }
        
        let deviceID = DeviceIdentifier.shared.currentDeviceID
        let displayName = UIDevice.current.name
        let addressInfo = PeerMessage.addressInfo(
            deviceID: deviceID,
            displayName: displayName,
            localIP: address.ip,
            port: address.port
        )
        
        if let data = try? JSONEncoder().encode(addressInfo) {
            try? session?.send(data, toPeers: [peerID], with: .reliable)
        }
    }
    
    // MARK: - Cleanup
    
    private func cleanupCurrentRole() {
        advertiser?.stopAdvertisingPeer()
        advertiser = nil
        
        browser?.stopBrowsingForPeers()
        browser = nil
        
        session?.disconnect()
        session = nil
        
        DispatchQueue.main.async { [weak self] in
            self?.discoveredPeers.removeAll()
            self?.discoveredPeerIDs.removeAll()
            self?.peerAddressInfo.removeAll()
        }
    }
    
    // MARK: - Speaking (Sender)
    
    func startSpeaking() {
        guard currentRole() == .receiver else { return }
        guard tcpManager?.isConnected != true else { return }
        
        guard let firstPeerAddress = peerAddressInfo.values.first else {
            print("No peer address available")
            return
        }
        
        setRole(.sender)
        
        Task {
            do {
                try await tcpManager?.connect(to: firstPeerAddress)
                await MainActor.run {
                    self.connectionState = .speaking
                    self.isRunning = true
                }
                self.startSendingAudio()
            } catch {
                print("TCP connection failed: \(error)")
                await MainActor.run {
                    self.connectionState = .error("连接失败: \(error.localizedDescription)")
                    self.setRole(.receiver)
                }
            }
        }
    }
    
    func stopSpeaking() {
        guard currentRole() == .sender else { return }
        
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.speakingEngineRunning = false
            
            self.audioEngine?.inputNode.removeTap(onBus: 0)
            self.audioEngine?.stop()
            self.audioEngine = nil
            
            DispatchQueue.main.async {
                self.connectionState = .disconnected
                self.isRunning = false
                self.setRole(.receiver)
            }
        }
        
        tcpManager?.disconnect()
    }
    
    private func startSendingAudio() {
        speakingEngineRunning = true
        
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            
            let audioEngine = AVAudioEngine()
            let inputNode = audioEngine.inputNode
            
            let inputFormat = inputNode.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0 else {
                self.speakingEngineRunning = false
                return
            }
            
            let levelProcessor = self.levelProcessor
            let sampleRate = inputFormat.sampleRate
            
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
                guard let self = self, self.speakingEngineRunning else { return }
                
                self.processSpeakingLevel(buffer, processor: levelProcessor)
                
                guard let channelData = buffer.floatChannelData else { return }
                let frameLength = Int(buffer.frameLength)
                let dataSize = frameLength * MemoryLayout<Float>.size
                
                let header = AudioPacketHeader(sampleRate: sampleRate, frameCount: UInt32(frameLength))
                var packetData = header.serialize()
                packetData.append(Data(bytes: channelData[0], count: dataSize))
                
                self.tcpManager?.sendAudio(packetData)
            }
            
            do {
                try audioEngine.start()
                self.audioEngine = audioEngine
            } catch {
                print("Failed to start speaking engine: \(error)")
                self.speakingEngineRunning = false
            }
        }
    }
    
    private func processSpeakingLevel(_ buffer: AVAudioPCMBuffer, processor: AudioLevelProcessor) {
        let now = Date().timeIntervalSinceReferenceDate
        guard processor.shouldUpdate(now: now) else { return }
        guard let level = processor.calculateLevel(from: buffer) else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = level
        }
    }
    
    // MARK: - Audio Playback (Receiver)
    
    private func playAudioData(_ data: Data) {
        engineQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.receiveBuffer.append(data)
            
            while true {
                guard self.receiveBuffer.count > AudioPacketHeader.serializedSize else {
                    break
                }
                
                let headerData = self.receiveBuffer.prefix(AudioPacketHeader.serializedSize)
                guard let header = AudioPacketHeader.deserialize(from: headerData) else {
                    self.receiveBuffer.removeFirst()
                    continue
                }
                
                let packetSize = AudioPacketHeader.serializedSize + Int(header.frameCount) * MemoryLayout<Float>.size
                
                guard self.receiveBuffer.count >= packetSize else {
                    break
                }
                
                let packetData = self.receiveBuffer.prefix(packetSize)
                self.receiveBuffer.removeFirst(packetSize)
                
                if self.audioBufferQueue.count >= self.maxBufferedPackets {
                    self.audioBufferQueue.removeFirst()
                }
                self.audioBufferQueue.append(Data(packetData))
            }
            
            if self.audioEngine == nil && !self.audioBufferQueue.isEmpty {
                self.setupReceiverAudioEngine()
            }
            
            if !self.playbackReady {
                self.checkBufferReady()
            }
            
            if self.playbackReady {
                self.processAudioData()
            }
        }
    }
    
    private func checkBufferReady() {
        guard audioBufferQueue.count >= 5 else { return }
        
        playbackReady = true
    }
    
    private func processAudioData() {
        guard let playerNode = self.playerNode,
              let audioEngine = self.audioEngine else { return }
        
        while audioBufferQueue.count > minBufferedPackets && scheduledBuffers < maxScheduledBuffers {
            let data = audioBufferQueue.removeFirst()
            
            let headerSize = AudioPacketHeader.serializedSize
            guard data.count > headerSize else { continue }
            
            let headerData = data.prefix(headerSize)
            let audioData = data.dropFirst(headerSize)
            
            guard let header = AudioPacketHeader.deserialize(from: headerData) else { continue }
            
            let targetFormat = audioEngine.mainMixerNode.outputFormat(forBus: 0)
            let sourceFormat = AVAudioFormat(standardFormatWithSampleRate: header.sampleRate, channels: 1)!
            
            guard let converter = AVAudioConverter(from: sourceFormat, to: targetFormat) else { continue }
            
            let inputFrameCount = AVAudioFrameCount(audioData.count / MemoryLayout<Float>.size)
            guard let sourceBuffer = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: inputFrameCount) else { continue }
            sourceBuffer.frameLength = inputFrameCount
            
            audioData.withUnsafeBytes { rawBufferPointer in
                guard let baseAddress = rawBufferPointer.baseAddress else { return }
                memcpy(sourceBuffer.floatChannelData?[0], baseAddress, audioData.count)
            }
            
            var error: NSError?
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return sourceBuffer
            }
            
            guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: inputFrameCount * 2) else { continue }
            
            let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)
            
            guard error == nil, status == .haveData, outputBuffer.frameLength > 0 else { continue }
            
            scheduledBuffers += 1
            playerNode.scheduleBuffer(outputBuffer, at: nil, options: [], completionHandler: { [weak self] in
                DispatchQueue.main.async {
                    self?.scheduledBuffers -= 1
                }
            })
        }
        
        if !playerNode.isPlaying {
            playerNode.play()
        }
    }
    
    private func setupReceiverAudioEngine() {
        do {
            try AudioSessionConfig.configure(audioSession)
        } catch {
            print("Failed to configure audio session: \(error)")
            return
        }
        
        playbackReady = false
        scheduledBuffers = 0
        
        let audioEngine = AVAudioEngine()
        let outputNode = audioEngine.outputNode
        let mainMixer = audioEngine.mainMixerNode
        
        let playerNode = AVAudioPlayerNode()
        audioEngine.attach(playerNode)
        
        let outputFormat = outputNode.inputFormat(forBus: 0)
        audioEngine.connect(playerNode, to: mainMixer, format: outputFormat)
        audioEngine.connect(mainMixer, to: outputNode, format: outputFormat)
        
        do {
            try audioEngine.start()
            self.audioEngine = audioEngine
            self.playerNode = playerNode
            
            DispatchQueue.main.async {
                self.connectionState = .receiving
            }
        } catch {
            print("Failed to start receiver audio engine: \(error)")
            audioEngine.stop()
        }
    }
    
    // MARK: - Public Methods
    
    func shutdown() {
        stopSpeaking()
        
        engineQueue.async { [weak self] in
            self?.audioEngine?.stop()
            self?.audioEngine = nil
            self?.playerNode = nil
            
            self?.tcpManager?.disconnect()
            self?.tcpManager = nil
            
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                self?.isRunning = false
            }
        }
        
        cleanupCurrentRole()
    }
}

struct AudioPacketHeader {
    let sampleRate: Double
    let frameCount: UInt32
    
    static let serializedSize: Int = 12
    
    func serialize() -> Data {
        var data = Data()
        var sampleRateBits = sampleRate.bitPattern.littleEndian
        var frameCountVal = frameCount.littleEndian
        withUnsafeBytes(of: &sampleRateBits) { data.append(contentsOf: $0) }
        withUnsafeBytes(of: &frameCountVal) { data.append(contentsOf: $0) }
        return data
    }
    
    static func deserialize(from data: Data) -> AudioPacketHeader? {
        guard data.count >= serializedSize else { return nil }
        
        var sampleRateBits: UInt64 = 0
        var frameCount: UInt32 = 0
        
        data.withUnsafeBytes { buffer in
            memcpy(&sampleRateBits, buffer.baseAddress!, MemoryLayout<UInt64>.size)
            memcpy(&frameCount, buffer.baseAddress! + 8, MemoryLayout<UInt32>.size)
        }
        
        sampleRateBits = sampleRateBits.littleEndian
        frameCount = frameCount.littleEndian
        
        return AudioPacketHeader(sampleRate: Double(bitPattern: sampleRateBits), frameCount: frameCount)
    }
}

// MARK: - MCSessionDelegate

extension P2PAudioManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            switch state {
            case .notConnected:
                self?.discoveredPeers.removeAll { $0.displayName == peerID.displayName }
                self?.discoveredPeerIDs.removeValue(forKey: peerID.displayName)
                self?.peerAddressInfo.removeValue(forKey: peerID.displayName)
            case .connecting:
                break
            case .connected:
                if !(self?.discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) ?? true) {
                    let info = PeerInfo(deviceID: peerID.displayName, displayName: peerID.displayName)
                    self?.discoveredPeers.append(info)
                    self?.discoveredPeerIDs[peerID.displayName] = peerID
                }
                self?.sendAddressInfo(to: peerID)
            @unknown default:
                break
            }
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        guard let message = try? JSONDecoder().decode(PeerMessage.self, from: data) else { return }
        
        switch message {
        case .addressInfo(let deviceID, let displayName, let localIP, let port):
            var info = PeerInfo(deviceID: deviceID, displayName: displayName)
            info.ip = localIP
            info.port = port
            
            DispatchQueue.main.async { [weak self] in
                if let index = self?.discoveredPeers.firstIndex(where: { $0.deviceID == deviceID }) {
                    self?.discoveredPeers[index] = info
                } else {
                    self?.discoveredPeers.append(info)
                }
                self?.peerAddressInfo[deviceID] = info
            }
            
        case .requestAddress:
            break
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - MCNearbyServiceAdvertiserDelegate

extension P2PAudioManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        guard let session = session else {
            invitationHandler(false, nil)
            return
        }
        invitationHandler(true, session)
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("Failed to advertise: \(error)")
    }
}

// MARK: - MCNearbyServiceBrowserDelegate

extension P2PAudioManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let session = self.session else { return }
            
            if !self.discoveredPeers.contains(where: { $0.displayName == peerID.displayName }) {
                let peerInfo = PeerInfo(deviceID: peerID.displayName, displayName: peerID.displayName)
                self.discoveredPeers.append(peerInfo)
                self.discoveredPeerIDs[peerID.displayName] = peerID
            }
            
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.discoveredPeers.removeAll { $0.displayName == peerID.displayName }
            self?.discoveredPeerIDs.removeValue(forKey: peerID.displayName)
            self?.peerAddressInfo.removeValue(forKey: peerID.displayName)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .error("浏览失败: \(error.localizedDescription)")
        }
    }
}
