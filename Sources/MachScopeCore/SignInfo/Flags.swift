import Foundation

public struct SignatureFlags: Sendable {
    public let flags: [String]
    public let hardenedRuntime: Bool

    public init(flags: [String] = [], hardenedRuntime: Bool = false) {
        self.flags = flags
        self.hardenedRuntime = hardenedRuntime
    }

    public static func fromSigningInfo(_ info: [String: Any]) -> SignatureFlags {
        var names: [String] = []
        var hardened = false
        // CFString key bridges to "flags"
        if let flagsNumber = info["flags"] as? NSNumber {
            let flags = flagsNumber.uint64Value
            // Known bits (from cs_blobs.h / SecCode):
            let CS_ADHOC: UInt64 = 0x00000002
            let CS_RUNTIME: UInt64 = 0x00010000
            if (flags & CS_ADHOC) != 0 { names.append("adhoc") }
            if (flags & CS_RUNTIME) != 0 { names.append("runtime"); hardened = true }
        }
        return SignatureFlags(flags: names, hardenedRuntime: hardened)
    }
}


