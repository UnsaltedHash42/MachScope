import Foundation

public struct BundleIntrospector {
    public init() {}

    public func parseBundleIdentifier(at bundleURL: URL) -> String? {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else { return nil }
        return dict["CFBundleIdentifier"] as? String
    }

    public func findContainingBundle(for url: URL) -> URL? {
        var current = url
        let fm = FileManager.default
        while true {
            if current.pathExtension.lowercased() == "app", fm.fileExists(atPath: current.appendingPathComponent("Contents/Info.plist").path) {
                return current
            }
            let parent = current.deletingLastPathComponent()
            if parent.path == current.path { return nil }
            current = parent
        }
    }
}


