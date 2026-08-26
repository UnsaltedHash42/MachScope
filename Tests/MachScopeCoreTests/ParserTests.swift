import Foundation
import Testing
@testable import MachScopeCore

@Suite struct ParserTests {
    @Test func jsonWriterEncodesEmptyRecords() throws {
        let writer = JSONWriter()
        let data = try writer.write(records: [])
        #expect(data.count > 0)
    }

    @Test func entitlementValuesPreserveTypesAndRoundTrip() throws {
        let info: [String: Any] = [
            "entitlements-dict": [
                "enabled": true,
                "identifier": "com.example.app",
                "count": 3,
                "ratio": 1.5,
                "groups": ["one", "two"],
                "nested": ["value": false],
                "blob": Data([0, 1, 2])
            ]
        ]
        let ents = Entitlements.fromSigningInfo(info)
        #expect(ents.values["enabled"]?.isTrue == true)
        #expect(ents.values["identifier"]?.asString == "com.example.app")
        #expect(ents.values["groups"]?.asStringArray == ["one", "two"])

        let data = try JSONEncoder().encode(ents.values)
        let object = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(object["enabled"] as? Bool == true)
        #expect(object["identifier"] as? String == "com.example.app")
        #expect(object["count"] as? Int == 3)
        #expect(object["ratio"] as? Double == 1.5)
        #expect(object["groups"] as? [String] == ["one", "two"])
        #expect((object["blob"] as? [String: Int])?["data_bytes"] == 3)

        let decoded = try JSONDecoder().decode(
            [String: EntitlementValue].self,
            from: data
        )
        #expect(decoded == ents.values)
    }

    @Test func signatureFlagsDecodeKnownValues() {
        let info: [String: Any] = [
            "flags": NSNumber(value: UInt64(0x12a00))
        ]
        let sig = SignatureFlags.fromSigningInfo(info)
        #expect(sig.flags == ["kill", "restrict", "library-validation", "runtime"])
        #expect(sig.hardenedRuntime)

        let finder = SignatureFlags.fromSigningInfo([
            "flags": NSNumber(value: UInt64(0x2000))
        ])
        #expect(finder.flags == ["library-validation"])

        let installer = SignatureFlags.fromSigningInfo([
            "flags": NSNumber(value: UInt64(0x8))
        ])
        #expect(installer.flags == ["installer"])
    }

    @Test func machoMagicDetectsExecByDefault() {
        let kind = MachOMagic().detect(at: URL(fileURLWithPath: "/usr/bin/ls"))
        #expect(kind == .exec)
    }

    @Test func machoArchitecturesUseArmSubtype() {
        let arm64e = Data([
            0xcf, 0xfa, 0xed, 0xfe,
            0x0c, 0x00, 0x00, 0x01,
            0x02, 0x00, 0x00, 0x80
        ])
        let arm64 = Data([
            0xcf, 0xfa, 0xed, 0xfe,
            0x0c, 0x00, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x00
        ])
        #expect(MachOMagic().detectArchitectures(in: arm64e) == ["arm64e"])
        #expect(MachOMagic().detectArchitectures(in: arm64) == ["arm64"])
    }

    @Test func malformedFatHeaderReturnsNoArchitectures() {
        let data = Data([0xca, 0xfe, 0xba, 0xbe, 0xff, 0xff, 0xff, 0xff])
        #expect(MachOMagic().detectArchitectures(in: data).isEmpty)
    }
}


