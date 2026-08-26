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
        if let flagsNumber = info["flags"] as? NSNumber {
            let flags = flagsNumber.uint64Value
            let table: [(UInt64, String)] = [
                (0x00000002, "adhoc"),
                (0x00000004, "get-task-allow"),
                (0x00000008, "installer"),
                (0x00000010, "forced-lv"),
                (0x00000020, "invalid-allowed"),
                (0x00000100, "hard"),
                (0x00000200, "kill"),
                (0x00000400, "check-expiration"),
                (0x00000800, "restrict"),
                (0x00001000, "enforcement"),
                (0x00002000, "library-validation"),
                (0x00010000, "runtime"),
                (0x00020000, "linker-signed")
            ]
            names = table.compactMap { flags & $0.0 == 0 ? nil : $0.1 }
        }
        return SignatureFlags(flags: names, hardenedRuntime: names.contains("runtime"))
    }
}


