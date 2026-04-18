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

        let magic = UInt16(data[0]) << 8 | UInt16(data[1])
        guard magic == PacketHeader.magic else { return nil }

        let version = data[2]
        guard version == PacketHeader.version else { return nil }

        let typeRaw = data[3]
        guard let type = PacketType(rawValue: typeRaw) else { return nil }

        let timestamp = UInt32(data[4]) << 24 | UInt32(data[5]) << 16 | UInt32(data[6]) << 8 | UInt32(data[7])
        let payloadLength = UInt16(data[8]) << 8 | UInt16(data[9])

        let header = PacketHeader(type: type, timestamp: timestamp, payloadLength: payloadLength)
        return (header, headerSize)
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

        for i in 0..<(data.count - 1) {
            let magic = UInt16(data[i]) << 8 | UInt16(data[i + 1])
            if magic == PacketHeader.magic {
                return i
            }
        }
        return nil
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }

        state = .waitingForHeader
        recvBuffer.removeAll()
        currentHeader = nil
    }
}