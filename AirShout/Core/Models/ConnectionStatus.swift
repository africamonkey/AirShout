import Foundation

enum ConnectionStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case transmitting
    case error(String)
    
    var isTransmitting: Bool {
        if case .transmitting = self { return true }
        return false
    }
}

enum AudioError: Error, LocalizedError {
    case microphonePermissionDenied
    case engineSetupFailed
    case noInputAvailable
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return String(localized: "audio.error.microphone.permission.denied", defaultValue: "Microphone permission denied")
        case .engineSetupFailed:
            return String(localized: "audio.error.engine.setup.failed", defaultValue: "Audio engine setup failed")
        case .noInputAvailable:
            return String(localized: "audio.error.no.input.available", defaultValue: "No input device available. Please ensure an audio output device is selected.")
        }
    }
}