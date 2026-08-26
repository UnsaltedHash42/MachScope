import Foundation

public struct BundleIntrospector {
    public init() {}

    public func parseBundleIdentifier(at bundleURL: URL) -> String? {
        let infoPlistURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: infoPlistURL) as? [String: Any] else { return nil }
        return dict["CFBundleIdentifier"] as? String
    }

    public func findContainingBundle(for url: URL) -> URL? {
        var currentPath = url.standardizedFileURL.path
        let fm = FileManager.default
        while true {
            let current = currentPath as NSString
            if current.pathExtension.lowercased() == "app" {
                let plistPath = current.appendingPathComponent("Contents/Info.plist")
                if fm.fileExists(atPath: plistPath) {
                    return URL(fileURLWithPath: currentPath)
                }
            }
            let parent = current.deletingLastPathComponent
            if parent.isEmpty || parent == currentPath { return nil }
            currentPath = parent
        }
    }
}


