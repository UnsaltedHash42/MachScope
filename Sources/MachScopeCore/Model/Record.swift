import Foundation

public struct Record: Codable, Sendable {
    public struct CertificateSummary: Codable, Sendable {
        public let subject: String
        public let sha256: String?

        enum CodingKeys: String, CodingKey {
            case subject
            case sha256
        }

        public init(subject: String, sha256: String? = nil) {
            self.subject = subject
            self.sha256 = sha256
        }
    }
    public let path: String
    public let bundleId: String?
    public let binaryType: String?
    public let arch: [String]
    public let teamId: String?
    public let signingIdentifier: String?
    public let signingAuthorities: [String]
    public let hardenedRuntime: Bool?
    public let signatureFlags: [String]
    public let cdhash: String?
    public let platformBinary: Bool
    public let format: String?
    public let notarization: String?
    public let entitlements: [String: EntitlementValue]
    public let sandboxed: Bool?
    public let developerType: String?
    public let hasQuarantineXattr: Bool?
    public let certificateChain: [CertificateSummary]
    public let findings: [Finding]
    public let errors: [String]

    enum CodingKeys: String, CodingKey {
        case path
        case bundleId = "bundle_id"
        case binaryType = "binary_type"
        case arch
        case teamId = "team_id"
        case signingIdentifier = "signing_identifier"
        case signingAuthorities = "signing_authorities"
        case hardenedRuntime = "hardened_runtime"
        case signatureFlags = "signature_flags"
        case cdhash
        case platformBinary = "platform_binary"
        case format
        case notarization
        case entitlements
        case sandboxed
        case developerType = "developer_type"
        case hasQuarantineXattr = "has_quarantine_xattr"
        case certificateChain = "certificate_chain"
        case findings
        case errors
    }

    public init(
        path: String,
        bundleId: String? = nil,
        binaryType: String? = nil,
        arch: [String] = [],
        teamId: String? = nil,
        signingIdentifier: String? = nil,
        signingAuthorities: [String] = [],
        hardenedRuntime: Bool? = nil,
        signatureFlags: [String] = [],
        cdhash: String? = nil,
        platformBinary: Bool = false,
        format: String? = nil,
        notarization: String? = nil,
        entitlements: [String: EntitlementValue] = [:],
        sandboxed: Bool? = nil,
        developerType: String? = nil,
        hasQuarantineXattr: Bool? = nil,
        certificateChain: [CertificateSummary] = [],
        findings: [Finding] = [],
        errors: [String] = []
    ) {
        self.path = path
        self.bundleId = bundleId
        self.binaryType = binaryType
        self.arch = arch
        self.teamId = teamId
        self.signingIdentifier = signingIdentifier
        self.signingAuthorities = signingAuthorities
        self.hardenedRuntime = hardenedRuntime
        self.signatureFlags = signatureFlags
        self.cdhash = cdhash
        self.platformBinary = platformBinary
        self.format = format
        self.notarization = notarization
        self.entitlements = entitlements
        self.sandboxed = sandboxed
        self.developerType = developerType
        self.hasQuarantineXattr = hasQuarantineXattr
        self.certificateChain = certificateChain
        self.findings = findings
        self.errors = errors
    }
}


