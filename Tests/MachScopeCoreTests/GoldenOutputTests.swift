import XCTest
@testable import MachScopeCore

final class GoldenOutputTests: XCTestCase {
    func test_html_report_renders_count() {
        let report = HTMLReport()
        let html = report.render(records: [])
        XCTAssertTrue(html.contains("MachScope Report"))
    }
}


