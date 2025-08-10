import Foundation

public struct RulesEngine {
    public init() {}

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

        // Notarization
        if let n = notarization?.lowercased(), n == "rejected" {
            add("NOTARIZATION_REJECTED", .high, "Gatekeeper assessment was rejected")
        }

        return findings
    }
}


