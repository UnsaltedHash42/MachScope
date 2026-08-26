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
        #expect(object["records"] is [[String: Any]])
    }

    @Test func entitlementNamesPreserveUppercaseBytes() throws {
        let key = "com.apple.private.security.storage.AppBundles"
        let record = Record(path: "/tmp/example", entitlements: [key: .bool(true)])
        let data = try JSONWriter().writeRecords([record])
        let array = try #require(
            JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        )
        let entitlements = try #require(array.first?["entitlements"] as? [String: Any])
        #expect(entitlements[key] as? Bool == true)
    }
}
