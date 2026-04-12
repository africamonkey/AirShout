import Foundation
import AVFAudio
import Combine

final class DeviceDiscoveryManager: ObservableObject {
    static let shared = DeviceDiscoveryManager()

    @Published var availableDevices: [Device] = []
    @Published var selectedDevice: Device?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        updateAvailableDevices()
    }

    private func setupRouteChangeObserver() {
        // Temporarily disabled to isolate UI freeze issue
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
