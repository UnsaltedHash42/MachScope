import Foundation

public struct FileWalker {
    public struct Options {
        public let root: URL
        public let excludes: [String]
        public let maxDepth: Int
        public let bundleMainsOnly: Bool

        public init(root: URL, excludes: [String] = [], maxDepth: Int = .max, bundleMainsOnly: Bool = false) {
            self.root = root
            self.excludes = excludes
            self.maxDepth = maxDepth
            self.bundleMainsOnly = bundleMainsOnly
        }
    }

    public init() {}

    public func enumeratePaths(options: Options) -> [URL] {
        let fm = FileManager.default
        var results: [URL] = []

        func isExcluded(_ path: String) -> Bool {
            guard !options.excludes.isEmpty else { return false }
            let components = path.split(separator: "/")
            for ex in options.excludes {
                let normalized = ex.count > 1 && ex.hasSuffix("/")
                    ? String(ex.dropLast())
                    : ex
                if normalized.isEmpty { continue }
                if path == normalized || path.hasPrefix(normalized + "/") {
                    return true
                }
                if !normalized.contains("/"),
                   components.contains(where: { $0 == normalized }) {
                    return true
                }
            }
            return false
        }

        func walk(_ url: URL, depth: Int) {
            guard depth <= options.maxDepth else { return }
            let path = url.path
            if isExcluded(path) { return }

            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return }

            if !isDir.boolValue {
                results.append(url)
                return
            }

            // If scanning bundle mains only and current is an .app bundle, add its main executable and skip descending
            if options.bundleMainsOnly, url.pathExtension.lowercased() == "app" {
                if let mainExec = mainExecutable(inAppBundle: url) {
                    results.append(mainExec)
                }
                return
            }

            guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isRegularFileKey], options: [.skipsHiddenFiles], errorHandler: nil) else { return }
            for case let child as URL in e {
                let childPath = child.path
                if isExcluded(childPath) { e.skipDescendants(); continue }
                if let vals = try? child.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey, .isRegularFileKey]) {
                    if vals.isSymbolicLink == true {
                        e.skipDescendants();
                        continue
                    }
                    if vals.isDirectory == true {
                        if options.bundleMainsOnly, child.pathExtension.lowercased() == "app" {
                            if let mainExec = mainExecutable(inAppBundle: child) {
                                results.append(mainExec)
                            }
                            e.skipDescendants();
                            continue
                        }
                        let relDepth = child.pathComponents.count - url.pathComponents.count
                        if relDepth > options.maxDepth {
                            e.skipDescendants();
                            continue
                        }
                    } else {
                        // Only include probable Mach-O regular files
                        if vals.isRegularFile == true && MachOMagic().isMachO(child) {
                            results.append(child)
                        }
                    }
                }
            }
        }

        walk(options.root, depth: 0)
        return results
    }

    private func mainExecutable(inAppBundle appURL: URL) -> URL? {
        let plistURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let dict = NSDictionary(contentsOf: plistURL) as? [String: Any],
              let execName = dict["CFBundleExecutable"] as? String else { return nil }
        let execURL = appURL.appendingPathComponent("Contents/MacOS/").appendingPathComponent(execName)
        return FileManager.default.fileExists(atPath: execURL.path) ? execURL : nil
    }
}


