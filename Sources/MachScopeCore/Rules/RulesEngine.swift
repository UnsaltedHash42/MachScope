import Foundation
import CryptoKit

public struct RulesEngine: Sendable {
    public struct Weights: Sendable, Equatable {
        public let low: Int
        public let medium: Int
        public let high: Int
        public let critical: Int

        public init(low: Int, medium: Int, high: Int, critical: Int) {
            self.low = low
            self.medium = medium
            self.high = high
            self.critical = critical
        }

        func value(for severity: Finding.Severity) -> Int {
            switch severity {
            case .low: low
            case .medium: medium
            case .high: high
            case .critical: critical
            }
        }
    }

    public enum EntitlementPredicate: Sendable, Equatable {
        case isValue(Bool)
        case present(Bool)
        case equals(String)
        case contains(String)
    }

    public indirect enum Condition: Sendable, Equatable {
        case entitlement(String, EntitlementPredicate)
        case flag(String, present: Bool)
        case quarantine(present: Bool)
        case notarization(equals: String)
        case any([Condition])
    }

    public enum MatchMode: String, Sendable {
        case all
        case any
    }

    public struct Rule: Sendable, Equatable {
        public let id: String
        public let severity: Finding.Severity
        public let reason: String
        public let weight: Int
        public let mode: MatchMode
        public let conditions: [Condition]

        public init(
            id: String,
            severity: Finding.Severity,
            reason: String,
            weight: Int,
            mode: MatchMode,
            conditions: [Condition]
        ) {
            self.id = id
            self.severity = severity
            self.reason = reason
            self.weight = weight
            self.mode = mode
            self.conditions = conditions
        }

        public var matchSummary: String {
            let separator = mode == .all ? " and " : " or "
            return conditions.map(\.summary).joined(separator: separator)
        }
    }

    public struct ParseError: Error, CustomStringConvertible, Sendable, Equatable {
        public let line: Int
        public let message: String

        public var description: String {
            "line \(line): \(message)"
        }
    }

    public struct LoadError: Error, CustomStringConvertible, Sendable, Equatable {
        public let message: String

        public var description: String { message }
    }

    public let rules: [Rule]
    public let weights: Weights
    public let digest: String

    public init(
        rules: [Rule] = [],
        weights: Weights = Weights(low: 1, medium: 5, high: 15, critical: 40)
    ) {
        self.rules = rules
        self.weights = weights
        self.digest = Self.digest(for: Data())
    }

    private init(rules: [Rule], weights: Weights, digest: String) {
        self.rules = rules
        self.weights = weights
        self.digest = digest
    }

    public func evaluate(
        entitlements: [String: EntitlementValue],
        flags: [String],
        notarization: String?,
        hasQuarantine: Bool? = nil
    ) -> [Finding] {
        if entitlements.isEmpty && flags.isEmpty && notarization == nil && hasQuarantine == nil {
            return []
        }

        let context = EvaluationContext(
            entitlements: entitlements,
            flags: Set(flags),
            notarization: notarization,
            hasQuarantine: hasQuarantine
        )
        return rules.compactMap { rule in
            let matches: Bool
            switch rule.mode {
            case .all:
                matches = rule.conditions.allSatisfy { $0.matches(context) }
            case .any:
                matches = rule.conditions.contains { $0.matches(context) }
            }
            return matches
                ? Finding(id: rule.id, severity: rule.severity, reason: rule.reason)
                : nil
        }
    }

    public static func loadDefault() -> RulesEngine {
        guard let url = Bundle.module.url(forResource: "DefaultRules", withExtension: "yml"),
              let data = try? Data(contentsOf: url) else {
            fatalError("DefaultRules.yml is missing from the resource bundle")
        }
        do {
            return try load(fromYAMLData: data)
        } catch {
            fatalError("DefaultRules.yml is invalid: \(error)")
        }
    }

    public static func load(fromYAMLData data: Data) throws -> RulesEngine {
        var parser = try Parser(data: data)
        let engine = try parser.parse()
        return RulesEngine(
            rules: engine.rules,
            weights: engine.weights,
            digest: digest(for: data)
        )
    }

    public static func load(fromFilePath path: String) throws -> RulesEngine {
        do {
            return try load(fromYAMLData: Data(contentsOf: URL(fileURLWithPath: path)))
        } catch let error as ParseError {
            throw error
        } catch {
            throw LoadError(message: "unable to read rules file \(path): \(error.localizedDescription)")
        }
    }

    private static func digest(for data: Data) -> String {
        let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return "sha256:\(hex)"
    }
}

private struct EvaluationContext {
    let entitlements: [String: EntitlementValue]
    let flags: Set<String>
    let notarization: String?
    let hasQuarantine: Bool?
}

private extension RulesEngine.Condition {
    func matches(_ context: EvaluationContext) -> Bool {
        switch self {
        case .entitlement(let key, let predicate):
            let value = context.entitlements[key]
            switch predicate {
            case .isValue(let expected):
                return value == .bool(expected)
            case .present(let expected):
                return (value != nil) == expected
            case .equals(let expected):
                return value?.asString == expected
            case .contains(let expected):
                if value?.asString == expected { return true }
                return value?.asStringArray?.contains(expected) == true
            }
        case .flag(let name, let expected):
            return context.flags.contains(name) == expected
        case .quarantine(let expected):
            return context.hasQuarantine == expected
        case .notarization(let expected):
            return context.notarization?.lowercased() == expected.lowercased()
        case .any(let conditions):
            return conditions.contains { $0.matches(context) }
        }
    }

    var summary: String {
        switch self {
        case .entitlement(let key, let predicate):
            switch predicate {
            case .isValue(let value): return "entitlement \(key) is \(value)"
            case .present(let value): return "entitlement \(key) present \(value)"
            case .equals(let value): return "entitlement \(key) equals \(value)"
            case .contains(let value): return "entitlement \(key) contains \(value)"
            }
        case .flag(let name, let present):
            return "flag \(name) present \(present)"
        case .quarantine(let present):
            return "quarantine present \(present)"
        case .notarization(let value):
            return "notarization equals \(value)"
        case .any(let conditions):
            return "any (\(conditions.map(\.summary).joined(separator: " or ")))"
        }
    }
}

private struct Parser {
    private struct Line {
        let number: Int
        let indent: Int
        let text: String
    }

    private let lines: [Line]
    private var index = 0

    init(data: Data) throws {
        guard let text = String(data: data, encoding: .utf8) else {
            throw RulesEngine.ParseError(line: 1, message: "expected UTF-8 ruleset")
        }
        var parsed: [Line] = []
        for (offset, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            if rawLine.contains("\t") {
                throw RulesEngine.ParseError(
                    line: offset + 1,
                    message: "expected spaces for indentation"
                )
            }
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            let indent = rawLine.prefix { $0 == " " }.count
            parsed.append(Line(number: offset + 1, indent: indent, text: trimmed))
        }
        self.lines = parsed
    }

    mutating func parse() throws -> RulesEngine {
        let versionLine = try takeLine(expected: "version: 2")
        guard versionLine.indent == 0, versionLine.text == "version: 2" else {
            throw error(at: versionLine, expected: "version: 2")
        }

        let weightsLine = try takeLine(expected: "weights map")
        guard weightsLine.indent == 0 else {
            throw error(at: weightsLine, expected: "weights map")
        }
        let weights = try parseWeights(weightsLine)

        let rulesLine = try takeLine(expected: "rules:")
        guard rulesLine.indent == 0, rulesLine.text == "rules:" else {
            throw error(at: rulesLine, expected: "rules:")
        }

        var rules: [RulesEngine.Rule] = []
        while index < lines.count {
            rules.append(try parseRule(weights: weights))
        }
        guard !rules.isEmpty else {
            throw RulesEngine.ParseError(
                line: rulesLine.number,
                message: "expected at least one rule"
            )
        }
        return RulesEngine(rules: rules, weights: weights)
    }

    private mutating func parseWeights(_ line: Line) throws -> RulesEngine.Weights {
        guard line.text.hasPrefix("weights: {") && line.text.hasSuffix("}") else {
            throw error(at: line, expected: "weights: { low: N, medium: N, high: N, critical: N }")
        }
        let start = line.text.index(line.text.startIndex, offsetBy: 10)
        let end = line.text.index(before: line.text.endIndex)
        let body = line.text[start..<end]
        var values: [String: Int] = [:]
        for entry in body.split(separator: ",", omittingEmptySubsequences: false) {
            let parts = entry.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
            guard parts.count == 2,
                  ["low", "medium", "high", "critical"].contains(parts[0]),
                  values[parts[0]] == nil,
                  let value = Int(parts[1]), value >= 0 else {
                throw error(at: line, expected: "four non-negative severity weights")
            }
            values[parts[0]] = value
        }
        guard let low = values["low"], let medium = values["medium"],
              let high = values["high"], let critical = values["critical"],
              values.count == 4 else {
            throw error(at: line, expected: "low, medium, high, and critical weights")
        }
        return RulesEngine.Weights(

            low: low,
            medium: medium,
            high: high,
            critical: critical
        )
    }

    private mutating func parseRule(weights: RulesEngine.Weights) throws -> RulesEngine.Rule {
        let idLine = try takeLine(expected: "rule id")
        guard idLine.indent == 2, idLine.text.hasPrefix("- id: ") else {
            throw error(at: idLine, expected: "- id: UPPERCASE_ID")
        }
        let id = String(idLine.text.dropFirst(6))
        guard isValidID(id) else {
            throw error(at: idLine, expected: "an ID containing only A-Z, 0-9, and _")
        }

        var severity: Finding.Severity?
        var reason: String?
        var weightOverride: Int?
        var mode: RulesEngine.MatchMode?
        var conditions: [RulesEngine.Condition]?

        while index < lines.count {
            let line = lines[index]
            if line.indent == 2 && line.text.hasPrefix("- id:") { break }
            guard line.indent == 4 else {
                throw error(at: line, expected: "a rule property")
            }

            if line.text.hasPrefix("severity: ") {
                guard severity == nil,
                      let value = Finding.Severity(rawValue: String(line.text.dropFirst(10))) else {
                    throw error(at: line, expected: "severity: low|medium|high|critical")
                }
                severity = value
                index += 1
            } else if line.text.hasPrefix("reason: ") {
                guard reason == nil else {
                    throw error(at: line, expected: "one reason")
                }
                let value = String(line.text.dropFirst(8))
                guard !value.isEmpty else {
                    throw error(at: line, expected: "a non-empty reason")
                }
                reason = value
                index += 1
            } else if line.text.hasPrefix("weight: ") {
                guard weightOverride == nil,
                      let value = Int(line.text.dropFirst(8)), value >= 0 else {
                    throw error(at: line, expected: "a non-negative integer weight")
                }
                weightOverride = value
                index += 1
            } else if line.text == "all:" || line.text == "any:" {
                guard mode == nil else {
                    throw error(at: line, expected: "exactly one of all: or any:")
                }
                let parsedMode: RulesEngine.MatchMode = line.text == "all:" ? .all : .any
                index += 1
                let parsedConditions = try parseConditions(
                    indent: 6,
                    allowNestedAny: parsedMode == .all
                )
                mode = parsedMode
                conditions = parsedConditions
            } else {
                throw error(at: line, expected: "severity, reason, weight, all, or any")
            }
        }

        guard let severity else {
            throw RulesEngine.ParseError(line: idLine.number, message: "expected severity")
        }
        guard let reason else {
            throw RulesEngine.ParseError(line: idLine.number, message: "expected reason")
        }
        guard let mode, let conditions else {
            throw RulesEngine.ParseError(
                line: idLine.number,
                message: "expected exactly one of all: or any:"
            )
        }
        return RulesEngine.Rule(
            id: id,
            severity: severity,
            reason: reason,
            weight: weightOverride ?? weights.value(for: severity),
            mode: mode,
            conditions: conditions
        )
    }

    private mutating func parseConditions(
        indent: Int,
        allowNestedAny: Bool
    ) throws -> [RulesEngine.Condition] {
        var conditions: [RulesEngine.Condition] = []
        while index < lines.count {
            let line = lines[index]
            if line.indent < indent { break }
            guard line.indent == indent, line.text.hasPrefix("- ") else {
                throw error(at: line, expected: "a condition")
            }
            let declaration = String(line.text.dropFirst(2))
            if declaration == "any:" {
                guard allowNestedAny else {
                    throw error(at: line, expected: "no deeper than one nested any:")
                }
                index += 1
                let nested = try parseConditions(indent: indent + 4, allowNestedAny: false)
                conditions.append(.any(nested))
                continue
            }

            let parts = declaration.split(
                separator: ":",
                maxSplits: 1,
                omittingEmptySubsequences: false
            ).map(String.init)
            guard parts.count == 2 else {
                throw error(at: line, expected: "a condition key and value")
            }
            let key = parts[0]
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            index += 1
            guard index < lines.count else {
                throw RulesEngine.ParseError(line: line.number, message: "expected a condition comparator")
            }
            let comparatorLine = lines[index]
            guard comparatorLine.indent == indent + 2 else {
                throw error(at: comparatorLine, expected: "a condition comparator")
            }
            let comparatorParts = comparatorLine.text.split(separator: ":", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard comparatorParts.count == 2 else {
                throw error(at: comparatorLine, expected: "a condition comparator")
            }
            let comparator = comparatorParts[0]
            let expected = comparatorParts[1]
            let condition: RulesEngine.Condition

            switch key {
            case "entitlement":
                guard !value.isEmpty else {
                    throw error(at: line, expected: "an entitlement name")
                }
                switch comparator {
                case "is":
                    condition = .entitlement(value, .isValue(try parseBool(expected, at: comparatorLine)))
                case "present":
                    condition = .entitlement(value, .present(try parseBool(expected, at: comparatorLine)))
                case "equals":
                    guard !expected.isEmpty else { throw error(at: comparatorLine, expected: "a string value") }
                    condition = .entitlement(value, .equals(expected))
                case "contains":
                    guard !expected.isEmpty else { throw error(at: comparatorLine, expected: "a string value") }
                    condition = .entitlement(value, .contains(expected))
                default:
                    throw error(at: comparatorLine, expected: "is, present, equals, or contains")
                }
            case "flag":
                guard !value.isEmpty, comparator == "present" else {
                    throw error(at: comparatorLine, expected: "present: true|false for a flag")
                }
                condition = .flag(value, present: try parseBool(expected, at: comparatorLine))
            case "quarantine":
                guard value.isEmpty, comparator == "present" else {
                    throw error(at: comparatorLine, expected: "present: true|false for quarantine")
                }
                condition = .quarantine(present: try parseBool(expected, at: comparatorLine))
            case "notarization":
                guard value.isEmpty, comparator == "equals", !expected.isEmpty else {
                    throw error(at: comparatorLine, expected: "equals: STRING for notarization")
                }
                condition = .notarization(equals: expected)
            default:
                throw error(at: line, expected: "entitlement, flag, quarantine, notarization, or any")
            }
            conditions.append(condition)
            index += 1
        }
        guard !conditions.isEmpty else {
            let line = lines[max(0, min(index, lines.count - 1))]
            throw error(at: line, expected: "at least one condition")
        }
        return conditions
    }

    private func parseBool(_ value: String, at line: Line) throws -> Bool {
        if value == "true" { return true }
        if value == "false" { return false }
        throw error(at: line, expected: "true or false")
    }

    private func isValidID(_ id: String) -> Bool {
        id.isEmpty == false && id.unicodeScalars.allSatisfy { scalar in
            (65...90).contains(scalar.value)
                || (48...57).contains(scalar.value)
                || scalar.value == 95
        }
    }

    private mutating func takeLine(expected: String) throws -> Line {
        guard index < lines.count else {
            throw RulesEngine.ParseError(line: lines.last?.number ?? 1, message: "expected \(expected)")
        }
        defer { index += 1 }
        return lines[index]
    }

    private func error(at line: Line, expected: String) -> RulesEngine.ParseError {
        RulesEngine.ParseError(line: line.number, message: "expected \(expected)")
    }
}
