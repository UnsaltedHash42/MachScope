import Foundation
import MachScopeCore

struct CLIConfig {
    var format = "json"
    var outDir: String?
    var rulesPath: String?
    var exclude: [String] = []
    var maxDepth: Int = .max
    var concurrency = 8
    var verbose = false
    var assessment = false
    var bundleMainsOnly = false
    var failOn: Finding.Severity?
    var help = false
}

enum CLIError: Error, CustomStringConvertible {
    case usage(String)
    case scan(String)

    var description: String {
        switch self {
        case .usage(let message), .scan(let message): message
        }
    }

    var exitCode: Int32 {
        switch self {
        case .usage: 2
        case .scan: 3
        }
    }
}

let usage = """
Usage:
  machscope scan <PATH> [OPTIONS]
  machscope quick <PATH> [OPTIONS]
  machscope rules [--rules FILE]
  machscope --help
  machscope --version

Scan options:
  --format html|json|both      Output format (default: json)
  --out DIR                    Write report.json, report.html, or both to DIR
  --rules FILE                 Load a custom YAML ruleset
  --exclude PATHS              Exclude comma-separated path prefixes or components
  --max-depth N                Limit directory traversal depth
  --concurrency N              Set scanner worker count (default: 8)
  --fail-on SEVERITY           Exit 1 for low, medium, high, or critical findings
  --assessment                 Accept the disabled notarization assessment request
  --bundle-mains-only          Scan only the main executable in each app bundle
  --verbose                    Write interval progress to stderr
  --help                       Show this help

Quick defaults:
  Excludes /System and /Library, limits depth to 8, and uses JSON with 8 workers.

Exit codes:
  0  Scan completed below the requested threshold
  1  A finding met or exceeded --fail-on
  2  Usage or ruleset error
  3  Root scan error
"""

func printUsage(to stream: UnsafeMutablePointer<FILE>) {
    fputs(usage + "\n", stream)
}

func value(for flag: String, from args: inout ArraySlice<String>) throws -> String {
    guard let value = args.first, !value.hasPrefix("--") else {
        throw CLIError.usage("\(flag) requires a value")
    }
    _ = args.removeFirst()
    return value
}

func parseFlags(_ args: inout ArraySlice<String>, into config: inout CLIConfig) throws {
    while let flag = args.first {
        _ = args.removeFirst()
        guard flag.hasPrefix("--") else {
            throw CLIError.usage("unexpected argument: \(flag)")
        }
        switch flag {
        case "--format":
            config.format = try value(for: flag, from: &args).lowercased()
        case "--out":
            config.outDir = try value(for: flag, from: &args)
        case "--rules":
            config.rulesPath = try value(for: flag, from: &args)
        case "--exclude":
            config.exclude = try value(for: flag, from: &args)
                .split(separator: ",")
                .map(String.init)
        case "--max-depth":
            let raw = try value(for: flag, from: &args)
            guard let depth = Int(raw), depth >= 0 else {
                throw CLIError.usage("invalid --max-depth: \(raw)")
            }
            config.maxDepth = depth
        case "--concurrency":
            let raw = try value(for: flag, from: &args)
            guard let concurrency = Int(raw), concurrency > 0 else {
                throw CLIError.usage("invalid --concurrency: \(raw)")
            }
            config.concurrency = concurrency
        case "--fail-on":
            let raw = try value(for: flag, from: &args).lowercased()
            guard let severity = Finding.Severity(rawValue: raw) else {
                throw CLIError.usage("invalid --fail-on severity: \(raw)")
            }
            config.failOn = severity
        case "--verbose":
            config.verbose = true
        case "--assessment":
            config.assessment = true
        case "--bundle-mains-only":
            config.bundleMainsOnly = true
        case "--help":
            config.help = true
        default:
            throw CLIError.usage("unknown flag: \(flag)")
        }
    }
}

func parseRulesFlags(_ args: inout ArraySlice<String>) throws -> (rulesPath: String?, help: Bool) {
    var rulesPath: String?
    var help = false
    while let flag = args.first {
        _ = args.removeFirst()
        switch flag {
        case "--rules":
            rulesPath = try value(for: flag, from: &args)
        case "--help":
            help = true
        default:
            throw CLIError.usage("unknown flag: \(flag)")
        }
    }
    return (rulesPath, help)
}

func loadRules(at path: String?) throws -> RulesEngine {
    guard let path else { return RulesEngine.loadDefault() }
    do {
        return try RulesEngine.load(fromFilePath: path)
    } catch {
        throw CLIError.usage("unable to load ruleset: \(error)")
    }
}

func severityRank(_ severity: Finding.Severity) -> Int {
    switch severity {
    case .low: 0
    case .medium: 1
    case .high: 2
    case .critical: 3
    }
}

func write(_ data: Data, named filename: String, to outDir: String?) throws {
    if let outDir {
        try FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        try data.write(to: URL(fileURLWithPath: outDir).appendingPathComponent(filename))
    } else {
        FileHandle.standardOutput.write(data)
    }
}

func runScan(path: String, config: CLIConfig) throws -> Int32 {
    let rulesEngine = try loadRules(at: config.rulesPath)
    let root = URL(fileURLWithPath: path).standardizedFileURL
    guard FileManager.default.fileExists(atPath: root.path) else {
        throw CLIError.scan("root does not exist: \(path)")
    }
    guard FileManager.default.isReadableFile(atPath: root.path) else {
        throw CLIError.scan("root is not readable: \(path)")
    }
    if config.assessment {
        fputs("Assessment is unavailable; see docs/adr/0003-assessment-is-disabled-until-the-bridge-is-correct.md.\n", stderr)
    }

    let startedAt = Date()
    let files = FileWalker().enumeratePaths(options: .init(
        root: root,
        excludes: config.exclude,
        maxDepth: config.maxDepth,
        bundleMainsOnly: config.bundleMainsOnly
    ))
    if config.verbose {
        fputs("Found \(files.count) files. Scanning with concurrency=\(config.concurrency)...\n", stderr)
    }
    let progress: ((Int, Int) -> Void)? = config.verbose ? { completed, total in
        fputs("Scanned \(completed)/\(total) records...\n", stderr)
    } : nil
    let records = Scanner(rulesEngine: rulesEngine).scan(
        urls: files,
        concurrency: config.concurrency,
        progress: progress
    )
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
        try write(try JSONWriter().write(report: report), named: "report.json", to: config.outDir)
    case "html":
        try write(Data(HTMLReport().render(records: records).utf8), named: "report.html", to: config.outDir)
    case "both":
        let outDir = config.outDir
        try write(try JSONWriter().write(report: report), named: "report.json", to: outDir)
        try write(Data(HTMLReport().render(records: records).utf8), named: "report.html", to: outDir)
    default:
        throw CLIError.usage("invalid --format: \(config.format)")
    }

    guard let threshold = config.failOn else { return 0 }
    let thresholdRank = severityRank(threshold)
    return records.contains { record in
        record.findings.contains {
            $0.classification == .weakening
                && severityRank($0.severity) >= thresholdRank
        }
    } ? 1 : 0
}

func run() throws -> Int32 {
    var args = CommandLine.arguments.dropFirst()[...]
    guard let command = args.first else {
        printUsage(to: stderr)
        return 2
    }
    _ = args.removeFirst()

    switch command {
    case "--help":
        print(usage)
        return 0
    case "--version":
        guard args.isEmpty else {
            throw CLIError.usage("unexpected argument: \(args.first!)")
        }
        print(MachScopeVersion.current)
        return 0
    case "rules":
        let parsed = try parseRulesFlags(&args)
        if parsed.help {
            print(usage)
            return 0
        }
        let engine = try loadRules(at: parsed.rulesPath)
        for rule in engine.rules {
            print("\(rule.id)\t\(rule.severity.rawValue)\t\(rule.weight)\t\(rule.matchSummary)")
        }
        return 0
    case "scan", "quick":
        if args.first == "--help" {
            print(usage)
            return 0
        }
        guard let path = args.first, !path.hasPrefix("--") else {
            throw CLIError.usage("missing path for \(command)")
        }
        _ = args.removeFirst()
        var config = CLIConfig()
        if command == "quick" {
            config.exclude = ["/System", "/Library"]
            config.maxDepth = 8
        }
        try parseFlags(&args, into: &config)
        if config.help {
            print(usage)
            return 0
        }
        guard ["html", "json", "both"].contains(config.format) else {
            throw CLIError.usage("invalid --format: \(config.format)")
        }
        if config.format == "both", config.outDir == nil {
            throw CLIError.usage("--format both requires --out DIR")
        }
        return try runScan(path: path, config: config)
    default:
        throw CLIError.usage("unknown command: \(command)")
    }
}

do {
    exit(try run())
} catch let error as CLIError {
    fputs("error: \(error)\n", stderr)
    exit(error.exitCode)
} catch {
    fputs("error: \(error)\n", stderr)
    exit(3)
}
