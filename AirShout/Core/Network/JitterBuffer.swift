import Foundation

class JitterBuffer {
    var packets: [AudioPacket] = []
    var targetDelayMs: Int = 100

    private let lock = NSLock()

    func insert(_ packet: AudioPacket) {
        lock.lock()
        defer { lock.unlock() }

        print("[JitterBuffer] Inserting packet timestamp=\(packet.timestamp), payload=\(packet.payload.count), bufferCount=\(packets.count)")
        let insertIndex = packets.firstIndex { $0.timestamp > packet.timestamp }
            ?? packets.endIndex
        packets.insert(packet, at: insertIndex)
        print("[JitterBuffer] After insert, bufferCount=\(packets.count)")
    }

    func popIfReady(currentTimeMs: UInt64) -> AudioPacket? {
        lock.lock()
        defer { lock.unlock() }

        guard let oldest = packets.first else { return nil }

        if packets.count > 20 {
            packets.removeFirst()
            return oldest
        }

        let playbackTime = oldest.timestamp + UInt64(targetDelayMs)
        if currentTimeMs >= playbackTime || packets.count > 5 {
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

    var isEmpty: Bool {
        lock.lock()
        defer { lock.unlock() }
        return packets.isEmpty
    }

    func clear() {
        lock.lock()
        defer { lock.unlock() }
        packets.removeAll()
    }
}