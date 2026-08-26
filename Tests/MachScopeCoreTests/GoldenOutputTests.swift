import Foundation
import Testing
@testable import MachScopeCore

@Suite struct GoldenOutputTests {
    @Test func htmlReportRendersCount() {
        let report = HTMLReport()
        let html = report.render(records: [])
        #expect(html.contains("MachScope Report"))
    }

    @Test func jsonWriterMatchesGoldenExampleShape() throws {
        let record = Record(path: "/usr/bin/ls")
        let data = try JSONWriter().write(records: [record])
        let any = try JSONSerialization.jsonObject(with: data, options: [])
        let arr = try #require(any as? [[String: Any]])
        let obj = try #require(arr.first)
        #expect(obj["path"] != nil)
        #expect(obj["entitlements"] != nil)
    }
}
