import Foundation
import Combine

final class ShoutViewModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isShouting: Bool = false

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
        Task {
            do {
                try await audioManager.start()
            } catch {
                print("Failed to start audio: \(error)")
            }
        }
    }

    func stopShout() {
        audioManager.stop()
    }
}
