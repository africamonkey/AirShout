import Foundation
import Combine

final class P2PViewModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isShouting: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var devices: [P2PDevice] = []
    @Published var showPermissionAlert: Bool = false
    
    private let audioManager: P2PAudioManager
    private var cancellables = Set<AnyCancellable>()
    
    init(audioManager: P2PAudioManager = .shared) {
        self.audioManager = audioManager
        setupBindings()
    }
    
    private func setupBindings() {
        audioManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)
        
        audioManager.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isShouting)
        
        audioManager.$connectionStatus
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionStatus)
        
        audioManager.$peers
            .receive(on: DispatchQueue.main)
            .map { peers in
                peers.map { peerID in
                    P2PDevice(
                        id: peerID,
                        displayName: peerID.displayName,
                        isConnected: true
                    )
                }
            }
            .assign(to: &$devices)
    }
    
    func startShout() {
        Task { @MainActor in
            do {
                try await audioManager.start()
            } catch AudioError.microphonePermissionDenied {
                showPermissionAlert = true
            } catch {
                print("Failed to start audio: \(error)")
            }
        }
    }
    
    func stopShout() {
        audioManager.stop()
    }
    
    func restartDiscovery() {
        audioManager.restartBrowsing()
    }
}
