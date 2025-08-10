import Foundation

public struct Entitlements: Sendable {
    public let values: [String: Bool]

    public init(values: [String: Bool] = [:]) {
        self.values = values
    }

    public static func fromSigningInfo(_ info: [String: Any]) -> Entitlements {
        // Apple exposes entitlements under kSecCodeInfoEntitlementsDict in CF form.
        if let ent = info[kSecCodeInfoEntitlementsDict as String] as? [String: Any] {
            var bools: [String: Bool] = [:]
            for (k, v) in ent {
                if let b = v as? Bool { bools[k] = b }
            }
            return Entitlements(values: bools)
        }
        return Entitlements()
    }
}


