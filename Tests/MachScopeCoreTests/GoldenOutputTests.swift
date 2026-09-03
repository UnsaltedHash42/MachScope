import Foundation
import Testing
@testable import MachScopeCore

@Suite struct GoldenOutputTests {
    @Test func htmlReportRendersCount() {
        let report = HTMLReport()
        let html = report.render(records: [])
        #expect(html.contains("MachScope Report"))
    }

    @Test func jsonEnvelopeHasContractShape() throws {
        let engine = RulesEngine.loadDefault()
        let report = ScanReport(
            root: "/usr/bin/ls",
            startedAt: Date(timeIntervalSince1970: 0),
            durationMs: 1,
            filesSeen: 1,
            rulesDigest: engine.digest,
            records: [Record(path: "/usr/bin/ls")]
        )
        let data = try JSONWriter().write(report: report)
        let any = try JSONSerialization.jsonObject(with: data, options: [])
        let object = try #require(any as? [String: Any])
        let tool = try #require(object["tool"] as? [String: Any])
        let scan = try #require(object["scan"] as? [String: Any])
        #expect(object["schema_version"] as? Int == 1)
        #expect(tool["name"] as? String == "machscope")
        #expect((scan["rules_digest"] as? String)?.hasPrefix("sha256:") == true)
        let records = try #require(object["records"] as? [[String: Any]])
        #expect(records[0]["entitlements_der_only"] as? [String] == [])
    }

    @Test func recordsMatchGoldenFixture() throws {
        let actual = try JSONWriter().writeRecords(fixtureRecords())
        let fixtureURL = try #require(
            Bundle.module.url(forResource: "example", withExtension: "json")
        )
        let expected = try Data(contentsOf: fixtureURL)
        #expect(actual == expected)
    }

    private func fixtureRecords() -> [Record] {
        let findings = [
            Finding(
                id: "CRITICAL",
                severity: .critical,
                classification: .weakening,
                reason: "Critical fixture"
            ),
            Finding(
                id: "LOW_ONE",
                severity: .low,
                classification: .capability,
                reason: "First low fixture"
            ),
            Finding(
                id: "LOW_TWO",
                severity: .low,
                classification: .provenance,
                reason: "Second low fixture"
            )
        ]
        return [
            Record(path: "/fixtures/clean"),
            Record(
                path: "/fixtures/risky",
                bundleId: "com.example.risky",
                binaryType: "exec",
                arch: ["arm64"],
                teamId: "EXAMPLETEAM",
                signingIdentifier: "com.example.risky",
                signingAuthorities: ["Example Authority"],
                hardenedRuntime: true,
                signatureFlags: ["runtime"],
                cdhash: "0123456789abcdef",
                format: "Mach-O 64-bit",
                entitlements: [
                    "array": .array([.string("one"), .int(2)]),
                    "bool": .bool(true),
                    "com.apple.private.security.storage.AppBundles": .bool(true),
                    "data": .data(3),
                    "dictionary": .dictionary(["nested": .bool(false)]),
                    "double": .double(1.5),
                    "int": .int(7),
                    "string": .string("value"),
                    "unknown": .unknown
                ],
                entitlementsDerOnly: ["com.apple.private.security.storage.AppBundles"],
                sandboxed: false,
                developerType: "Developer ID",
                hasQuarantineXattr: false,
                certificateChain: [.init(subject: "Digest unavailable")],
                findings: findings,
                riskScore: 40
            )
        ]
    }
}
