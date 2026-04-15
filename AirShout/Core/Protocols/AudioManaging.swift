import Foundation
import Combine

protocol AudioManaging: ObservableObject {
    var audioLevel: Float { get }
    var isRunning: Bool { get }
    var connectionStatus: ConnectionStatus { get }
    
    func start() async throws
    func stop()
}