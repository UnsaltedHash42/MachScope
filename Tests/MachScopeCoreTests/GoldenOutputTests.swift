import XCTest
@testable import MachScopeCore

final class GoldenOutputTests: XCTestCase {
    func test_html_report_renders_count() {
        let report = HTMLReport()
        let html = report.render(records: [])
        XCTAssertTrue(html.contains("MachScope Report"))
    }

    func test_json_writer_matches_golden_example_shape() throws {
        let record = Record(path: "/usr/bin/ls")
        let data = try JSONWriter().write(records: [record])
        let any = try JSONSerialization.jsonObject(with: data, options: [])
        guard let arr = any as? [[String: Any]], let obj = arr.first else {
            XCTFail("Expected top-level array with object"); return
        }
        XCTAssertNotNil(obj["path"])
        XCTAssertNotNil(obj["entitlements"])
    }
}
