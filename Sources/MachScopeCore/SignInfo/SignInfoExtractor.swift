import Foundation
import SecurityBridge

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
}


