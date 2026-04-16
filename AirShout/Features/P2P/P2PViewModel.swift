import Foundation
import Combine

final class P2PViewModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isShouting: Bool = false
    @Published var connectionState: P2PAudioManager.P2PConnectionState = .disconnected
    @Published var devices: [PeerInfo] = []
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
        
        audioManager.$connectionState
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectionState)
        
        audioManager.$discoveredPeers
            .receive(on: DispatchQueue.main)
            .assign(to: &$devices)
    }
    
    func startShout() {
        audioManager.startSpeaking()
    }
    
    func stopShout() {
        audioManager.stopSpeaking()
    }
    
    func restartDiscovery() {
        audioManager.startDiscovery()
    }
}
