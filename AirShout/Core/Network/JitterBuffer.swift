import Foundation

class JitterBuffer {
    var packets: [AudioPacket] = []
    var targetDelayMs: Int = 100

    private let lock = NSLock()

    func insert(_ packet: AudioPacket) {
        lock.lock()
        defer { lock.unlock() }

        let insertIndex = packets.firstIndex { $0.timestamp > packet.timestamp }
            ?? packets.endIndex
        packets.insert(packet, at: insertIndex)
    }

    func popIfReady(currentTimeMs: UInt64) -> AudioPacket? {
        lock.lock()
        defer { lock.unlock() }

        guard let oldest = packets.first else { return nil }

        let playbackTime = oldest.timestamp + UInt64(targetDelayMs)

        if currentTimeMs >= playbackTime {
            packets.removeFirst()
            return oldest
        }
        return nil
    }

    func cleanup(maxCount: Int = 100) {
        lock.lock()
        defer { lock.unlock() }

        if packets.count > maxCount {
            packets.removeFirst(packets.count - maxCount)
        }
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return packets.count
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        packets.removeAll()
    }
}