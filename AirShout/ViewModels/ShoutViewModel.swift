import Foundation
import Combine

final class ShoutViewModel: ObservableObject {
    @Published var audioLevel: Float = 0
    @Published var isShouting: Bool = false
    @Published var availableDevices: [Device] = []
    @Published var selectedDevice: Device?

    private let audioManager = AudioManager.shared
    private let deviceManager = DeviceDiscoveryManager.shared
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

        deviceManager.$availableDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableDevices)

        deviceManager.$selectedDevice
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedDevice)
    }

    func startShout() {
        do {
            try audioManager.start()
        } catch {
            print("Failed to start audio: \(error)")
        }
    }

    func stopShout() {
        audioManager.stop()
    }

    func selectDevice(_ device: Device) {
        deviceManager.selectDevice(device)
    }

    func refreshDevices() {
        deviceManager.refreshDevices()
    }
}
