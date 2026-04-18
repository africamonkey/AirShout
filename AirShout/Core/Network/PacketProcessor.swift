import Foundation

struct AudioPacket {
    let timestamp: UInt64
    let payload: Data

    init(timestamp: UInt32, payload: Data) {
        self.timestamp = UInt64(timestamp)
        self.payload = payload
    }
}

struct PacketHeader {
    static let magic: UInt16 = 0x4148
    static let version: UInt8 = 0x01
    static let headerSize = 10

    var type: PacketType
    var timestamp: UInt32
    var payloadLength: UInt16

    func toData() -> Data {
        var data = Data()
        var magic = PacketHeader.magic.bigEndian
        var version = PacketHeader.version
        var typeRaw = type.rawValue
        var timestamp = self.timestamp.bigEndian
        var payloadLength = self.payloadLength.bigEndian

        data.append(Data(bytes: &magic, count: 2))
        data.append(Data(bytes: &version, count: 1))
        data.append(Data(bytes: &typeRaw, count: 1))
        data.append(Data(bytes: &timestamp, count: 4))
        data.append(Data(bytes: &payloadLength, count: 2))
        return data
    }

    static func parse(from data: Data) -> (PacketHeader?, Int)? {
        guard data.count >= 10 else { return nil }

        var result: (PacketHeader?, Int)?
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }

            let magic = baseAddress.load(as: UInt16.self).bigEndian
            guard magic == PacketHeader.magic else { return }

            let version = baseAddress.load(fromByteOffset: 2, as: UInt8.self)
            guard version == PacketHeader.version else { return }

            let typeRaw = baseAddress.load(fromByteOffset: 3, as: UInt8.self)
            guard let type = PacketType(rawValue: typeRaw) else { return }

            let timestamp = baseAddress.load(fromByteOffset: 4, as: UInt32.self).bigEndian
            let payloadLength = baseAddress.load(fromByteOffset: 8, as: UInt16.self).bigEndian

            let header = PacketHeader(type: type, timestamp: timestamp, payloadLength: payloadLength)
            result = (header, headerSize)
        }
        return result
    }
}

enum PacketType: UInt8 {
    case audio = 0x01
    case control = 0x02
}

enum ControlSubtype: UInt8 {
    case ping = 0x01
    case pong = 0x02
    case disconnect = 0x03
}

class PacketProcessor {
    enum State {
        case waitingForHeader
        case waitingForPayload(length: UInt16)
    }

    var state: State = .waitingForHeader
    var recvBuffer = Data()
    var currentHeader: PacketHeader?

    private let lock = NSLock()

    func processReceivedData(_ newData: Data) -> [AudioPacket] {
        lock.lock()
        defer { lock.unlock() }

        var packets: [AudioPacket] = []
        recvBuffer.append(newData)

        while true {
            switch state {
            case .waitingForHeader:
                guard recvBuffer.count >= PacketHeader.headerSize else {
                    return packets
                }

                if let result = PacketHeader.parse(from: recvBuffer), let header = result.0 {
                    currentHeader = header
                    recvBuffer.removeFirst(result.1)
                    state = .waitingForPayload(length: header.payloadLength)
                } else {
                    if let syncIndex = findNextMagic(in: recvBuffer), syncIndex > 0 {
                        recvBuffer.removeFirst(syncIndex)
                        continue
                    }
                    if let firstByte = recvBuffer.first, firstByte == PacketHeader.magic >> 8 {
                        recvBuffer.removeFirst(1)
                        continue
                    }
                    return packets
                }

            case .waitingForPayload(let length):
                guard recvBuffer.count >= Int(length) else {
                    return packets
                }

                let payload = recvBuffer.prefix(Int(length))
                recvBuffer.removeFirst(Int(length))

                if let header = currentHeader {
                    packets.append(AudioPacket(timestamp: header.timestamp, payload: Data(payload)))
                }

                currentHeader = nil
                state = .waitingForHeader
            }
        }
    }

    private func findNextMagic(in data: Data) -> Int? {
        guard data.count >= 2 else { return nil }

        var result: Int?
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            for i in 0..<(data.count - 1) {
                let magic = baseAddress.load(fromByteOffset: i, as: UInt16.self).bigEndian
                if magic == PacketHeader.magic {
                    result = i
                    return
                }
            }
        }
        return result
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }

        state = .waitingForHeader
        recvBuffer.removeAll()
        currentHeader = nil
    }
}