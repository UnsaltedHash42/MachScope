import Foundation

public struct Finding: Codable, Sendable {
    public enum Severity: String, Codable, Sendable {
        case low, medium, high, critical
    }

    public let id: String
    public let severity: Severity
    public let reason: String

    public init(id: String, severity: Severity, reason: String) {
        self.id = id
        self.severity = severity
        self.reason = reason
    }
}


