import XCTest
@testable import MachScopeCore

final class RulesTests: XCTestCase {
    func test_rules_engine_returns_no_findings_initially() {
        let engine = RulesEngine()
        let findings = engine.evaluate(entitlements: [:], flags: [], notarization: nil)
        XCTAssertEqual(findings.count, 0)
    }
}


