import Foundation
import SecurityBridge
import MachO

public struct SignInfoExtractor {
    private let rulesEngine: RulesEngine?
    private static let secAPISem = DispatchSemaphore(value: 2)
    public init(rulesEngine: RulesEngine? = nil) {
        self.rulesEngine = rulesEngine
    }

    public func extract(for url: URL) -> [String: Any] {
        var osStatus: OSStatus = errSecSuccess
        SignInfoExtractor.secAPISem.wait()
        let unmanagedOpt = SecBridge.copySigningInfo(forPath: url.path, error: &osStatus)
        SignInfoExtractor.secAPISem.signal()
        guard let unmanaged = unmanagedOpt else {
            return [:]
        }
        let cfDict = unmanaged.takeRetainedValue()
        let dict = cfDict as NSDictionary as? [String: Any] ?? [:]
        return dict
    }

    public func extractWithErrors(for url: URL) -> (info: [String: Any], errors: [String]) {
        var errors: [String] = []
        var osStatus: OSStatus = errSecSuccess
        SignInfoExtractor.secAPISem.wait()
        let unmanagedOpt = SecBridge.copySigningInfo(forPath: url.path, error: &osStatus)
        SignInfoExtractor.secAPISem.signal()
        guard let unmanaged = unmanagedOpt else {
            errors.append("SecCodeCopySigningInformation failed: OSStatus=\(osStatus)")
            return ([:], errors)
        }
        let cfDict = unmanaged.takeRetainedValue()
        let dict = cfDict as NSDictionary as? [String: Any] ?? [:]
        return (dict, errors)
    }

    public func buildRecord(for url: URL, assessmentEnabled: Bool = false) -> Record {
        let (signInfo, initialErrors) = extractWithErrors(for: url)
        let entitlements = Entitlements.fromSigningInfo(signInfo)
        let flags = SignatureFlags.fromSigningInfo(signInfo)

        var bundleId: String? = nil
        if let bundleURL = BundleIntrospector().findContainingBundle(for: url) {
            bundleId = BundleIntrospector().parseBundleIdentifier(at: bundleURL)
        }

        let teamId = signInfo["teamid"] as? String
        let signingIdentifier = signInfo["identifier"] as? String
        let authorities = (signInfo["authority"] as? [String]) ?? []
        let certs: [Record.CertificateSummary]? = (signInfo["certificates"] as? [Any])?.compactMap { any in
            // certificates is usually an array of SecCertificate refs which bridge to Data/CFData in signing info
            if let dict = any as? [String: Any] {
                let subj = dict["subject"] as? String ?? ""
                let sha = dict["sha256"] as? String ?? ""
                return Record.CertificateSummary(subject: subj, sha256: sha)
            }
            return nil
        }

        let archs: [String] = MachOMagic().detectArchitectures(at: url)

        let notarization = Assessment().assessNotarizationString(at: url, enabled: assessmentEnabled)
        let engine = self.rulesEngine ?? RulesEngine.loadDefault()
        let findings = engine.evaluate(entitlements: entitlements.values, flags: flags.flags, notarization: notarization)

        // Quarantine xattr
        let quarantine = hasQuarantineAttribute(atPath: url.path)

        // Sandbox: infer from entitlements
        let sandboxed = entitlements.values["com.apple.security.app-sandbox"].map { $0 }

        // Developer type from authorities
        let developerType = authorities.first.map { auth in
            if auth.contains("Apple Development") || auth.contains("Apple Distribution") { return "Apple" }
            if auth.contains("Developer ID Application") { return "Developer ID" }
            return "Unknown"
        }

        return Record(
            path: url.path,
            bundleId: bundleId,
            binaryType: MachOMagic().detect(at: url).rawValue,
            arch: archs,
            teamId: teamId,
            signingIdentifier: signingIdentifier,
            signingAuthorities: authorities,
            hardenedRuntime: flags.hardenedRuntime,
            signatureFlags: flags.flags,
            notarization: notarization,
            entitlements: entitlements.values,
            sandboxed: sandboxed,
            developerType: developerType,
            hasQuarantineXattr: quarantine,
            certificateChain: certs,
            findings: findings,
            errors: initialErrors
        )
    }

    private func hasQuarantineAttribute(atPath path: String) -> Bool {
        let name = "com.apple.quarantine"
        return name.withCString { namePtr in
            return path.withCString { pathPtr in
                let size = getxattr(pathPtr, namePtr, nil, 0, 0, 0)
                return size > 0
            }
        }
    }
}


