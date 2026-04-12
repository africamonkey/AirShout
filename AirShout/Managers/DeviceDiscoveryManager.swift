import Foundation
import AVFAudio
import Combine

final class DeviceDiscoveryManager: ObservableObject {
    static let shared = DeviceDiscoveryManager()

    @Published var availableDevices: [Device] = []
    @Published var selectedDevice: Device?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupRouteChangeObserver()
        updateAvailableDevices()
    }

    private func setupRouteChangeObserver() {
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAvailableDevices()
            }
            .store(in: &cancellables)
    }

    private func updateAvailableDevices() {
        let session = AVAudioSession.sharedInstance()
        let outputRoutes = session.currentRoute.outputs

        var devices: [Device] = []
        for output in outputRoutes {
            let device = Device(description: output)
            devices.append(device)
            if device.portType == .airPlay || device.portType == .builtInReceiver {
                selectedDevice = device
            }
        }

        if selectedDevice == nil, let first = devices.first {
            selectedDevice = first
        }

        availableDevices = devices
    }

    func selectDevice(_ device: Device) {
        selectedDevice = device
    }

    func refreshDevices() {
        updateAvailableDevices()
    }
}
