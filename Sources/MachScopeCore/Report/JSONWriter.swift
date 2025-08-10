import Foundation

public struct JSONWriter {
    public init() {}
    public func write(records: [Record]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(records)
    }
}


