import Foundation
import Combine

final class AirPlayViewModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isShouting: Bool = false
    @Published var isStarting: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private let audioManager: AirPlayAudioManager
    private var cancellables = Set<AnyCancellable>()
    
    init(audioManager: AirPlayAudioManager = .shared) {
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
    }
    
    func startShout() {
        guard !isStarting else { return }
        isStarting = true
        Task { @MainActor in
            do {
                try await audioManager.start()
            } catch AudioError.microphonePermissionDenied {
                showPermissionAlert = true
            } catch {
                print("Failed to start audio: \(error)")
                connectionStatus = .error(error.localizedDescription)
            }
            isStarting = false
        }
    }
    
    func stopShout() {
        audioManager.stop()
    }
}
