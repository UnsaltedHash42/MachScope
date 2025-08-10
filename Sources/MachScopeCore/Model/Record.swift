import Foundation

public struct Record: Codable, Sendable {
    public let path: String
    public let bundleId: String?
    public let binaryType: String?
    public let arch: [String]
    public let teamId: String?
    public let signingAuthorities: [String]
    public let hardenedRuntime: Bool?
    public let signatureFlags: [String]
    public let notarization: String?
    public let entitlements: [String: Bool]
    public let findings: [Finding]
    public let errors: [String]

    public init(
        path: String,
        bundleId: String? = nil,
        binaryType: String? = nil,
        arch: [String] = [],
        teamId: String? = nil,
        signingAuthorities: [String] = [],
        hardenedRuntime: Bool? = nil,
        signatureFlags: [String] = [],
        notarization: String? = nil,
        entitlements: [String: Bool] = [:],
        findings: [Finding] = [],
        errors: [String] = []
    ) {
        self.path = path
        self.bundleId = bundleId
        self.binaryType = binaryType
        self.arch = arch
        self.teamId = teamId
        self.signingAuthorities = signingAuthorities
        self.hardenedRuntime = hardenedRuntime
        self.signatureFlags = signatureFlags
        self.notarization = notarization
        self.entitlements = entitlements
        self.findings = findings
        self.errors = errors
    }
}


