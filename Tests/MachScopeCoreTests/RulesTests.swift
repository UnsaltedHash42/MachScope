import Testing
@testable import MachScopeCore

@Suite struct RulesTests {
    @Test func rulesEngineReturnsNoFindingsInitially() {
        let engine = RulesEngine()
        let findings = engine.evaluate(entitlements: [:], flags: [], notarization: nil)
        #expect(findings.count == 0)
    }

    @Test func rulesEngineCombinationJitAndNetwork() {
        let engine = RulesEngine()
        let ents = [
            "com.apple.security.cs.allow-jit": true,
            "com.apple.security.network.client": true
        ]
        let findings = engine.evaluate(entitlements: ents, flags: ["runtime"], notarization: nil)
        #expect(findings.contains(where: { $0.id == "JIT_AND_NETWORK" }))
    }
}


