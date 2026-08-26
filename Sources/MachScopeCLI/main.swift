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
    var assessment: Bool = false
    var bundleMainsOnly: Bool = false
}

func printUsage() {
    let usage = """
    Usage:
      machscope scan <PATH> [--format html|json|both] [--out DIR] [--rules FILE] [--exclude PATHS] [--max-depth N] [--follow-symlinks] [--concurrency N] [--verbose]
      machscope quick <PATH>
      machscope rules [--rules FILE]
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
        case "--assessment": config.assessment = true
        case "--bundle-mains-only": config.bundleMainsOnly = true
        default: break
        }
    }
}

func loadRules(at path: String?) -> RulesEngine {
    guard let path else { return RulesEngine.loadDefault() }
    do {
        return try RulesEngine.load(fromFilePath: path)
    } catch {
        fputs("error: \(error)\n", stderr)
        exit(2)
    }
}

var args = CommandLine.arguments.dropFirst()[...]
guard let sub = args.first else { printUsage(); exit(1) }
_ = args.removeFirst()

switch sub {
case "--version":
    print(MachScopeVersion.current)
case "rules":
    var config = CLIConfig()
    parseFlags(&args, into: &config)
    let engine = loadRules(at: config.rulesPath)
    for rule in engine.rules {
        print("\(rule.id)\t\(rule.severity.rawValue)\t\(rule.weight)\t\(rule.matchSummary)")
    }
case "quick":
    guard let path = args.first else { printUsage(); exit(1) }
    var config = CLIConfig()
    _ = args.dropFirst() // path consumed
    parseFlags(&args, into: &config)
    let root = URL(fileURLWithPath: path)
    let startedAt = Date()
    let files = FileWalker().enumeratePaths(options: .init(root: root, excludes: ["/System", "/Library"], maxDepth: 8, followSymlinks: config.followSymlinks))
    if config.verbose { fputs("Found \(files.count) files. Scanning with concurrency=8...\n", stderr) }
    let rulesEngine = loadRules(at: config.rulesPath)
    let records = Scanner(rulesEngine: rulesEngine).scan(urls: files, concurrency: 8)
    let durationMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
    if config.verbose { fputs("Scan completed in \(String(format: "%.2f", Double(durationMs) / 1_000))s\n", stderr) }
    switch config.format.lowercased() {
    case "json":
        let report = ScanReport(
            root: root.path,
            startedAt: startedAt,
            durationMs: durationMs,
            filesSeen: files.count,
            rulesDigest: rulesEngine.digest,
            records: records
        )
        let data = try JSONWriter().write(report: report)
        if let out = config.outDir {
            try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
            try data.write(to: URL(fileURLWithPath: out).appendingPathComponent("report.json"))
        } else {
            FileHandle.standardOutput.write(data)
        }
    default:
        let html = HTMLReport().render(records: records)
        if let out = config.outDir {
            try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
            try html.data(using: .utf8)!.write(to: URL(fileURLWithPath: out).appendingPathComponent("report.html"))
        } else {
            print(html)
        }
    }
case "scan":
    guard let path = args.first else { printUsage(); exit(1) }
    _ = args.removeFirst()
    var config = CLIConfig()
    parseFlags(&args, into: &config)
    if config.format == "both" && config.outDir == nil {
        fputs("error: --format both requires --out DIR\n", stderr)
        exit(2)
    }
    if config.assessment {
        fputs("Assessment is unavailable; see docs/adr/0003-assessment-is-disabled-until-the-bridge-is-correct.md.\n", stderr)
    }
    let root = URL(fileURLWithPath: path)
    let startedAt = Date()
    let files = FileWalker().enumeratePaths(options: .init(root: root, excludes: config.exclude, maxDepth: config.maxDepth, followSymlinks: config.followSymlinks, bundleMainsOnly: config.bundleMainsOnly))
    let rulesEngine = loadRules(at: config.rulesPath)
    if config.verbose {
        fputs("Found \(files.count) files. Scanning with concurrency=\(config.concurrency)...\n", stderr)
    }
    let records = Scanner(rulesEngine: rulesEngine).scan(urls: files, concurrency: config.concurrency)
    let durationMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
    if config.verbose {
        fputs("Scan completed in \(String(format: "%.2f", Double(durationMs) / 1_000))s\n", stderr)
    }
    let report = ScanReport(
        root: root.path,
        startedAt: startedAt,
        durationMs: durationMs,
        filesSeen: files.count,
        rulesDigest: rulesEngine.digest,
        records: records
    )
    switch config.format {
    case "json":
        let data = try JSONWriter().write(report: report)
        if let out = config.outDir {
            try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
            try data.write(to: URL(fileURLWithPath: out).appendingPathComponent("report.json"))
        } else {
            FileHandle.standardOutput.write(data)
        }
    case "html":
        let html = HTMLReport().render(records: records)
        if let out = config.outDir {
            try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
            try html.data(using: .utf8)!.write(to: URL(fileURLWithPath: out).appendingPathComponent("report.html"))
        } else {
            print(html)
        }
    default:
        // both
        let data = try JSONWriter().write(report: report)
        let html = HTMLReport().render(records: records)
        if let out = config.outDir {
            try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
            try data.write(to: URL(fileURLWithPath: out).appendingPathComponent("report.json"))
            try html.data(using: .utf8)!.write(to: URL(fileURLWithPath: out).appendingPathComponent("report.html"))
        }
    }
default:
    printUsage(); exit(1)
}


