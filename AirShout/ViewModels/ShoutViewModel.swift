import Foundation
import Combine

final class ShoutViewModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isShouting: Bool = false
    @Published var showPermissionAlert: Bool = false

    private let audioManager = AudioManager.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        audioManager.$audioLevel
            .receive(on: DispatchQueue.main)
            .assign(to: &$audioLevel)

        audioManager.$isRunning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isShouting)
    }

    func startShout() {
        Task { @MainActor in
            do {
                try await audioManager.start()
            } catch AudioManager.AudioError.microphonePermissionDenied {
                showPermissionAlert = true
            } catch {
                print("Failed to start audio: \(error)")
            }
        }
    }

    func stopShout() {
        audioManager.stop()
    }
}
