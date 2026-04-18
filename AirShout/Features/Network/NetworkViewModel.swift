import Foundation
import Combine
import Network

final class NetworkViewModel: ObservableObject {
    @Published var localIP: String = ""
    @Published var localPort: String = "8080"
    @Published var savedConnections: [SavedConnection] = []
    @Published var selectedConnection: SavedConnection?
    @Published var isListening: Bool = false
    @Published var isTransmitting: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var audioLevel: Float = 0
    @Published var showAddConnection: Bool = false
    @Published var errorMessage: String?

    private let networkManager = NetworkManager.shared
    private let storage = SavedConnectionStorage.shared
    private var cancellables = Set<AnyCancellable>()
    private var pendingStartTransmission: Bool = false

    init() {
        setupBindings()
        loadConnections()
        detectLocalIP()
    }

    private func setupBindings() {
        networkManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        networkManager.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isTransmitting)

        networkManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self = self else { return }
                self.connectionStatus = status

                if case .connected = status, self.pendingStartTransmission {
                    self.pendingStartTransmission = false
                    self.performStartTransmission()
                } else if case .error(let message) = status {
                    self.errorMessage = message
                    self.pendingStartTransmission = false
                }
            }
            .store(in: &cancellables)
    }

    private func loadConnections() {
        savedConnections = storage.load()
    }

    func detectLocalIP() {
        var address: String = "无法获取"
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&ifaddr) == 0 else { return }
        guard let firstAddr = ifaddr else { return }

        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            let addrFamily = interface.ifa_addr.pointee.sa_family

            if addrFamily == UInt8(AF_INET) {
                let name = String(cString: interface.ifa_name)
                if name == "en0" || name == "pdp_ip0" {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)

        localIP = address
    }

    func startListening() {
        guard let port = UInt16(localPort) else {
            errorMessage = "无效的端口号"
            return
        }

        do {
            try networkManager.startListening(port: port)
            isListening = true
            errorMessage = nil
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopListening() {
        networkManager.stopListening()
        isListening = false
    }

    func addConnection(name: String, ip: String, port: String) {
        guard let portNum = UInt16(port), !name.isEmpty, !ip.isEmpty else {
            errorMessage = "请填写完整信息"
            return
        }

        let connection = SavedConnection(name: name, ip: ip, port: portNum)
        storage.add(connection)
        savedConnections = storage.load()
        showAddConnection = false
    }

    func removeConnection(at offsets: IndexSet) {
        for index in offsets {
            storage.remove(at: index)
        }
        savedConnections = storage.load()
    }

    func selectConnection(_ connection: SavedConnection) {
        selectedConnection = connection
    }

    func connect() {
        guard let connection = selectedConnection else {
            errorMessage = "请先选择一个连接"
            return
        }

        networkManager.connect(ip: connection.ip, port: connection.port)

        var updated = connection
        updated.lastConnected = Date()
        storage.update(updated)
        savedConnections = storage.load()
    }

    func disconnect() {
        networkManager.disconnect()
        selectedConnection = nil
    }

    func startTransmission() {
        switch connectionStatus {
        case .disconnected, .error:
            if selectedConnection != nil {
                pendingStartTransmission = true
                connect()
            } else {
                errorMessage = "请先选择一个连接"
            }
        case .connecting:
            pendingStartTransmission = true
        case .connected:
            performStartTransmission()
        case .transmitting:
            break
        }
    }

    private func performStartTransmission() {
        Task { @MainActor in
            do {
                try await networkManager.start()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopTransmission() {
        networkManager.disconnect()
    }
}