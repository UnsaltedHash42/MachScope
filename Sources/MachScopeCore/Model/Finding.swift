import Foundation

public struct Finding: Codable, Sendable {
    public enum Severity: String, Codable, Sendable {
        case low, medium, high, critical
    }

    public enum Classification: String, Codable, Sendable {
        case weakening, capability, provenance
    }

    public let id: String
    public let severity: Severity
    public let classification: Classification
    public let reason: String

    enum CodingKeys: String, CodingKey {
        case id
        case severity
        case classification = "class"
        case reason
    }

    public init(
        id: String,
        severity: Severity,
        classification: Classification = .weakening,
        reason: String
    ) {
        self.id = id
        self.severity = severity
        self.classification = classification
        self.reason = reason
    }
}

