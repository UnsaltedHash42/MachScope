# MachScope

A high-performance macOS security scanner that audits Mach-O binaries and app bundles for potentially dangerous entitlements and configurations.

## Features

- **Native Security Framework Integration**: Direct use of Apple's Security.framework APIs for maximum performance
- **Comprehensive Analysis**: Extracts entitlements, Team ID, signature flags, certificate chains, and notarization status
- **Security Risk Assessment**: Built-in rules engine identifies dangerous entitlement combinations
- **Multiple Output Formats**: JSON for automation, self-contained HTML for reporting
- **High Performance**: Concurrent scanning with configurable worker pools
- **Zero Dependencies**: No external tools required (no codesign/spctl subprocesses)

## Installation

### Prerequisites

- macOS 13.0 (Ventura) or later
- Xcode Command Line Tools or Xcode 15+

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/MachScope.git
cd MachScope

# Build the release version
make release

# Install to /usr/local/bin (requires sudo)
make install
```

### Homebrew (Coming Soon)

```bash
brew tap yourusername/machscope
brew install machscope
```

## Quick Start

```bash
# Quick scan of /Applications with HTML report
machscope quick /Applications

# JSON output for automation
machscope quick /Applications --json > report.json

# Detailed scan with custom options
machscope scan /Applications \
  --format both \
  --output ./reports \
  --exclude "/System,/Library" \
  --concurrency 8
```

## Usage

### Commands

#### `machscope quick [PATH]`
Performs a quick scan with default settings.

Options:
- `--json, -j`: Output JSON instead of HTML

#### `machscope scan PATH`
Performs a detailed scan with customizable options.

Options:
- `--format, -f`: Output format (html, json, or both)
- `--output, -o`: Output directory
- `--rules`: Custom rules file (YAML)
- `--exclude`: Comma-separated paths to exclude
- `--max-depth`: Maximum directory traversal depth
- `--follow-symlinks`: Follow symbolic links
- `--concurrency, -c`: Number of concurrent workers
- `--verbose, -v`: Enable verbose output

## Security Findings

MachScope identifies various security-relevant configurations:

### Critical Severity
- **Get Task Allow**: Allows debugger attachment in production builds
- **Multiple Disabled Protections**: Combination of weakened security boundaries

### High Severity
- **Disabled Library Validation**: Can load unsigned libraries
- **DYLD Environment Variables**: Accepts dynamic linker manipulation
- **JIT Compilation**: Can execute dynamically generated code
- **Unsigned Executable Memory**: Can create executable memory without signing

### Medium Severity
- **Missing Hardened Runtime**: Not compiled with runtime protections
- **Not Notarized**: Binary hasn't been notarized by Apple

## Output Formats

### JSON Format
Machine-readable format suitable for automation and SIEM ingestion:

```json
{
  "path": "/Applications/Example.app/Contents/MacOS/Example",
  "bundle_id": "com.example.app",
  "team_id": "ABC123",
  "hardened_runtime": true,
  "entitlements": {
    "com.apple.security.cs.allow-jit": true
  },
  "findings": [
    {
      "id": "ALLOW-JIT",
      "severity": "high",
      "reason": "Enables just-in-time compilation"
    }
  ]
}
```

### HTML Report
Self-contained HTML file with:
- Sortable and filterable results
- Severity badges and color coding
- Grouping by Team ID and Bundle ID
- Search functionality
- No external dependencies

## Development

### Project Structure
```
MachScope/
├── Sources/
│   ├── MachScopeCLI/        # Command-line interface
│   └── MachScopeCore/       # Core scanning library
├── Tests/                   # Unit and integration tests
├── Package.swift            # Swift Package Manager config
└── Makefile                 # Build automation
```

### Building and Testing
```bash
# Build debug version
make build

# Run tests
make test

# Run tests with coverage
make test-coverage

# Format code (requires swift-format)
make format

# Lint code (requires SwiftLint)
make lint
```

### Contributing
Please read the development documentation in `.docs/` for guidelines on:
- Code conventions (`.docs/conventions/swift-conventions.md`)
- Task tracking (`.docs/Task_List.md`)
- Design decisions (`.docs/Design.md`)

## Performance

Typical performance on Apple Silicon Macs:
- `/Applications` directory: < 2 minutes
- Memory usage: < 500MB
- Concurrent workers: 8 (configurable)

## Security & Privacy

- **Read-only operations**: Never modifies or executes scanned binaries
- **Local-only**: No network connections or data collection
- **No telemetry**: Your scan results stay on your machine

## Limitations

- Requires macOS 13+ (Security.framework APIs)
- Cannot scan System Integrity Protection (SIP) protected files without Full Disk Access
- Some entitlements may require additional privileges to read

## License

[License information to be added]

## Acknowledgments

- Inspired by tools like [Taccy](https://github.com/objective-see/Taccy) and [WhatsYourSign](https://github.com/objective-see/WhatsYourSign)
- Built with Apple's Security.framework
- Uses Swift Argument Parser for CLI

## Support

For issues, questions, or contributions, please visit the [GitHub repository](https://github.com/yourusername/MachScope).