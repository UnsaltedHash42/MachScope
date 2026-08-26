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

    public func buildRecord(for url: URL) -> Record {
        let (signInfo, initialErrors) = extractWithErrors(for: url)
        var errors = initialErrors
        let entitlements = Entitlements.fromSigningInfo(signInfo)
        let flags = SignatureFlags.fromSigningInfo(signInfo)

        var bundleId: String? = nil
        if let bundleURL = BundleIntrospector().findContainingBundle(for: url) {
            bundleId = BundleIntrospector().parseBundleIdentifier(at: bundleURL)
        }

        let teamId = signInfo["teamid"] as? String
        let signingIdentifier = signInfo["identifier"] as? String
        var certificateStatus: OSStatus = errSecSuccess
        SignInfoExtractor.secAPISem.wait()
        let certificateDictionaries = SecBridge.copyCertificateSummaries(
            forPath: url.path,
            error: &certificateStatus
        ) as? [[String: Any]] ?? []
        SignInfoExtractor.secAPISem.signal()
        let certs = certificateDictionaries.map { dictionary in
            Record.CertificateSummary(
                subject: dictionary["subject"] as? String ?? "",
                sha256: dictionary["sha256"] as? String ?? ""
            )
        }
        let authorities = certs.map(\.subject)
        let cdhash = (signInfo["cdhashes"] as? [Any])?.first
            .flatMap { $0 as? Data }?
            .map { String(format: "%02x", $0) }
            .joined()
        let platformBinary = ((signInfo["platform-identifier"] as? NSNumber)?.intValue ?? 0) != 0
        let signingFormat = signInfo["format"] as? String

        let architectureDetection = MachOMagic().architectureDetection(at: url)
        if let error = architectureDetection.error {
            errors.append(error)
        }

        let quarantine = hasQuarantineAttribute(atPath: url.path)
        let sandboxed = entitlements.values["com.apple.security.app-sandbox"]?.isTrue
        let notarization: String? = nil
        let engine = self.rulesEngine ?? RulesEngine.loadDefault()
        let findings = engine.evaluate(entitlements: entitlements.values, flags: flags.flags, notarization: notarization, hasQuarantine: quarantine)

        let developerType = authorities.first.map { auth in
            if auth.contains("Apple Development") || auth.contains("Apple Distribution") { return "Apple" }
            if auth.contains("Developer ID Application") { return "Developer ID" }
            return "Unknown"
        }

        return Record(
            path: url.path,
            bundleId: bundleId,
            binaryType: MachOMagic().detect(at: url).rawValue,
            arch: architectureDetection.architectures,
            teamId: teamId,
            signingIdentifier: signingIdentifier,
            signingAuthorities: authorities,
            hardenedRuntime: flags.hardenedRuntime,
            signatureFlags: flags.flags,
            cdhash: cdhash,
            platformBinary: platformBinary,
            format: signingFormat,
            notarization: notarization,
            entitlements: entitlements.values,
            sandboxed: sandboxed,
            developerType: developerType,
            hasQuarantineXattr: quarantine,
            certificateChain: certs,
            findings: findings,
            errors: errors
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


