import XCTest
@testable import MachScopeCore

final class ParserTests: XCTestCase {
    func test_json_writer_encodes_empty_records() throws {
        let writer = JSONWriter()
        let data = try writer.write(records: [])
        XCTAssertGreaterThan(data.count, 0)
    }

    func test_entitlements_from_signing_info_parses_bools() {
        let info: [String: Any] = [
            "entitlements": [
                "com.apple.security.get-task-allow": true,
                "com.apple.security.cs.allow-jit": false,
                "nonbool": "x"
            ]
        ]
        let ents = Entitlements.fromSigningInfo(info)
        XCTAssertEqual(ents.values["com.apple.security.get-task-allow"], true)
        XCTAssertEqual(ents.values["com.apple.security.cs.allow-jit"], false)
        XCTAssertNil(ents.values["nonbool"])
    }

    func test_signature_flags_mapping_runtime_and_adhoc() {
        // flags: runtime(0x00010000) + adhoc(0x2)
        let info: [String: Any] = [
            "flags": NSNumber(value: UInt64(0x00010000 | 0x2))
        ]
        let sig = SignatureFlags.fromSigningInfo(info)
        XCTAssertTrue(sig.flags.contains("runtime"))
        XCTAssertTrue(sig.flags.contains("adhoc"))
        XCTAssertTrue(sig.hardenedRuntime)
    }

    func test_macho_magic_detects_exec_by_default() {
        let kind = MachOMagic().detect(at: URL(fileURLWithPath: "/usr/bin/ls"))
        XCTAssertEqual(kind, .exec)
    }
}


