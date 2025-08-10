import XCTest
@testable import MachScopeCore

final class ParserTests: XCTestCase {
    func test_json_writer_encodes_empty_records() throws {
        let writer = JSONWriter()
        let data = try writer.write(records: [])
        XCTAssertGreaterThan(data.count, 0)
    }
}


