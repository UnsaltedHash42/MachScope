# MachScope

MachScope is a macOS command-line tool that audits Mach-O binaries and app bundles for dangerous entitlements and code-signing settings. It reads Security.framework directly and does not run `codesign` or `spctl`.

MachScope reports what a signature claims. It does not call `SecStaticCodeCheckValidity`, verify the code seal, or prove that a signature is valid.

Notarization is not reported in v1.0. `--assessment` is accepted but disabled because the old bridge called the wrong private API and confused a local Gatekeeper policy verdict with a stapled notarization ticket. See [ADR-0003](docs/adr/0003-assessment-is-disabled-until-the-bridge-is-correct.md).

## Requirements

- macOS 13 or later
- Swift 5.10 or later
- Xcode Command Line Tools or Xcode

## Build and test

```sh
make build
make test
.build/release/machscope --help
```

`make build` creates a release build at `.build/release/machscope`. The Makefile also provides `make run`, which runs a quick scan of `/Applications`.

## Usage

```text
machscope scan <PATH> [OPTIONS]
machscope quick <PATH> [OPTIONS]
machscope rules [--rules FILE]
machscope --help
machscope --version
```

Both `scan` and `quick` default to JSON and use eight workers. `quick` also excludes `/System` and `/Library` and limits traversal to depth 8. The two commands otherwise use the same parser and scan path.

```sh
.build/release/machscope quick /Applications --format json > /tmp/machscope.json
.build/release/machscope scan /bin/ls --format html --out /tmp/machscope-report
.build/release/machscope rules
```

### Scan options

| Option | Meaning |
|---|---|
| `--format html\|json\|both` | Select the output format. Default: `json`. `both` requires `--out`. |
| `--out DIR` | Write `report.json`, `report.html`, or both to a directory. |
| `--rules FILE` | Load a custom YAML ruleset. A missing or malformed ruleset is a usage error. |
| `--exclude PATHS` | Exclude comma-separated path prefixes or whole path components. |
| `--max-depth N` | Limit directory traversal depth. |
| `--concurrency N` | Set the worker count. Default: 8. |
| `--fail-on SEVERITY` | Exit 1 for a finding at or above `low`, `medium`, `high`, or `critical`. |
| `--assessment` | Accept the disabled assessment request and explain it on stderr. |
| `--bundle-mains-only` | Scan only the main executable in each app bundle. |
| `--verbose` | Write progress to stderr every 500 records or two seconds. |
| `--help` | Print usage. |

Directory scans never follow symbolic links. A bad binary produces a record with entries in `errors`; it does not stop the batch.

### Exit codes

| Code | Meaning |
|---:|---|
| 0 | The scan completed and no finding met the requested `--fail-on` threshold. |
| 1 | The scan completed and at least one finding met or exceeded `--fail-on`. |
| 2 | Usage error, including an unknown flag, a missing argument, or an invalid ruleset. |
| 3 | Scan error because the root does not exist or cannot be read. |

Without `--fail-on`, findings do not change the exit code. A record-level extraction error also does not produce exit 3.

## JSON contract

JSON output is an envelope with `schema_version`, `tool`, `scan`, and `records`.

- Keys use `snake_case` at every depth.
- An absent optional field means unknown. MachScope does not emit explicit `null` values.
- `records` is sorted by UTF-8 path bytes.
- `schema_version` changes only for a breaking contract change. Additive fields do not change it.
- `scan.rules_digest` is the SHA-256 digest of the loaded ruleset. It ties a finding set and its scores to that ruleset.
- stdout contains only the selected report. Progress and warnings go to stderr.

This is the output of `.build/release/machscope scan /bin/ls --format json` on the benchmark host:

```json
{
  "records" : [
    {
      "arch" : [
        "x86_64",
        "arm64e"
      ],
      "binary_type" : "exec",
      "cdhash" : "7640f65d2a51ab03a93df1917c7449ed3d3a0b2e",
      "certificate_chain" : [
        {
          "sha256" : "1ee9d45f25111c924aa3ad69f3fffe5da5ac3691bbb2a1a48d85fad1863eade1",
          "subject" : "macOS Software Signing"
        },
        {
          "sha256" : "76843e4c6e3acb216134a57ba8aff512e394672b3966b996da80f009ee7b4645",
          "subject" : "Apple Code Signing Certification Authority"
        },
        {
          "sha256" : "b0b1730ecbc7ff4505142c49f1295e6eda6bcaed7e2c68c5be91b5a11001f024",
          "subject" : "Apple Root CA"
        }
      ],
      "developer_type" : "Unknown",
      "entitlements" : {

      },
      "errors" : [

      ],
      "findings" : [
        {
          "id" : "NO_HARDENED_RUNTIME",
          "reason" : "Hardened Runtime not enabled",
          "severity" : "medium"
        }
      ],
      "format" : "Mach-O universal (x86_64 arm64e)",
      "hardened_runtime" : false,
      "has_quarantine_xattr" : false,
      "path" : "\/bin\/ls",
      "platform_binary" : true,
      "risk_band" : "low",
      "risk_score" : 5,
      "signature_flags" : [

      ],
      "signing_authorities" : [
        "macOS Software Signing",
        "Apple Code Signing Certification Authority",
        "Apple Root CA"
      ],
      "signing_identifier" : "com.apple.ls"
    }
  ],
  "scan" : {
    "duration_ms" : 2,
    "files_seen" : 1,
    "records" : 1,
    "root" : "\/bin\/ls",
    "rules_digest" : "sha256:903a6f7c3e3ee825247fcfa405f89fc8694e7f47c16031ec939f328ac8cd9d45",
    "started_at" : "2026-08-26T22:15:27Z"
  },
  "schema_version" : 1,
  "tool" : {
    "name" : "machscope",
    "version" : "1.0.0"
  }
}
```

## HTML reports

HTML output is a self-contained table with severity badges. Click a supported column header to sort it. It has no filtering, grouping, or search controls.

## Rules and scoring

The packaged YAML ruleset is the only source of findings. `machscope rules` lists each rule's ID, severity, weight, and match. Scores are derived from the findings and capped at 100; they are a sort key, not a malware verdict.

## Performance

On an Apple M5 Max running macOS 26.5, a release build scanned 940 records under `/Applications` in a median 4.34 seconds with `--concurrency 8` across five runs. Security.framework calls are capped at four under [ADR-0004](docs/adr/0004-the-security-api-cap-is-four.md); `--concurrency` values above four do not change throughput measurably.

## Limits

- MachScope reads only files that the current user can access.
- It does not validate signatures or code seals.
- It does not report notarization in v1.0.
- It does not follow symbolic links.

## License

[MIT](LICENSE)
