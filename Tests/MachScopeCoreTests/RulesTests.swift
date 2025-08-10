import XCTest
@testable import MachScopeCore

final class RulesTests: XCTestCase {
    func test_rules_engine_returns_no_findings_initially() {
        let engine = RulesEngine()
        let findings = engine.evaluate(entitlements: [:], flags: [], notarization: nil)
        XCTAssertEqual(findings.count, 0)
    }

    func test_rules_engine_combination_jit_and_network() {
        let engine = RulesEngine()
        let ents = [
            "com.apple.security.cs.allow-jit": true,
            "com.apple.security.network.client": true
        ]
        let findings = engine.evaluate(entitlements: ents, flags: ["runtime"], notarization: nil)
        XCTAssertTrue(findings.contains(where: { $0.id == "JIT_AND_NETWORK" }))
    }
}


