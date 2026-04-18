import Foundation

struct AudioPacket {
    let timestamp: UInt32
    let payload: Data
}

struct PacketHeader {
    static let magic: UInt16 = 0x4148
    static let version: UInt8 = 0x01
    static let headerSize = 7

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
        guard data.count >= headerSize else { return nil }

        let magic = data.prefix(2).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }
        guard magic == PacketHeader.magic else { return nil }

        let version = data[2]
        guard version == PacketHeader.version else { return nil }

        let typeRaw = data[3]
        guard let type = PacketType(rawValue: typeRaw) else { return nil }

        let timestamp = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
        let payloadLength = data.subdata(in: 8..<10).withUnsafeBytes { $0.load(as: UInt16.self).bigEndian }

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
                guard let result = PacketHeader.parse(from: recvBuffer) else {
                    if let syncIndex = findNextMagic(in: recvBuffer) {
                        recvBuffer.removeFirst(syncIndex)
                        continue
                    }
                    return packets
                }

                let header = result.0
                let headerEndIndex = result.1
                guard let unwrappedHeader = header else {
                    if let syncIndex = findNextMagic(in: recvBuffer) {
                        recvBuffer.removeFirst(syncIndex)
                    }
                    return packets
                }

                currentHeader = unwrappedHeader
                recvBuffer.removeFirst(headerEndIndex)
                state = .waitingForPayload(length: unwrappedHeader.payloadLength)

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
            let magic = data.subdata(in: i..<(i + 2)).withUnsafeBytes {
                $0.load(as: UInt16.self).bigEndian
            }
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