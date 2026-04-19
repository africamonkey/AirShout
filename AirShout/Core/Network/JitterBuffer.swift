import Foundation

class JitterBuffer {
    var packets: [AudioPacket] = []
    var targetDelayMs: Int = 100

    private let lock = NSLock()
    private var totalDropped = 0

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

        if packets.count > 50 {
            totalDropped += packets.count - 50
            packets.removeFirst(packets.count - 50)
            print("[JitterBuffer] WARNING: Bulk dropped to 50, total dropped=\(totalDropped)")
            return packets.first
        }

        packets.removeFirst()
        return oldest
    }

    func cleanup(maxCount: Int = 100) {
        lock.lock()
        defer { lock.unlock() }

        if packets.count > maxCount {
            let removed = packets.count - maxCount
            totalDropped += removed
            packets.removeFirst(removed)
            print("[JitterBuffer] Cleanup removed \(removed) packets, total dropped=\(totalDropped)")
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