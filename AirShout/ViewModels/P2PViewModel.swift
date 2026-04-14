import Foundation
import Combine
import MultipeerConnectivity

@MainActor
final class P2PViewModel: ObservableObject {
    @Published var devices: [Device] = []
    @Published var isSpeaking: Bool = false
    @Published var audioLevel: Float = 0
    @Published var connectionStatus: P2PAudioManager.P2PConnectionStatus = .disconnected
    @Published var errorMessage: String?

    private let audioManager = P2PAudioManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        audioManager.$peers
            .receive(on: DispatchQueue.main)
            .map { peers in
                peers.map { peerID in
                    Device(
                        id: peerID,
                        displayName: peerID.displayName,
                        isConnected: true
                    )
                }
            }
            .assign(to: &$devices)

        audioManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        audioManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.connectionStatus = status
                if case .error(let message) = status {
                    self?.errorMessage = message
                } else {
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)

        audioManager.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isSpeaking)
    }

    func startSpeaking() {
        Task {
            do {
                errorMessage = nil
                try await audioManager.startSpeaking()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func stopSpeaking() {
        audioManager.stopSpeaking()
    }
}