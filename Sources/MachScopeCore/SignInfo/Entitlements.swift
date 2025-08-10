import Foundation

public struct Entitlements: Sendable {
    public let values: [String: Bool]

    public init(values: [String: Bool] = [:]) {
        self.values = values
    }

    public static func fromSigningInfo(_ info: [String: Any]) -> Entitlements {
        // Accept common keys that may appear from SecCodeCopySigningInformation bridging
        // or in tests: "entitlements" or the CFString-bridged constant name.
        let possibleKeys = [
            "entitlements",
            "Entitlements",
            "kSecCodeInfoEntitlementsDict"
        ]
        for key in possibleKeys {
            if let ent = info[key] as? [String: Any] {
                var bools: [String: Bool] = [:]
                for (k, v) in ent {
                    if let b = v as? Bool { bools[k] = b }
                }
                return Entitlements(values: bools)
            }
        }
        return Entitlements()
    }
}


