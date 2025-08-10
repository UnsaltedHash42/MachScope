import Foundation
import SecurityBridge
import MachO

public struct SignInfoExtractor {
    public init() {}

    public func extract(for url: URL) -> [String: Any] {
        var osStatus: OSStatus = errSecSuccess
        guard let unmanaged = SecBridge.copySigningInfo(forPath: url.path, error: &osStatus) else {
            return [:]
        }
        let cfDict = unmanaged.takeRetainedValue()
        let dict = cfDict as NSDictionary as? [String: Any] ?? [:]
        return dict
    }

    public func buildRecord(for url: URL) -> Record {
        let signInfo = extract(for: url)
        let entitlements = Entitlements.fromSigningInfo(signInfo)
        let flags = SignatureFlags.fromSigningInfo(signInfo)

        var bundleId: String? = nil
        if let bundleURL = BundleIntrospector().findContainingBundle(for: url) {
            bundleId = BundleIntrospector().parseBundleIdentifier(at: bundleURL)
        }

        let teamId = signInfo["teamid"] as? String
        let authorities = (signInfo["authority"] as? [String]) ?? []

        let archs: [String] = MachOMagic().detectArchitectures(at: url)

        let notarization = Assessment().assessNotarizationString(at: url)
        let findings = RulesEngine().evaluate(entitlements: entitlements.values, flags: flags.flags, notarization: notarization)

        return Record(
            path: url.path,
            bundleId: bundleId,
            binaryType: MachOMagic().detect(at: url).rawValue,
            arch: archs,
            teamId: teamId,
            signingAuthorities: authorities,
            hardenedRuntime: flags.hardenedRuntime,
            signatureFlags: flags.flags,
            notarization: notarization,
            entitlements: entitlements.values,
            findings: findings,
            errors: []
        )
    }
}


