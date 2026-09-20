import Foundation

/// A small, dependency-free DEFLATE (RFC 1951) decoder, used to read EPUB
/// files, which are ZIP archives. Pure Swift so it behaves the same on every
/// platform and is covered by unit tests.
///
/// Follows the structure of zlib's reference decoder "puff": canonical
/// Huffman codes decoded one bit at a time. That is plenty fast for books.
enum Inflate {
    enum Failure: Error, Equatable {
        case truncated
        case invalidBlockType
        case invalidStoredLength
        case invalidCode
        case invalidDistance
        case tooLarge
    }

    /// Decompresses raw DEFLATE data (no zlib or gzip header).
    /// `limit` guards against archive bombs.
    static func decompress(_ input: [UInt8], limit: Int = 64 * 1024 * 1024) throws -> [UInt8] {
        var state = State(input: input, limit: limit)
        var isLast = false
        repeat {
            isLast = try state.bits(1) == 1
            switch try state.bits(2) {
            case 0: try state.stored()
            case 1: try state.codes(literal: Fixed.literal, distance: Fixed.distance)
            case 2: try state.dynamic()
            default: throw Failure.invalidBlockType
            }
        } while !isLast
        return state.output
    }

    // MARK: Tables

    private static let lengthBase: [Int] = [3, 4, 5, 6, 7, 8, 9, 10, 11, 13, 15, 17, 19, 23, 27, 31,
                                            35, 43, 51, 59, 67, 83, 99, 115, 131, 163, 195, 227, 258]
    private static let lengthExtra: [Int] = [0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2,
                                             3, 3, 3, 3, 4, 4, 4, 4, 5, 5, 5, 5, 0]
    private static let distanceBase: [Int] = [1, 2, 3, 4, 5, 7, 9, 13, 17, 25, 33, 49, 65, 97, 129, 193,
                                              257, 385, 513, 769, 1025, 1537, 2049, 3073, 4097, 6145,
                                              8193, 12289, 16385, 24577]
    private static let distanceExtra: [Int] = [0, 0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
                                               7, 7, 8, 8, 9, 9, 10, 10, 11, 11, 12, 12, 13, 13]
    private static let codeLengthOrder: [Int] = [16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15]

    private enum Fixed {
        static let literal: Huffman = {
            var lengths = [Int](repeating: 8, count: 288)
            for symbol in 144..<256 { lengths[symbol] = 9 }
            for symbol in 256..<280 { lengths[symbol] = 7 }
            return Huffman(lengths: lengths)
        }()
        static let distance = Huffman(lengths: [Int](repeating: 5, count: 30))
    }

    /// Canonical Huffman code: how many codes of each length, and the symbols
    /// ordered by code.
    struct Huffman {
        var counts = [Int](repeating: 0, count: 16)
        var symbols: [Int]

        init(lengths: [Int]) {
            symbols = [Int](repeating: 0, count: lengths.count)
            for length in lengths where length > 0 && length < 16 { counts[length] += 1 }
            var offsets = [Int](repeating: 0, count: 16)
            for length in 1..<15 { offsets[length + 1] = offsets[length] + counts[length] }
            for (symbol, length) in lengths.enumerated() where length > 0 && length < 16 {
                symbols[offsets[length]] = symbol
                offsets[length] += 1
            }
        }
    }

    // MARK: Decoder state

    private struct State {
        let input: [UInt8]
        let limit: Int
        var position = 0
        var bitBuffer = 0
        var bitCount = 0
        var output: [UInt8] = []

        init(input: [UInt8], limit: Int) {
            self.input = input
            self.limit = limit
            output.reserveCapacity(min(limit, input.count * 4))
        }

        mutating func bits(_ need: Int) throws -> Int {
            var value = bitBuffer
            while bitCount < need {
                guard position < input.count else { throw Failure.truncated }
                value |= Int(input[position]) << bitCount
                position += 1
                bitCount += 8
            }
            bitBuffer = value >> need
            bitCount -= need
            return value & ((1 << need) - 1)
        }

        mutating func stored() throws {
            // Stored blocks start on a byte boundary.
            bitBuffer = 0
            bitCount = 0
            guard position + 4 <= input.count else { throw Failure.truncated }
            let length = Int(input[position]) | Int(input[position + 1]) << 8
            let complement = Int(input[position + 2]) | Int(input[position + 3]) << 8
            position += 4
            guard length == (~complement & 0xFFFF) else { throw Failure.invalidStoredLength }
            guard position + length <= input.count else { throw Failure.truncated }
            guard output.count + length <= limit else { throw Failure.tooLarge }
            output.append(contentsOf: input[position..<(position + length)])
            position += length
        }

        mutating func decode(_ huffman: Huffman) throws -> Int {
            var code = 0
            var first = 0
            var index = 0
            for length in 1..<16 {
                code |= try bits(1)
                let count = huffman.counts[length]
                if code - count < first {
                    return huffman.symbols[index + (code - first)]
                }
                index += count
                first += count
                first <<= 1
                code <<= 1
            }
            throw Failure.invalidCode
        }

        mutating func codes(literal: Huffman, distance: Huffman) throws {
            while true {
                let symbol = try decode(literal)
                if symbol < 256 {
                    guard output.count < limit else { throw Failure.tooLarge }
                    output.append(UInt8(symbol))
                } else if symbol == 256 {
                    return
                } else {
                    let lengthIndex = symbol - 257
                    guard lengthIndex < Inflate.lengthBase.count else { throw Failure.invalidCode }
                    let length = Inflate.lengthBase[lengthIndex] + (try bits(Inflate.lengthExtra[lengthIndex]))
                    let distanceSymbol = try decode(distance)
                    guard distanceSymbol < Inflate.distanceBase.count else { throw Failure.invalidDistance }
                    let back = Inflate.distanceBase[distanceSymbol] + (try bits(Inflate.distanceExtra[distanceSymbol]))
                    guard back <= output.count else { throw Failure.invalidDistance }
                    guard output.count + length <= limit else { throw Failure.tooLarge }
                    let start = output.count - back
                    // Byte by byte: the copy may overlap what it's writing.
                    for offset in 0..<length {
                        output.append(output[start + offset])
                    }
                }
            }
        }

        mutating func dynamic() throws {
            let literalCount = try bits(5) + 257
            let distanceCount = try bits(5) + 1
            let codeLengthCount = try bits(4) + 4
            guard literalCount <= 286, distanceCount <= 30 else { throw Failure.invalidCode }

            var codeLengths = [Int](repeating: 0, count: 19)
            for index in 0..<codeLengthCount {
                codeLengths[Inflate.codeLengthOrder[index]] = try bits(3)
            }
            let lengthCode = Huffman(lengths: codeLengths)

            var lengths = [Int]()
            lengths.reserveCapacity(literalCount + distanceCount)
            while lengths.count < literalCount + distanceCount {
                let symbol = try decode(lengthCode)
                switch symbol {
                case 0..<16:
                    lengths.append(symbol)
                case 16:
                    guard let previous = lengths.last else { throw Failure.invalidCode }
                    lengths.append(contentsOf: repeatElement(previous, count: 3 + (try bits(2))))
                case 17:
                    lengths.append(contentsOf: repeatElement(0, count: 3 + (try bits(3))))
                case 18:
                    lengths.append(contentsOf: repeatElement(0, count: 11 + (try bits(7))))
                default:
                    throw Failure.invalidCode
                }
            }
            guard lengths.count == literalCount + distanceCount, lengths[256] != 0 else { throw Failure.invalidCode }
            let literal = Huffman(lengths: Array(lengths[0..<literalCount]))
            let distance = Huffman(lengths: Array(lengths[literalCount...]))
            try codes(literal: literal, distance: distance)
        }
    }
}

/// Reads files out of a ZIP archive held in memory (enough for EPUBs).
/// Supports stored and deflated entries; ZIP64 and encryption are refused.
struct ZipArchive {
    enum Failure: Error, Equatable {
        case notAZip
        case unsupported(String)
        case missingEntry(String)
        case corrupt
    }

    struct Entry: Hashable {
        let path: String
        let method: Int
        let compressedSize: Int
        let uncompressedSize: Int
        let localHeaderOffset: Int
    }

    let bytes: [UInt8]
    private(set) var entries: [String: Entry] = [:]

    init(data: Data) throws {
        bytes = [UInt8](data)
        try readCentralDirectory()
    }

    var paths: [String] { entries.keys.sorted() }

    func contains(_ path: String) -> Bool {
        entries[path] != nil
    }

    func data(for path: String) throws -> [UInt8] {
        guard let entry = entries[path] ?? entries.first(where: { $0.key.lowercased() == path.lowercased() })?.value else {
            throw Failure.missingEntry(path)
        }
        let header = entry.localHeaderOffset
        guard header + 30 <= bytes.count, read32(header) == 0x04034B50 else { throw Failure.corrupt }
        let nameLength = read16(header + 26)
        let extraLength = read16(header + 28)
        let start = header + 30 + nameLength + extraLength
        guard start + entry.compressedSize <= bytes.count else { throw Failure.corrupt }
        let raw = Array(bytes[start..<(start + entry.compressedSize)])
        switch entry.method {
        case 0:
            return raw
        case 8:
            return try Inflate.decompress(raw, limit: max(entry.uncompressedSize, 1) + 1024)
        default:
            throw Failure.unsupported("compression method \(entry.method)")
        }
    }

    func string(for path: String) throws -> String {
        let data = try data(for: path)
        if let text = String(bytes: data, encoding: .utf8) { return text }
        if let text = String(bytes: data, encoding: .isoLatin1) { return text }
        throw Failure.corrupt
    }

    // MARK: Parsing

    private mutating func readCentralDirectory() throws {
        guard bytes.count >= 22 else { throw Failure.notAZip }
        // The end-of-central-directory record sits in the last 64 KB.
        let lowest = max(0, bytes.count - 22 - 65_535)
        var end = -1
        var index = bytes.count - 22
        while index >= lowest {
            if read32(index) == 0x06054B50 { end = index; break }
            index -= 1
        }
        guard end >= 0 else { throw Failure.notAZip }
        let count = read16(end + 10)
        let directoryOffset = read32(end + 16)
        guard directoryOffset != 0xFFFF_FFFF, count != 0xFFFF else { throw Failure.unsupported("ZIP64") }

        var cursor = directoryOffset
        for _ in 0..<count {
            guard cursor + 46 <= bytes.count, read32(cursor) == 0x02014B50 else { throw Failure.corrupt }
            let flags = read16(cursor + 8)
            let method = read16(cursor + 10)
            let compressed = read32(cursor + 20)
            let uncompressed = read32(cursor + 24)
            let nameLength = read16(cursor + 28)
            let extraLength = read16(cursor + 30)
            let commentLength = read16(cursor + 32)
            let offset = read32(cursor + 42)
            guard cursor + 46 + nameLength <= bytes.count else { throw Failure.corrupt }
            let nameBytes = Array(bytes[(cursor + 46)..<(cursor + 46 + nameLength)])
            let name = String(bytes: nameBytes, encoding: .utf8) ?? String(bytes: nameBytes, encoding: .isoLatin1) ?? ""
            if flags & 1 != 0 { throw Failure.unsupported("encrypted entries") }
            if !name.hasSuffix("/") {
                entries[name] = Entry(path: name, method: method, compressedSize: compressed,
                                      uncompressedSize: uncompressed, localHeaderOffset: offset)
            }
            cursor += 46 + nameLength + extraLength + commentLength
        }
    }

    private func read16(_ offset: Int) -> Int {
        guard offset + 2 <= bytes.count else { return 0 }
        return Int(bytes[offset]) | Int(bytes[offset + 1]) << 8
    }

    private func read32(_ offset: Int) -> Int {
        guard offset + 4 <= bytes.count else { return 0 }
        return Int(bytes[offset]) | Int(bytes[offset + 1]) << 8 | Int(bytes[offset + 2]) << 16 | Int(bytes[offset + 3]) << 24
    }
}
