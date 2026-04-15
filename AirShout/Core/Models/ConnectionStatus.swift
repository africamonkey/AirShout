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
            return "麦克风权限被拒绝"
        case .engineSetupFailed:
            return "音频引擎设置失败"
        case .noInputAvailable:
            return "没有可用的输入设备，请确保已选择音频输出设备"
        }
    }
}