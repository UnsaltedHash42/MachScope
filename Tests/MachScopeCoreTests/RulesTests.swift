import Foundation
import Testing
@testable import MachScopeCore

@Suite struct RulesTests {
    @Test func defaultEngineLoadsAllRules() {
        let engine = RulesEngine.loadDefault()
        #expect(engine.rules.count == 24)
    }

    @Test func emptyRecordProducesNoFindings() {
        let findings = RulesEngine.loadDefault().evaluate(
            entitlements: [:],
            flags: [],
            notarization: nil
        )
        #expect(findings.isEmpty)
    }

    @Test func everyDefaultRuleFires() {
        let engine = RulesEngine.loadDefault()
        for rule in engine.rules {
            var context = RuleContext()
            let conditions = rule.mode == .all
                ? rule.conditions
                : Array(rule.conditions.prefix(1))
            for condition in conditions {
                context.apply(condition)
            }
            let findings = engine.evaluate(
                entitlements: context.entitlements,
                flags: Array(context.flags),
                notarization: context.notarization,
                hasQuarantine: context.hasQuarantine
            )
            #expect(
                findings.contains { $0.id == rule.id },
                "Expected \(rule.id) to fire"
            )
        }
    }

    @Test func formerlyDuplicatedEntitlementsProduceUniqueFindings() {
        let entitlements: [String: EntitlementValue] = [
            "com.apple.security.cs.disable-library-validation": .bool(true),
            "com.apple.security.cs.allow-dyld-environment-variables": .bool(true),
            "com.apple.security.cs.allow-unsigned-executable-memory": .bool(true),
            "com.apple.security.cs.allow-jit": .bool(true),
            "com.apple.security.get-task-allow": .bool(true)
        ]
        let findings = RulesEngine.loadDefault().evaluate(
            entitlements: entitlements,
            flags: ["runtime"],
            notarization: nil,
            hasQuarantine: false
        )
        let ids = findings.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Set(ids) == ["DLV", "DYLD_ENV", "UNSIGNED_EXEC_MEM", "ALLOW_JIT", "GET_TASK_ALLOW"])
    }

    @Test func schemaSupportsEveryEntitlementComparatorAndTopLevelAny() throws {
        let yaml = """
        version: 2
        weights: { low: 1, medium: 5, high: 15, critical: 40 }
        rules:
          - id: VALUE_MATCH
            severity: high
            reason: Value predicates match
            weight: 9
            all:
              - entitlement: enabled
                is: true
              - entitlement: identifier
                equals: com.example.app
              - entitlement: groups
                contains: group.example
              - entitlement: optional
                present: false
          - id: EITHER_FLAG
            severity: low
            reason: Any condition matches
            any:
              - flag: adhoc
                present: true
              - quarantine:
                present: true
        """
        let engine = try RulesEngine.load(fromYAMLData: Data(yaml.utf8))
        #expect(engine.rules[0].weight == 9)
        let valueFindings = engine.evaluate(
            entitlements: [
                "enabled": .bool(true),
                "identifier": .string("com.example.app"),
                "groups": .array([.string("group.example")])
            ],
            flags: [],
            notarization: nil,
            hasQuarantine: false
        )
        #expect(valueFindings.contains { $0.id == "VALUE_MATCH" })
        let anyFindings = engine.evaluate(
            entitlements: [:],
            flags: ["adhoc"],
            notarization: nil,
            hasQuarantine: false
        )
        #expect(anyFindings.contains { $0.id == "EITHER_FLAG" })
    }

    @Test(arguments: malformedRules) func malformedRulesFailWithLineNumber(yaml: String) {
        do {
            _ = try RulesEngine.load(fromYAMLData: Data(yaml.utf8))
            Issue.record("Expected ruleset parsing to fail")
        } catch let error as RulesEngine.ParseError {
            #expect(error.line > 0)
            #expect(error.description.hasPrefix("line "))
        } catch {
            Issue.record("Expected ParseError, got \(error)")
        }
    }

    @Test func nonexistentRulesFileFails() {
        #expect(throws: RulesEngine.LoadError.self) {
            try RulesEngine.load(fromFilePath: "/nonexistent")
        }
    }

    private static let malformedRules = [
        """
        version: 2
        weights: { low: 1, medium: 5, high: 15, critical: 40 }
        rules:
          - id: UNKNOWN_KEY
            severity: high
            reason: Unknown keys fail
            surprise: true
            all:
              - flag: runtime
                present: true
        """,
        """
        version: 2
        weights: { low: 1, medium: 5, high: 15, critical: 40 }
        rules:
          - id: BAD_SEVERITY
            severity: urgent
            reason: Bad severity fails
            all:
              - flag: runtime
                present: true
        """,
        """
        version: 2
        weights: { low: 1, medium: 5, high: 15, critical: 40 }
        rules:
          - id: MISSING_REASON
            severity: high
            all:
              - flag: runtime
                present: true
        """,
        """
        version: 2
        weights: { low: 1, medium: 5, high: 15, critical: 40 }
        rules:
          - id: TOO_DEEP
            severity: high
            reason: Deep nesting fails
            all:
              - any:
                  - any:
                      - flag: runtime
                        present: true
        """
    ]
}

private struct RuleContext {
    var entitlements: [String: EntitlementValue] = [:]
    var flags: Set<String> = []
    var notarization: String?
    var hasQuarantine: Bool? = false

    mutating func apply(_ condition: RulesEngine.Condition) {
        switch condition {
        case .entitlement(let key, let predicate):
            switch predicate {
            case .isValue(let value): entitlements[key] = .bool(value)
            case .present(let value):
                if value { entitlements[key] = .bool(true) }
            case .equals(let value): entitlements[key] = .string(value)
            case .contains(let value): entitlements[key] = .array([.string(value)])
            }
        case .flag(let name, let present):
            if present { flags.insert(name) } else { flags.remove(name) }
        case .quarantine(let present):
            hasQuarantine = present
        case .notarization(let value):
            notarization = value
        case .any(let conditions):
            if let condition = conditions.first { apply(condition) }
        }
    }
}
