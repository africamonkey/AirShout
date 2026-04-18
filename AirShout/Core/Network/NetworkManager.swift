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
            return "端口已被占用，请更换端口"
        case .connectionFailed(let reason):
            return "连接失败: \(reason)"
        case .notConnected:
            return "未连接到任何设备"
        case .engineSetupFailed:
            return "音频引擎设置失败"
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
    private var localPort: UInt16 = 8080

    private var isServerMode: Bool = false

    private var senderEngine: AVAudioEngine?
    private var receiverEngine: AVAudioEngine?
    private var receiverPlayerNode: AVAudioPlayerNode?
    private let audioEngineQueue = DispatchQueue(label: "com.airshout.network.audioengine")

    private let jitterBuffer = JitterBuffer()
    private let packetProcessor = PacketProcessor()
    private let levelProcessor = AudioLevelProcessor()

    private var sendBuffer: AVAudioPCMBuffer?
    private var sendBufferFormat: AVAudioFormat?
    private var accumulatedFrames: AVAudioFrameCount = 0
    private let targetSendDurationMs: Double = 50
    private var remoteSampleRate: Double = 44100

    private let networkQueue = DispatchQueue(label: "com.airshout.network")
    private let audioSession = AVAudioSession.sharedInstance()

    private var playbackTimer: Timer?
    private let connectionsQueue = DispatchQueue(label: "com.airshout.network.connections")
    private var activeConnection: NWConnection?

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
            switch state {
            case .ready:
                print("TCP Listener ready on port \(port)")
            case .failed(let error):
                print("TCP Listener failed: \(error)")
                DispatchQueue.main.async {
                    self?.connectionStatus = .error("监听失败: \(error.localizedDescription)")
                }
            case .cancelled:
                print("TCP Listener cancelled")
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
        serverConnections.forEach { $0.cancel() }
        serverConnections.removeAll()
    }

    private func handleIncomingConnection(_ conn: NWConnection) {
        connectionsQueue.async { [weak self] in
            guard let self = self else { return }
            self.serverConnections.append(conn)
            self.activeConnection = conn
        }

        conn.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Server connection ready")
                DispatchQueue.main.async {
                    self?.connectionStatus = .connected
                }
                self?.receiveData(from: conn)
            case .failed(let error):
                print("Server connection failed: \(error)")
                self?.connectionsQueue.async {
                    self?.serverConnections.removeAll { $0 === conn }
                    self?.activeConnection = self?.serverConnections.first
                }
                DispatchQueue.main.async {
                    self?.connectionStatus = .error("连接失败: \(error.localizedDescription)")
                }
            case .cancelled:
                self?.connectionsQueue.async {
                    self?.serverConnections.removeAll { $0 === conn }
                    self?.activeConnection = self?.serverConnections.first
                }
                if self?.serverConnections.isEmpty == true {
                    DispatchQueue.main.async {
                        if self?.isRunning == false {
                            self?.connectionStatus = .disconnected
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
        connectionStatus = .connecting
        isServerMode = false

        clientConnection?.cancel()
        clientConnection = nil

        let endpoint = NWEndpoint.hostPort(host: .init(ip), port: .init(rawValue: port)!)
        clientConnection = NWConnection(to: endpoint, using: .tcp)

        clientConnection?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                print("Client connected to \(ip):\(port)")
                self?.connectionsQueue.async {
                    self?.activeConnection = self?.clientConnection
                }
                DispatchQueue.main.async {
                    self?.connectionStatus = .connected
                }
                self?.receiveData(from: self?.clientConnection)
            case .failed(let error):
                print("Client connection failed: \(error)")
                self?.connectionsQueue.async {
                    self?.activeConnection = nil
                }
                DispatchQueue.main.async {
                    self?.connectionStatus = .error("连接失败: \(error.localizedDescription)")
                }
            case .cancelled:
                print("Client connection cancelled")
                self?.connectionsQueue.async {
                    self?.activeConnection = nil
                }
                DispatchQueue.main.async {
                    if self?.isRunning == false {
                        self?.connectionStatus = .disconnected
                    }
                }
            default:
                break
            }
        }

        clientConnection?.start(queue: networkQueue)
    }

    func disconnect() {
        clientConnection?.cancel()
        clientConnection = nil
        serverConnections.forEach { $0.cancel() }
        serverConnections.removeAll()

        connectionsQueue.async { [weak self] in
            self?.activeConnection = nil
        }

        stopAudioEngines()
        stopPlaybackTimer()

        DispatchQueue.main.async { [weak self] in
            self?.connectionStatus = .disconnected
            self?.audioLevel = 0
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
            audioEngineQueue.async {
                do {
                    try self.setupSenderEngine()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }

        startPlaybackTimer()

        DispatchQueue.main.async { [weak self] in
            self?.isRunning = true
            self?.connectionStatus = .connected
        }
    }

    func stop() {
        audioEngineQueue.async { [weak self] in
            self?.stopSenderEngine()
            self?.stopPlaybackTimer()

            DispatchQueue.main.async {
                self?.isRunning = false
                self?.audioLevel = 0
                if self?.clientConnection == nil && self?.serverConnections.isEmpty == true {
                    self?.connectionStatus = .disconnected
                }
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

        sendBufferFormat = inputFormat
        remoteSampleRate = inputFormat.sampleRate
        accumulatedFrames = 0

        let targetFrames = AVAudioFrameCount(inputFormat.sampleRate * targetSendDurationMs / 1000.0)
        sendBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: targetFrames)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.handleAudioBuffer(buffer)
        }

        senderEngine.prepare()
        try senderEngine.start()
    }

    private func stopSenderEngine() {
        senderEngine?.inputNode.removeTap(onBus: 0)
        senderEngine?.stop()
        senderEngine = nil
        sendBuffer = nil
        accumulatedFrames = 0
    }

    private func handleAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let sendBuffer = sendBuffer, let _ = sendBufferFormat else { return }
        guard let inputChannelData = buffer.floatChannelData else { return }
        guard let outputChannelData = sendBuffer.floatChannelData else { return }

        let framesToCopy = min(buffer.frameLength, sendBuffer.frameCapacity - accumulatedFrames)
        guard framesToCopy > 0 else {
            flushSendBuffer()
            return
        }

        memcpy(outputChannelData[0].advanced(by: Int(accumulatedFrames)),
               inputChannelData[0],
               Int(framesToCopy) * MemoryLayout<Float>.size)
        accumulatedFrames += framesToCopy

        processAudioLevel(buffer)

        if accumulatedFrames >= sendBuffer.frameCapacity {
            flushSendBuffer()
        }
    }

    private func flushSendBuffer() {
        guard accumulatedFrames > 0, let sendBuffer = sendBuffer else { return }

        var connectionToSend: NWConnection?
        connectionsQueue.sync {
            connectionToSend = self.activeConnection
        }

        guard let connection = connectionToSend else { return }

        sendBuffer.frameLength = accumulatedFrames

        let packet = createPacket(from: sendBuffer)
        send(data: packet, to: connection)

        accumulatedFrames = 0
    }

    private func processAudioLevel(_ buffer: AVAudioPCMBuffer) {
        let now = Date().timeIntervalSinceReferenceDate
        guard levelProcessor.shouldUpdate(now: now) else { return }

        guard let level = levelProcessor.calculateLevel(from: buffer) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = level
            if level > 0.01 {
                self?.connectionStatus = .transmitting
            }
        }
    }

    private func createPacket(from buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData else { return Data() }

        let frameLength = Int(buffer.frameLength)
        let dataSize = frameLength * MemoryLayout<Float>.size
        let pcmData = Data(bytes: channelData[0], count: dataSize)

        let timestamp = UInt32(Date().timeIntervalSince1970 * 1000)
        let header = PacketHeader(type: .audio, timestamp: timestamp, payloadLength: UInt16(pcmData.count))

        var packet = header.toData()
        packet.append(pcmData)
        return packet
    }

    private func send(data: Data, to connection: NWConnection) {
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
            }
        })
    }

    private func receiveData(from connection: NWConnection?) {
        guard let connection = connection else { return }

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data {
                let packets = self?.packetProcessor.processReceivedData(data) ?? []
                for packet in packets {
                    self?.jitterBuffer.insert(packet)
                }
            }

            if !isComplete && error == nil {
                self?.receiveData(from: connection)
            }
        }
    }

    private func startPlaybackTimer() {
        stopPlaybackTimer()

        DispatchQueue.main.async { [weak self] in
            self?.playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
                self?.checkPlayback()
            }
        }
    }

    private func stopPlaybackTimer() {
        DispatchQueue.main.async { [weak self] in
            self?.playbackTimer?.invalidate()
            self?.playbackTimer = nil
        }
    }

    private func checkPlayback() {
        guard isRunning else { return }

        let currentTimeMs = UInt32(Date().timeIntervalSince1970 * 1000)

        if let packet = jitterBuffer.popIfReady(currentTimeMs: currentTimeMs) {
            playAudioData(packet.payload)
        }

        jitterBuffer.cleanup()
    }

    private func setupReceiverEngineIfNeeded() {
        guard receiverEngine == nil else { return }

        receiverEngine = AVAudioEngine()
        guard let receiverEngine = receiverEngine else { return }

        let outputNode = receiverEngine.outputNode
        let mainMixer = receiverEngine.mainMixerNode

        receiverPlayerNode = AVAudioPlayerNode()
        guard let receiverPlayerNode = receiverPlayerNode else { return }

        receiverEngine.attach(receiverPlayerNode)

        let pcmFormat = AVAudioFormat(standardFormatWithSampleRate: remoteSampleRate, channels: 1)!
        let outputFormat = outputNode.inputFormat(forBus: 0)

        receiverEngine.connect(receiverPlayerNode, to: mainMixer, format: pcmFormat)
        receiverEngine.connect(mainMixer, to: outputNode, format: outputFormat)

        receiverEngine.prepare()

        do {
            try receiverEngine.start()
            receiverPlayerNode.play()
        } catch {
            print("Failed to start receiver engine: \(error)")
            self.receiverEngine = nil
        }
    }

    private func playAudioData(_ data: Data) {
        audioEngineQueue.async { [weak self] in
            guard let self = self else { return }

            self.setupReceiverEngineIfNeeded()

            guard self.receiverEngine != nil,
                  let receiverPlayerNode = self.receiverPlayerNode else { return }

            let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Float>.size)
            guard frameCount > 0 else { return }

            let pcmFormat = AVAudioFormat(standardFormatWithSampleRate: self.remoteSampleRate, channels: 1)!
            guard let buffer = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: frameCount) else { return }

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

    private func stopAudioEngines() {
        audioEngineQueue.async { [weak self] in
            self?.stopSenderEngine()

            self?.receiverPlayerNode?.stop()
            self?.receiverEngine?.stop()
            self?.receiverEngine = nil
            self?.receiverPlayerNode = nil

            self?.jitterBuffer.clear()
            self?.packetProcessor.reset()
            self?.remoteSampleRate = 44100
        }
    }
}