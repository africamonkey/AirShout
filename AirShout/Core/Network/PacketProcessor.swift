import Foundation

struct AudioPacket {
    let timestamp: UInt64
    let payload: Data
    let sampleRate: Double

    init(timestamp: UInt32, payload: Data, sampleRate: Double = 44100) {
        self.timestamp = UInt64(timestamp)
        self.payload = payload
        self.sampleRate = sampleRate
    }
}

struct PacketHeader {
    static let magic: UInt16 = 0x4148
    static let version: UInt8 = 0x02
    static let headerSize: Int = 14

    var type: PacketType
    var timestamp: UInt32
    var payloadLength: UInt16
    var sampleRate: UInt32

    func toData() -> Data {
        var data = Data()
        var magic = PacketHeader.magic.bigEndian
        var version = PacketHeader.version
        var typeRaw = type.rawValue
        var timestamp = self.timestamp.bigEndian
        var payloadLength = self.payloadLength.bigEndian
        var sampleRate = self.sampleRate.bigEndian

        data.append(Data(bytes: &magic, count: 2))
        data.append(Data(bytes: &version, count: 1))
        data.append(Data(bytes: &typeRaw, count: 1))
        data.append(Data(bytes: &timestamp, count: 4))
        data.append(Data(bytes: &payloadLength, count: 2))
        data.append(Data(bytes: &sampleRate, count: 4))
        return data
    }

    static func parse(from bytes: [UInt8]) -> PacketHeader? {
        guard bytes.count >= headerSize else { return nil }

        let magic = UInt16(bytes[0]) << 8 | UInt16(bytes[1])
        guard magic == PacketHeader.magic else { return nil }

        let version = bytes[2]
        guard version == PacketHeader.version else { return nil }

        let typeRaw = bytes[3]
        guard let type = PacketType(rawValue: typeRaw) else { return nil }

        let timestamp = UInt32(bytes[4]) << 24 | UInt32(bytes[5]) << 16 | UInt32(bytes[6]) << 8 | UInt32(bytes[7])
        let payloadLength = UInt16(bytes[8]) << 8 | UInt16(bytes[9])
        let sampleRate = UInt32(bytes[10]) << 24 | UInt32(bytes[11]) << 16 | UInt32(bytes[12]) << 8 | UInt32(bytes[13])

        return PacketHeader(type: type, timestamp: timestamp, payloadLength: payloadLength, sampleRate: sampleRate)
    }
}

enum PacketType: UInt8 {
    case audio = 0x01
    case control = 0x02
}

class PacketProcessor {
    private var recvBuffer = Data()
    private var expectedPayloadLength: UInt16 = 0
    private var currentTimestamp: UInt32 = 0
    private var currentSampleRate: Double = 44100

    enum ParseState {
        case waitingForHeader
        case waitingForPayload
    }
    private var state: ParseState = .waitingForHeader

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

                let headerBytes = [UInt8](recvBuffer.prefix(PacketHeader.headerSize))
                guard let header = PacketHeader.parse(from: headerBytes) else {
                    recvBuffer.removeFirst(1)
                    continue
                }

                currentTimestamp = header.timestamp
                currentSampleRate = Double(header.sampleRate)
                expectedPayloadLength = header.payloadLength
                recvBuffer.removeFirst(PacketHeader.headerSize)
                state = .waitingForPayload

            case .waitingForPayload:
                guard recvBuffer.count >= Int(expectedPayloadLength) else {
                    return packets
                }

                let payload = recvBuffer.prefix(Int(expectedPayloadLength))
                recvBuffer.removeFirst(Int(expectedPayloadLength))

                let packet = AudioPacket(timestamp: currentTimestamp, payload: Data(payload), sampleRate: currentSampleRate)
                packets.append(packet)

                state = .waitingForHeader
            }
        }
    }

    func reset() {
        lock.lock()
        defer { lock.unlock() }

        recvBuffer.removeAll()
        state = .waitingForHeader
        expectedPayloadLength = 0
        currentTimestamp = 0
    }
}
