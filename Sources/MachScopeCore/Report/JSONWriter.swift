import Foundation

public struct ScanReport: Codable, Sendable {
    public struct Tool: Codable, Sendable {
        public let name: String
        public let version: String

        enum CodingKeys: String, CodingKey {
            case name
            case version
        }
    }

    public struct Scan: Codable, Sendable {
        public let root: String
        public let startedAt: String
        public let durationMs: Int
        public let filesSeen: Int
        public let records: Int
        public let rulesDigest: String

        enum CodingKeys: String, CodingKey {
            case root
            case startedAt = "started_at"
            case durationMs = "duration_ms"
            case filesSeen = "files_seen"
            case records
            case rulesDigest = "rules_digest"
        }
    }

    public let schemaVersion: Int
    public let tool: Tool
    public let scan: Scan
    public let records: [Record]

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case tool
        case scan
        case records
    }

    public init(
        root: String,
        startedAt: Date,
        durationMs: Int,
        filesSeen: Int,
        rulesDigest: String,
        records: [Record]
    ) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        self.schemaVersion = 1
        self.tool = Tool(name: "machscope", version: MachScopeVersion.current)
        self.scan = Scan(
            root: root,
            startedAt: formatter.string(from: startedAt),
            durationMs: durationMs,
            filesSeen: filesSeen,
            records: records.count,
            rulesDigest: rulesDigest
        )
        self.records = records
    }

    private init(schemaVersion: Int, tool: Tool, scan: Scan, records: [Record]) {
        self.schemaVersion = schemaVersion
        self.tool = tool
        self.scan = scan
        self.records = records
    }

    fileprivate func replacingRecords(_ records: [Record]) -> ScanReport {
        ScanReport(
            schemaVersion: schemaVersion,
            tool: tool,
            scan: scan,
            records: records
        )
    }
}

public struct JSONWriter {
    public init() {}

    public func write(report: ScanReport) throws -> Data {
        try encoder().encode(report.replacingRecords(Self.sortedByPath(report.records)))
    }

    public func writeRecords(_ records: [Record]) throws -> Data {
        try encoder().encode(Self.sortedByPath(records))
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private static func sortedByPath(_ records: [Record]) -> [Record] {
        records.enumerated().sorted { lhs, rhs in
            if lhs.element.path == rhs.element.path {
                return lhs.offset < rhs.offset
            }
            return lhs.element.path.utf8.lexicographicallyPrecedes(rhs.element.path.utf8)
        }.map(\.element)
    }
}


