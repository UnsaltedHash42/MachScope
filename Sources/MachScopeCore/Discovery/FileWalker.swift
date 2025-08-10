import Foundation

public struct FileWalker {
    public struct Options {
        public let root: URL
        public let excludes: [String]
        public let maxDepth: Int
        public let followSymlinks: Bool

        public init(root: URL, excludes: [String] = [], maxDepth: Int = .max, followSymlinks: Bool = false) {
            self.root = root
            self.excludes = excludes
            self.maxDepth = maxDepth
            self.followSymlinks = followSymlinks
        }
    }

    public init() {}

    public func enumeratePaths(options: Options) -> [URL] {
        let fm = FileManager.default
        var results: [URL] = []

        func isExcluded(_ path: String) -> Bool {
            guard !options.excludes.isEmpty else { return false }
            for ex in options.excludes {
                if path.hasPrefix(ex) { return true }
                if path.contains(ex) { return true }
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

            guard let e = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey], options: [.skipsHiddenFiles], errorHandler: nil) else { return }
            for case let child as URL in e {
                let childPath = child.path
                if isExcluded(childPath) { e.skipDescendants(); continue }
                if let vals = try? child.resourceValues(forKeys: [.isSymbolicLinkKey, .isDirectoryKey]) {
                    if vals.isSymbolicLink == true && !options.followSymlinks {
                        e.skipDescendants();
                        continue
                    }
                    if vals.isDirectory == true {
                        let relDepth = child.pathComponents.count - url.pathComponents.count
                        if relDepth > options.maxDepth {
                            e.skipDescendants();
                            continue
                        }
                    } else {
                        results.append(child)
                    }
                }
            }
        }

        walk(options.root, depth: 0)
        return results
    }
}


