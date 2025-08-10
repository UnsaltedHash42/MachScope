import Foundation

public struct RulesEngine {
    public struct YamlRule: Sendable {
        public let entitlement: String
        public let severity: Finding.Severity
        public let reason: String
    }

    private let yamlRules: [YamlRule]

    public init(yamlRules: [YamlRule] = []) {
        self.yamlRules = yamlRules
    }

    public func evaluate(entitlements: [String: Bool], flags: [String], notarization: String?) -> [Finding] {
        var findings: [Finding] = []

        func add(_ id: String, _ severity: Finding.Severity, _ reason: String) {
            findings.append(Finding(id: id, severity: severity, reason: reason))
        }

        if entitlements["com.apple.security.cs.disable-library-validation"] == true {
            add("DLV", .high, "Disable Library Validation allows dylib injection")
        }
        if entitlements["com.apple.security.cs.allow-dyld-environment-variables"] == true {
            add("DYLD_ENV", .high, "Allows manipulation via DYLD_* environment variables")
        }
        if entitlements["com.apple.security.cs.allow-unsigned-executable-memory"] == true {
            add("UNSIGNED_EXEC_MEM", .high, "Allows creation of unsigned executable memory (code injection risk)")
        }
        if entitlements["com.apple.security.cs.allow-jit"] == true {
            add("ALLOW_JIT", .high, "JIT execution enabled")
        }
        if entitlements["com.apple.security.get-task-allow"] == true {
            add("GET_TASK_ALLOW", .critical, "Debugger attachment permitted in production context")
        }

        // YAML-driven rules for entitlements
        for rule in yamlRules {
            if entitlements[rule.entitlement] == true {
                add(rule.entitlement, rule.severity, rule.reason)
            }
        }

        // Hardened Runtime missing (only if we have any flags to judge)
        if !flags.isEmpty && !flags.contains("runtime") {
            add("NO_HARDENED_RUNTIME", .medium, "Hardened Runtime not enabled")
        }

        // Combination: allow-jit and network usage (approximate by presence of client entitlement if present)
        if entitlements["com.apple.security.cs.allow-jit"] == true {
            let networkKeys = ["com.apple.security.network.client", "com.apple.security.network.server"]
            if networkKeys.contains(where: { entitlements[$0] == true }) {
                add("JIT_AND_NETWORK", .high, "JIT combined with network entitlements increases risk")
            }
        }

        // Quarantine attribute present
        if entitlements.isEmpty { /* noop */ }


        // Notarization
        if let n = notarization?.lowercased(), n == "rejected" {
            add("NOTARIZATION_REJECTED", .high, "Gatekeeper assessment was rejected")
        }

        return findings
    }

    // MARK: - Loading

    public static func loadDefault() -> RulesEngine {
        guard let url = Bundle.module.url(forResource: "DefaultRules", withExtension: "yml", subdirectory: "Rules"),
              let data = try? Data(contentsOf: url) else {
            return RulesEngine()
        }
        return load(fromYAMLData: data) ?? RulesEngine()
    }

    public static func load(fromYAMLData data: Data) -> RulesEngine? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var parsed: [YamlRule] = []
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var i = 0
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("- entitlement:") {
                let ent = line.replacingOccurrences(of: "- entitlement:", with: "").trimmingCharacters(in: .whitespaces)
                var sev: Finding.Severity = .medium
                var reason: String = ""
                var j = i + 1
                while j < lines.count {
                    let l = lines[j].trimmingCharacters(in: .whitespaces)
                    if l.hasPrefix("- entitlement:") { break }
                    if l.hasPrefix("severity:") {
                        let s = l.replacingOccurrences(of: "severity:", with: "").trimmingCharacters(in: .whitespaces).lowercased()
                        sev = Finding.Severity(rawValue: s) ?? .medium
                    } else if l.hasPrefix("reason:") {
                        reason = l.replacingOccurrences(of: "reason:", with: "").trimmingCharacters(in: .whitespaces)
                    }
                    j += 1
                }
                parsed.append(YamlRule(entitlement: ent, severity: sev, reason: reason))
                i = j
                continue
            }
            i += 1
        }
        return RulesEngine(yamlRules: parsed)
    }

    public static func load(fromFilePath path: String) -> RulesEngine? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return load(fromYAMLData: data)
    }
}


