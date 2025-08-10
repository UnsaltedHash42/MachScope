import Foundation

public enum BinaryKind: String {
    case exec, dylib, framework, xpc, plugin, unknown
}

public struct MachOMagic {
    public init() {}
    public func detect(at url: URL) -> BinaryKind { .unknown }
}


