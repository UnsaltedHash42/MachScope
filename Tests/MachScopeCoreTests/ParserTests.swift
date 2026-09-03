import Foundation
import Testing
@testable import MachScopeCore

@Suite struct ParserTests {
    @Test func jsonWriterEncodesEmptyRecords() throws {
        let writer = JSONWriter()
        let data = try writer.write(report: ScanReport(
            root: "/tmp",
            startedAt: Date(timeIntervalSince1970: 0),
            durationMs: 0,
            filesSeen: 0,
            rulesDigest: RulesEngine.loadDefault().digest,
            records: []
        ))
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

    @Test func entitlementUnionMarksDerOnlyKeysAndFeedsRules() throws {
        let xml = try PropertyListSerialization.data(
            fromPropertyList: [
                "shared": true,
                "xml-only": "value"
            ],
            format: .xml,
            options: 0
        )
        let info: [String: Any] = [
            "entitlements": xml,
            "entitlements-DER": Data([0x01]),
            "entitlements-dict": [
                "shared": true,
                "xml-only": "value",
                "com.example.der-only": true
            ]
        ]
        let entitlements = Entitlements.fromSigningInfo(info)
        let engine = try RulesEngine.load(fromYAMLData: Data("""
        version: 2
        weights: { low: 1, medium: 5, high: 15, critical: 40 }
        rules:
          - id: DER_ONLY_MATCH
            severity: high
            class: weakening
            reason: DER-only fixture matched
            all:
              - entitlement: com.example.der-only
                is: true
        """.utf8))
        let findings = engine.evaluate(
            entitlements: entitlements.values,
            flags: [],
            notarization: nil
        )

        #expect(entitlements.values.keys.sorted() == [
            "com.example.der-only", "shared", "xml-only"
        ])
        #expect(entitlements.derOnlyKeys == ["com.example.der-only"])
        #expect(findings.map(\.id) == ["DER_ONLY_MATCH"])
    }

    @Test func malformedXmlDoesNotMislabelUnionAsDerOnly() {
        let info: [String: Any] = [
            "entitlements": Data("not a plist".utf8),
            "entitlements-DER": Data([0x01]),
            "entitlements-dict": ["union-key": true]
        ]

        #expect(Entitlements.fromSigningInfo(info).derOnlyKeys.isEmpty)
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

