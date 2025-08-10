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
    print("[stub] Quick scan of \(path). HTML report will be generated in current directory.")
case "scan":
    guard let path = args.first else { printUsage(); exit(1) }
    _ = args.removeFirst()
    var config = CLIConfig()
    parseFlags(&args, into: &config)
    print("[stub] Scan path=\(path) format=\(config.format) out=\(config.outDir ?? ".") rules=\(config.rulesPath ?? "default") exclude=\(config.exclude) maxDepth=\(config.maxDepth) followSymlinks=\(config.followSymlinks) concurrency=\(config.concurrency) verbose=\(config.verbose)")
default:
    printUsage(); exit(1)
}


