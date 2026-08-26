import Foundation

public struct Finding: Codable, Sendable {
    public enum Severity: String, Codable, Sendable {
        case low, medium, high, critical
    }

    public let id: String
    public let severity: Severity
    public let reason: String

    enum CodingKeys: String, CodingKey {
        case id
        case severity
        case reason
    }

    public init(id: String, severity: Severity, reason: String) {
        self.id = id
        self.severity = severity
        self.reason = reason
    }
}


