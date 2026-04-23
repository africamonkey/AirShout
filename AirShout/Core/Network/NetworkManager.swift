import Foundation
import Network
import AVFAudio
import Combine

enum NetworkError: Error, LocalizedError {
    case portInUse
    case connectionFailed(String)
    case notConnected
    case engineSetupFailed

    var errorDescription: String? {
        switch self {
        case .portInUse:
            return String(localized: "network.error.port.in.use", defaultValue: "Port is already in use, please change port")
        case .connectionFailed(let reason):
            return String(localized: "network.error.connection.failed.with.reason", defaultValue: "Connection failed: \(reason)")
        case .notConnected:
            return String(localized: "network.error.not.connected", defaultValue: "Not connected to any device")
        case .engineSetupFailed:
            return String(localized: "audio.error.engine.setup.failed", defaultValue: "Audio engine setup failed")
        }
    }
}

final class NetworkManager: NSObject, AudioManaging {
    static let shared = NetworkManager()

    @Published private(set) var audioLevel: Float = 0
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var connectionStatus: ConnectionStatus = .disconnected

    private var listener: NWListener?
    private var clientConnection: NWConnection?
    private var serverConnections: [NWConnection] = []
    private var localPort: UInt16 = 38800

    private var isServerMode: Bool = false

    private var senderEngine: AVAudioEngine?
    private var receiverEngine: AVAudioEngine?
    private var receiverPlayerNode: AVAudioPlayerNode?
    private let receiverQueue = DispatchQueue(label: "com.airshout.network.receiver")

    private let packetProcessor = PacketProcessor()
    private let levelProcessor = AudioLevelProcessor()

    private var remoteSampleRate: Double = 44100

    private let networkQueue = DispatchQueue(label: "com.airshout.network")
    private let audioSession = AVAudioSession.sharedInstance()

    private let connectionsQueue = DispatchQueue(label: "com.airshout.network.connections")
    private var activeConnection: NWConnection?
    private var isReceiving: Bool = false
    private var isDisconnecting: Bool = false

    private var connectingTimer: Timer?
    private var currentConnectingId: Int = 0
    private let connectingTimeout: TimeInterval = 3.0
    private var pendingConnectionId: Int = 0

    private override init() {
        super.init()
    }

    func startListening(port: UInt16) throws {
        localPort = port
        isServerMode = true

        listener?.cancel()
        listener = nil

        let params = NWParameters.tcp
        params.allowLocalEndpointReuse = true

        do {
            listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            throw NetworkError.connectionFailed(error.localizedDescription)
        }

        listener?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                Swift.print("TCP Listener ready on port \(port)")
            case .failed(let error):
                Swift.print("TCP Listener failed: \(error)")
                DispatchQueue.main.async {
                    self.connectionStatus = .error(String(localized: "network.listen.failed", defaultValue: "Listen failed: \(error.localizedDescription)"))
                }
            case .cancelled:
                Swift.print("TCP Listener cancelled")
            default:
                break
            }
        }

        listener?.newConnectionHandler = { [weak self] conn in
            self?.handleIncomingConnection(conn)
        }

        listener?.start(queue: networkQueue)
    }

    func stopListening() {
        listener?.cancel()
        listener = nil

        connectionsQueue.async { [weak self] in
            guard let self = self else { return }
            self.serverConnections.forEach { $0.cancel() }
            self.serverConnections.removeAll()
            self.activeConnection = nil
            self.isServerMode = false
        }
    }

    private func handleIncomingConnection(_ conn: NWConnection) {
        connectionsQueue.async { [weak self] in
            guard let self = self else { return }
            self.serverConnections.append(conn)
            self.activeConnection = conn
        }

        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                DispatchQueue.main.async {
                    self.connectionStatus = .connected
                }
                self.startReceiving()
                self.receiveData(from: conn)
            case .failed(let error):
                print("Server connection failed: \(error)")
                self.connectionsQueue.async {
                    self.serverConnections.removeAll { $0 === conn }
                    self.activeConnection = self.serverConnections.first
                }
                // Do not alert error for listening part.
                DispatchQueue.main.async {
                    if self.isRunning == false {
                        self.connectionStatus = .disconnected
                    }
                }
            case .cancelled:
                self.connectionsQueue.async { [weak self] in
                    guard let self = self else { return }
                    self.serverConnections.removeAll { $0 === conn }
                    self.activeConnection = self.serverConnections.first

                    if self.serverConnections.isEmpty {
                        DispatchQueue.main.async {
                            if self.isRunning == false {
                                self.connectionStatus = .disconnected
                            }
                        }
                    }
                }
            default:
                break
            }
        }
        conn.start(queue: networkQueue)
    }

    func connect(ip: String, port: UInt16) {
        guard !isDisconnecting else { return }

        connectingTimer?.invalidate()
        connectingTimer = nil
        clientConnection?.cancel()
        clientConnection = nil

        isServerMode = false
        connectionStatus = .connecting
        pendingConnectionId = currentConnectingId

        let endpoint = NWEndpoint.hostPort(host: .init(ip), port: .init(rawValue: port)!)
        clientConnection = NWConnection(to: endpoint, using: .tcp)

        clientConnection?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.connectingTimer?.invalidate()
                self.connectingTimer = nil
                self.connectionsQueue.async {
                    self.activeConnection = self.clientConnection
                }
                DispatchQueue.main.async {
                    self.connectionStatus = .connected
                }
                self.startReceiving()
                self.receiveData(from: self.clientConnection)
            case .failed(let error):
                self.connectingTimer?.invalidate()
                self.connectingTimer = nil
                self.connectionsQueue.async {
                    self.activeConnection = nil
                }
                DispatchQueue.main.async {
                    self.connectionStatus = .error(String(localized: "network.connection.failed", defaultValue: "Connection failed: \(error.localizedDescription)"))
                }
            case .cancelled:
                self.connectingTimer?.invalidate()
                self.connectingTimer = nil
                self.connectionsQueue.async {
                    self.activeConnection = nil
                }
                DispatchQueue.main.async {
                    if self.isRunning == false && self.currentConnectingId == self.pendingConnectionId {
                        self.connectionStatus = .disconnected
                    }
                }
            case .waiting(let error):
                self.connectingTimer?.invalidate()
                self.connectingTimer = nil
                self.connectionsQueue.async {
                    self.activeConnection = nil
                }
                DispatchQueue.main.async {
                    self.connectionStatus = .error(String(localized: "network.connection.failed", defaultValue: "Connection waiting: \(error.localizedDescription)"))
                }
            case .preparing:
                self.startConnectingTimer()
            default:
                break
            }
        }

        clientConnection?.start(queue: networkQueue)
    }

    private func startConnectingTimer() {
        connectingTimer?.invalidate()
        currentConnectingId += 1
        let timerConnectingId = currentConnectingId
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.connectingTimer = Timer.scheduledTimer(withTimeInterval: self.connectingTimeout, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                if self.connectionStatus == .connecting && self.currentConnectingId == timerConnectingId && timerConnectingId == self.pendingConnectionId {
                    self.connectionStatus = .disconnected
                    self.clientConnection?.cancel()
                    self.clientConnection = nil
                }
            }
        }
    }

    func disconnect() {
        isDisconnecting = true
        clientConnection?.cancel()
        clientConnection = nil

        connectionsQueue.async { [weak self] in
            guard let self = self else { return }
            self.serverConnections.forEach { $0.cancel() }
            self.serverConnections.removeAll()
            self.activeConnection = nil
        }

        stopReceiving()
        stopAudioEngines()

        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
            self?.connectionStatus = .disconnected
            self?.audioLevel = 0
            self?.isDisconnecting = false
        }
    }

    func start() async throws {
        let granted = await AudioSessionConfig.requestMicrophonePermission()
        guard granted else {
            throw AudioError.microphonePermissionDenied
        }

        do {
            try AudioSessionConfig.configure(audioSession)
        } catch {
            throw AudioError.engineSetupFailed
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            receiverQueue.async {
                do {
                    try self.setupSenderEngine()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        startReceiving()

        DispatchQueue.main.async { [weak self] in
            self?.isRunning = true
            self?.connectionStatus = .transmitting
        }
    }

    func stop() {
        receiverQueue.async { [weak self] in
            self?.stopSenderEngine()

            DispatchQueue.main.async {
                self?.isRunning = false
                self?.audioLevel = 0
                self?.connectionStatus = .disconnected
            }
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

        remoteSampleRate = inputFormat.sampleRate
        let levelProcessor = self.levelProcessor

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self = self else { return }

            self.processAudioLevel(buffer, processor: levelProcessor)
            self.sendAudioBuffer(buffer)
        }

        senderEngine.prepare()
        try senderEngine.start()
    }

    private func stopSenderEngine() {
        senderEngine?.inputNode.removeTap(onBus: 0)
        senderEngine?.stop()
        senderEngine = nil
    }

    private func sendAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isRunning else { return }

        var connectionToSend: NWConnection?
        connectionsQueue.sync {
            connectionToSend = self.activeConnection
        }

        guard let connection = connectionToSend else { return }

        guard let channelData = buffer.floatChannelData else { return }
        let frameLength = Int(buffer.frameLength)
        let dataSize = frameLength * MemoryLayout<Float>.size
        let pcmData = Data(bytes: channelData[0], count: dataSize)

        let uptimeMs = UInt64(DispatchTime.now().uptimeNanoseconds / 1_000_000)
        let timestamp = UInt32(truncatingIfNeeded: uptimeMs)
        let sampleRate = UInt32(remoteSampleRate)
        let header = PacketHeader(type: .audio, timestamp: timestamp, payloadLength: UInt16(pcmData.count), sampleRate: sampleRate)

        var packet = header.toData()
        packet.append(pcmData)

        connection.send(content: packet, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
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

    private func receiveData(from connection: NWConnection?) {
        guard let connection = connection else { return }

        var isReceivingCopy: Bool = false
        connectionsQueue.sync {
            isReceivingCopy = self.isReceiving
        }
        guard isReceivingCopy else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self else { return }

            var isReceivingCopy: Bool = false
            var isDisconnectingCopy: Bool = false
            self.connectionsQueue.sync {
                isReceivingCopy = self.isReceiving
                isDisconnectingCopy = self.isDisconnecting
            }
            guard isReceivingCopy, !isDisconnectingCopy else { return }

            if let data = data {
                let packets = self.packetProcessor.processReceivedData(data)
                for packet in packets {
                    self.playAudioData(packet.payload, sampleRate: packet.sampleRate)
                }
            }

            if !isComplete && error == nil {
                self.networkQueue.async {
                    self.receiveData(from: connection)
                }
            }
        }

        if receiverEngine == nil {
            do {
                try AudioSessionConfig.configure(audioSession)
            } catch {
                Swift.print("[NetworkManager] Failed to configure audio session: \(error)")
            }
        }
    }

    private func playAudioData(_ data: Data, sampleRate: Double) {
        var isDisconnectingCopy: Bool = false
        connectionsQueue.sync {
            isDisconnectingCopy = self.isDisconnecting
        }
        guard !isDisconnectingCopy else { return }

        if receiverEngine == nil {
            receiverQueue.sync {
                if self.receiverEngine == nil {
                    self.setupReceiverEngine()
                }
            }
        }

        guard let playerNode = receiverPlayerNode,
              let engine = receiverEngine,
              engine.isRunning else { return }

        scheduleBuffer(data, sampleRate: sampleRate, playerNode: playerNode)
    }

    private func scheduleBuffer(_ data: Data, sampleRate: Double, playerNode: AVAudioPlayerNode) {
        var isDisconnectingCopy: Bool = false
        connectionsQueue.sync {
            isDisconnectingCopy = self.isDisconnecting
        }
        guard !isDisconnectingCopy else { return }

        guard playerNode.isPlaying else { return }

        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Float>.size)
        guard frameCount > 0 else { return }

        guard let engine = receiverEngine else { return }
        let pcmFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount

        data.withUnsafeBytes { rawBufferPointer in
            guard let baseAddress = rawBufferPointer.baseAddress else { return }
            memcpy(buffer.floatChannelData?[0], baseAddress, data.count)
        }

        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }

    private func setupReceiverEngine() {
        guard receiverEngine == nil else { return }

        do {
            try AudioSessionConfig.configure(audioSession)
        } catch {
            print("Failed to configure audio session for receiving: \(error)")
            return
        }

        receiverEngine = AVAudioEngine()
        guard let receiverEngine = receiverEngine else { return }

        let outputNode = receiverEngine.outputNode
        let mainMixer = receiverEngine.mainMixerNode

        receiverPlayerNode = AVAudioPlayerNode()
        guard let receiverPlayerNode = receiverPlayerNode else { return }
        receiverEngine.attach(receiverPlayerNode)

        receiverEngine.connect(receiverPlayerNode, to: mainMixer, format: nil)
        receiverEngine.connect(mainMixer, to: outputNode, format: nil)

        receiverEngine.prepare()
        do {
            try receiverEngine.start()
        } catch {
            print("Failed to start receiver engine: \(error)")
            self.receiverEngine = nil
            return
        }
        receiverPlayerNode.play()
    }

    private func startReceiving() {
        connectionsQueue.async { [weak self] in
            self?.isReceiving = true
        }
    }

    private func stopReceiving() {
        connectionsQueue.async { [weak self] in
            self?.isReceiving = false
        }
    }

    private func stopAudioEngines() {
        receiverQueue.sync { [weak self] in
            self?.stopSenderEngine()

            self?.receiverPlayerNode?.stop()
            self?.receiverEngine?.stop()
            self?.receiverEngine = nil
            self?.receiverPlayerNode = nil

            self?.packetProcessor.reset()
            self?.remoteSampleRate = 44100
            self?.isReceiving = false
        }
    }
}
