import Foundation
import Testing
@testable import MachScopeCore

@Suite struct ParserTests {
    @Test func jsonWriterEncodesEmptyRecords() throws {
        let writer = JSONWriter()
        let data = try writer.write(records: [])
        #expect(data.count > 0)
    }

    @Test func entitlementsFromSigningInfoParsesBools() {
        let info: [String: Any] = [
            "entitlements": [
                "com.apple.security.get-task-allow": true,
                "com.apple.security.cs.allow-jit": false,
                "nonbool": "x"
            ]
        ]
        let ents = Entitlements.fromSigningInfo(info)
        #expect(ents.values["com.apple.security.get-task-allow"] == true)
        #expect(ents.values["com.apple.security.cs.allow-jit"] == false)
        #expect(ents.values["nonbool"] == nil)
    }

    @Test func signatureFlagsMappingRuntimeAndAdhoc() {
        // flags: runtime(0x00010000) + adhoc(0x2)
        let info: [String: Any] = [
            "flags": NSNumber(value: UInt64(0x00010000 | 0x2))
        ]
        let sig = SignatureFlags.fromSigningInfo(info)
        #expect(sig.flags.contains("runtime"))
        #expect(sig.flags.contains("adhoc"))
        #expect(sig.hardenedRuntime)
    }

    @Test func machoMagicDetectsExecByDefault() {
        let kind = MachOMagic().detect(at: URL(fileURLWithPath: "/usr/bin/ls"))
        #expect(kind == .exec)
    }
}


