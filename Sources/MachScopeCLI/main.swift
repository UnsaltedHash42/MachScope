import Foundation
import MachScopeCore

struct CLIConfig {
    var format: String = "both" // html|json|both
    var outDir: String? = nil
    var rulesPath: String? = nil
    var exclude: [String] = []
    var maxDepth: Int = .max
    var followSymlinks: Bool = false
    var concurrency: Int = 8
    var verbose: Bool = false
}

func printUsage() {
    let usage = """
    Usage:
      machscope scan <PATH> [--format html|json|both] [--out DIR] [--rules FILE] [--exclude PATHS] [--max-depth N] [--follow-symlinks] [--concurrency N] [--verbose]
      machscope quick <PATH>
    """
    print(usage)
}

func parseFlags(_ args: inout ArraySlice<String>, into config: inout CLIConfig) {
    while let flag = args.first, flag.hasPrefix("--") {
        _ = args.removeFirst()
        switch flag {
        case "--format": if let v = args.first { config.format = v; _ = args.removeFirst() }
        case "--out": if let v = args.first { config.outDir = v; _ = args.removeFirst() }
        case "--rules": if let v = args.first { config.rulesPath = v; _ = args.removeFirst() }
        case "--exclude": if let v = args.first { config.exclude = v.split(separator: ",").map(String.init); _ = args.removeFirst() }
        case "--max-depth": if let v = args.first, let n = Int(v) { config.maxDepth = n; _ = args.removeFirst() }
        case "--follow-symlinks": config.followSymlinks = true
        case "--concurrency": if let v = args.first, let n = Int(v) { config.concurrency = n; _ = args.removeFirst() }
        case "--verbose": config.verbose = true
        default: break
        }
    }
}

var args = CommandLine.arguments.dropFirst()[...]
guard let sub = args.first else { printUsage(); exit(1) }
_ = args.removeFirst()

switch sub {
case "quick":
    guard let path = args.first else { printUsage(); exit(1) }
    var config = CLIConfig()
    config.format = "html"
    let root = URL(fileURLWithPath: path)
    let files = FileWalker().enumeratePaths(options: .init(root: root, excludes: ["/System", "/Library"], maxDepth: 8, followSymlinks: false))
    let extractor = SignInfoExtractor()
    let records = files.map { extractor.buildRecord(for: $0) }
    let html = HTMLReport().render(records: records)
    print(html)
case "scan":
    guard let path = args.first else { printUsage(); exit(1) }
    _ = args.removeFirst()
    var config = CLIConfig()
    parseFlags(&args, into: &config)
    let root = URL(fileURLWithPath: path)
    let files = FileWalker().enumeratePaths(options: .init(root: root, excludes: config.exclude, maxDepth: config.maxDepth, followSymlinks: config.followSymlinks))
    let extractor = SignInfoExtractor()
    let records = files.map { extractor.buildRecord(for: $0) }
    switch config.format {
    case "json":
        let data = try JSONWriter().write(records: records)
        FileHandle.standardOutput.write(data)
    case "html":
        let html = HTMLReport().render(records: records)
        print(html)
    default:
        // both
        let data = try JSONWriter().write(records: records)
        print(String(data: data, encoding: .utf8) ?? "{}")
        let html = HTMLReport().render(records: records)
        print("\n\n--- HTML ---\n\n")
        print(html)
    }
default:
    printUsage(); exit(1)
}


