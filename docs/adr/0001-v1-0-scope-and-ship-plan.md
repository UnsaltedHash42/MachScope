# ADR-0001: MachScope v1.0 scope and ship plan

Status: Accepted
Date: 2026-08-26
Owner: UnsaltedHash42

## Context

MachScope is 1056 lines of Swift that audits Mach-O binaries and app bundles for dangerous
entitlements and code-signing configurations, using Security.framework directly rather than
shelling out to `codesign` or `spctl`. It is the first public release in a macOS tradecraft
suite, and its JSON output is meant to be consumed by a downstream bounty harness — so the
output shape becomes an API the moment v1.0 is tagged.

A recon pass on 2026-08-26 measured the tree against `codesign` ground truth on this
workstation (macOS 26.5, Swift 6.3.3, Command Line Tools only). Fifteen defects were verified
by running, not by reading. The load-bearing ones:

**The core extraction returns nothing.** `machscope scan
/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder --format json` reports
`"entitlements": {}`. `codesign -d --entitlements -` on the same binary returns 98 keys. A
probe against `SecCodeCopySigningInformation` shows the dictionary does carry them, under the
key `entitlements-dict`. `Entitlements.fromSigningInfo` looks for `entitlements`,
`Entitlements`, and `kSecCodeInfoEntitlementsDict` — none of which match. (`entitlements` does
exist, but it is the raw plist as `CFData`, so the `as? [String: Any]` cast fails and the
function falls through to empty.) **Every entitlement finding the tool can produce is
currently unreachable.**

Three more fields are dead for the same class of reason:

- `signature_flags` is empty for Finder, whose `flags` value is `8192` (`0x2000`,
  `CS_REQUIRE_LV`). `Flags.swift` maps four bits and gets one of them wrong: it declares
  `CS_RESTRICT = 0x8`, which is actually `CS_INSTALLER`; the real `CS_RESTRICT` is `0x800`.
  Google Chrome signs with `0x12a00` (`kill,restrict,library-validation,runtime`) and MachScope
  would report `runtime` alone.
- `signing_authorities` is always `[]`. The code reads `signInfo["authority"]`; no such key
  exists in the returned dictionary under any flag combination (verified across
  `kSecCSSigningInformation`, `|kSecCSRequirementInformation`, and `|kSecCSInternalInformation
  |kSecCSContentInformation`).
- `certificate_chain` is always `[]`. The code casts elements of `certificates` — an array of
  `SecCertificateRef` — to `[String: Any]`, which never succeeds.
  `SecBridge.copyCertificateSummariesForPath:` already does this correctly and is never called
  from Swift.

**The JSON contract disagrees with itself three ways.** The encoder emits camelCase
(`bundleId`, `teamId`). `README.md` documents snake_case (`bundle_id`, `team_id`). The golden
fixture `Tests/MachScopeCoreTests/Golden/example.json` also uses snake_case — and is never
compared: `GoldenOutputTests` asserts that two keys exist and never opens the file. Had it
been compared, it would have failed since the day it was written. The top level is a bare
array, so nothing in an output file identifies which MachScope or which ruleset produced it.
`certificate_chain[].sha256` is not a SHA-256; it is the first 64 bytes of
`SecCertificateCopyNormalizedSubjectSequence`, hex-encoded (`SecBridge.m:73-81`).

**Rules live in two places, and both fire.** Five entitlements are checked in
`RulesEngine.evaluate` with stable IDs (`DLV`, `DYLD_ENV`, `UNSIGNED_EXEC_MEM`, `ALLOW_JIT`,
`GET_TASK_ALLOW`) *and* in `DefaultRules.yml`, where the finding ID is the raw entitlement
string. With the default ruleset loaded, one JIT entitlement produces two findings under two
different IDs. `CLAUDE.md` states the opposite as a repo rule: "A new dangerous-entitlement
check is a rule, not an `if`." Combination rules (`JIT_AND_NETWORK`, `GTA_NO_HARDENED`) cannot
be expressed in YAML at all, so they have nowhere to go but the hardcoded block.

**Everything after `machscope quick <path>` is ignored.** `main.swift:53` calls
`args.dropFirst()` and discards the result; `ArraySlice.dropFirst()` is non-mutating, so the
path is still `args.first`, `parseFlags` sees a token that does not start with `--`, and
returns immediately. The README's own example, `machscope quick /Applications --json`, is wrong
twice over: the flag is never read, and `--json` is not a flag `parseFlags` knows in any case.
A `--rules` file that fails to load falls back to the defaults in silence
(`main.swift:59,87`).

**`make test` does not run.** `error: no such module 'XCTest'` — no Xcode on this box, and
Command Line Tools ships no `XCTest.framework`. See [ADR-0002](0002-tests-run-without-xcode.md).

Smaller, still contract-visible: entitlement values that are not booleans are silently dropped
(`Entitlements` is `[String: Bool]`), which discards exactly the interesting ones —
`keychain-access-groups`, `application-identifier`, the
`temporary-exception.files.absolute-path.*` arrays. `arm64e` is reported as `arm64` because
`mapCPUType` reads cputype and ignores cpusubtype. Record order is nondeterministic, so two
scans of one tree produce different JSON. `--concurrency 8` is throttled to 2 by
`SignInfoExtractor.secAPISem`, which guards the only expensive call, while the
`DispatchSemaphore(value: 1)` in `Assessment.assessExecution` is constructed per call and
serializes nothing. `FileWalker.isExcluded` matches with `contains`, so `--exclude /Library`
also drops `/Applications/Foo.app/Contents/Library/…`. There is no LICENSE file, and the
README's Contributing section points at `.docs/`, which `.gitignore` excludes.

The state of the tree is therefore: the plumbing is sound and the semantics are wrong. Nothing
here calls for a rewrite. It calls for a scoped correctness pass, a frozen output contract,
and a runnable test suite — in that order, because a golden test written against today's
output would enshrine the defects.

## Decision

**v1.0 is a correctness and contract release, not a feature release.** Seven workstreams ship.
Everything that reads as a new capability waits for v1.1.

### W1 — Extraction correctness

The record must say what `codesign -dv --entitlements -` says about the same binary.

- Entitlements come from `entitlements-dict`. A regression test asserts a non-empty dictionary
  for a binary known to carry entitlements.
- Entitlement values keep their type. The JSON value is the entitlement's actual value —
  boolean, string, number, or array of strings — not a boolean projection. Rules that test for
  presence still work; rules can now test a value.
- The `CS_*` flag table is complete and correct: `adhoc 0x2`, `get-task-allow 0x4`,
  `installer 0x8`, `forced-lv 0x10`, `invalid-allowed 0x20`, `hard 0x100`, `kill 0x200`,
  `check-expiration 0x400`, `restrict 0x800`, `enforcement 0x1000`, `library-validation
  0x2000`, `runtime 0x10000`, `linker-signed 0x20000`. Chrome's `0x12a00` must decode to four
  names.
- Authorities and the certificate chain come from `SecBridge.copyCertificateSummariesForPath:`,
  which already works. The field currently called `sha256` is either a real SHA-256 of the
  certificate DER or is renamed to what it is. It is not shipped under a name that lies.
- `arm64e` is distinguished from `arm64` by cpusubtype.
- `cdhash`, `platform_binary`, and the `format` string are added to the record. They are cheap
  (already in the dictionary) and they are what a triager asks for next.

### W2 — One place a rule lives

The hardcoded block in `RulesEngine.evaluate` is deleted. The YAML ruleset is the only source
of rules, and it grows the two things the hardcoded block could express and it could not:

- **Stable IDs.** Every rule declares an `id`. IDs are uppercase, underscore-separated, and
  never the raw entitlement string. They are part of the JSON contract: a consumer pins on
  `GET_TASK_ALLOW`, and that ID never changes meaning. A rule that is retired keeps its ID
  retired.
- **Combination rules.** A rule may match on more than one condition — several entitlements, a
  signature flag, an absent flag, an entitlement value. `JIT_AND_NETWORK` and `GTA_NO_HARDENED`
  become YAML like everything else.

A `--rules` file that fails to parse is a fatal error with the parse position, never a silent
fallback to the defaults. The hand-rolled line scanner is replaced by a parser that handles the
subset the schema actually needs and rejects what it does not understand rather than skipping
it.

`machscope rules` lists the loaded ruleset — ID, severity, weight, match — so a report's
findings can be traced to the rules that produced them.

### W3 — JSON contract v1

Frozen at v1.0 and additive-only afterward.

```json
{
  "schema_version": 1,
  "tool": { "name": "machscope", "version": "1.0.0" },
  "scan": {
    "root": "/Applications",
    "started_at": "2026-08-26T14:02:11Z",
    "duration_ms": 41822,
    "files_seen": 18402,
    "records": 1197,
    "rules_digest": "sha256:9f2c…"
  },
  "records": [ … ]
}
```

Rules that hold for the whole document:

- **Keys are snake_case.** Every key, at every depth.
- **`schema_version` is an integer** and bumps only on a breaking change. Adding a field is not
  a breaking change and does not bump it. Renaming, removing, or changing the type of a field
  is, and requires an ADR.
- **Absent means unknown.** An optional field is omitted when it has no value. Explicit `null`
  is never emitted, so a consumer has one case to handle, not two.
- **Records are sorted by `path`** before emit. Two scans of the same tree produce
  byte-identical JSON given the same ruleset and tool version. This is what makes a golden test
  possible and diffs meaningful.
- **`rules_digest` is a SHA-256 over the loaded ruleset**, so a score or a finding set is
  attributable to a specific ruleset, including a custom `--rules` file.
- **stdout carries JSON and nothing else.** Progress, timing, and warnings go to stderr, so
  `machscope scan … --format json | jq` works without a flag.

Record fields keep their current names, transliterated to snake_case, plus the W1 additions and
`risk_score` / `risk_band` from W4. `errors` stays: a file that fails extraction still produces
a record, with the reason in `errors`.

### W4 — Scoring is derived, published, and recomputable

A 1200-record scan needs a rank, and four severity words do not provide one. The score is
arithmetic over the findings, not a judgement layered on top of them:

- Each severity carries a base weight: `low 1`, `medium 5`, `high 15`, `critical 40`.
- A rule may override its weight with an explicit `weight:` in the ruleset.
- `risk_score` = `min(100, sum of the weights of that record's findings)`.
- `risk_band` = `none` at 0, `low` 1–9, `medium` 10–29, `high` 30–59, `critical` 60+.

Three properties are the point. The score is **reproducible** — a consumer holding `findings`
and the ruleset can recompute it and get the same number. It is **attributable** —
`rules_digest` says which weights produced it. And it is **advisory** — findings are the
product, the score is a sort key. Nothing in MachScope decides that a binary is malicious.

The weights are a starting position, not a calibration. They ship in the ruleset header where
they can be tuned, and a follow-up ADR revisits them after v1.0 is measured against a full
`/Applications` corpus.

### W5 — Batch scan

Enumeration and evaluation are separate phases. Enumeration is single-threaded and cheap;
evaluation is where the parallelism belongs.

- **Deterministic output.** Results are collected with their input index and sorted by path
  before emit (see W3).
- **Honest concurrency.** `--concurrency N` either means N or the cap is documented. The
  `secAPISem(2)` gate is not removed on faith: W5 requires a measured run over `/Applications`
  at caps 2, 4, 8, and off, and the chosen value plus the evidence goes in a follow-up ADR. If
  the gate exists because Security.framework misbehaves under load, that is a fact worth
  writing down rather than a limit worth quietly deleting. The dead
  `DispatchSemaphore(value: 1)` in `Assessment` goes.
- **No abort on a bad file.** An unreadable or malformed file produces a record with `errors`
  populated. The scan finishes.
- **Progress on stderr** under `--verbose`, at an interval, not per file.
- **No whole-file mapping to read a header.** `detectArchitectures` reads the bytes it needs.
- `--bundle-mains-only` stays as the fast pass; the default stays "every Mach-O below the
  root". `--exclude` matches path prefixes and path components, not arbitrary substrings.

### W6 — CLI

- `quick <path>` consumes its path, so its flags are read. `quick` becomes what it claims to
  be: `scan` with a fixed set of defaults, sharing one code path and one flag parser.
- An unknown flag is an error, not a silent no-op.
- `--version`, `--help`, and a usage string that matches the flags that exist.
- **Exit codes are a contract**, because a harness reads them: `0` clean, `1` findings at or
  above the `--fail-on` threshold (default: never), `2` usage error, `3` scan error. A scan
  that produced records is not a failure just because it found something, unless asked.
- `README.md` is rewritten to describe what the binary does. Every claim in it is checked
  against the built binary before the tag — the HTML report's "filterable, grouping, search" and
  the Homebrew tap are removed rather than implemented, and the Contributing section stops
  pointing at gitignored paths.

### W7 — Tests

- The suite runs. See [ADR-0002](0002-tests-run-without-xcode.md).
- The golden fixture is actually compared, byte for byte, against a scan of committed fixture
  binaries — not against whatever is installed on the machine running the tests. Host paths do
  not appear in a golden file.
- Coverage that must exist before the tag: entitlement extraction returns a non-empty
  dictionary for a binary that has entitlements; the full `CS_*` flag table decodes Chrome's
  `0x12a00`; the certificate chain is non-empty for a Developer ID binary; every rule in the
  default ruleset fires on a synthetic record and no rule fires twice; the score arithmetic;
  the envelope's shape and key casing; record ordering is stable across two runs; a malformed
  `--rules` file is fatal.

### Ship gate

v1.0 is tagged when, and only when: `make test` is green; `machscope scan` on a Developer ID
app reports the same entitlements, team ID, and flags that `codesign` reports for it; two
consecutive scans of `/Applications` produce byte-identical JSON; every README claim is true of
the built binary; a LICENSE file exists; and no corp identifier, customer name, or internal path
appears anywhere in the tree.

### Explicitly not in v1.0

- **Load-command analysis** — `LC_RPATH` / `LC_LOAD_DYLIB` inventory, `@rpath` hijack
  candidates, `LC_LOAD_DYLINKER`. This is the natural v1.1 and it needs a Mach-O parser the
  tree does not have yet.
- **XPC and MachServices** — `Info.plist` service inventory, URL handlers, login items.
- **TCC correlation.** MachScope does not read `TCC.db`, does not require Full Disk Access, and
  does not need root. Keeping it out is what makes it safe to run anywhere.
- **SARIF and NDJSON output.** One output contract to get right in v1.0.
- **Homebrew tap.** The README's "Coming Soon" is removed.
- **Signature validation.** MachScope reports what a signature *claims*. It does not call
  `SecStaticCodeCheckValidity` and does not verify the seal, so a report says "this binary
  declares `get-task-allow`", never "this signature is valid". The README says so plainly. What
  a flag actually enforces at exec time is AMFI's business, not this tool's.
- **Rewriting extraction against the raw `LC_CODE_SIGNATURE` blob.** Security.framework is
  fine; the bug was a key name.

## Consequences

- **Findings appear where there were none.** A user upgrading from the pre-release binary will
  see entitlement findings on binaries that previously reported clean. Those binaries did not
  change. This is the headline of the release notes, not a footnote.
- **The v1.0 JSON is a breaking change against the current output**, in key casing and in top
  level shape. That is deliberate and it is the last free change: after the tag, `schema_version`
  governs, and an ADR gates any bump.
- **Finding IDs are now a public identifier.** `DLV` and the raw-entitlement-string IDs from the
  YAML both go away in favour of one stable namespace, and consumers pin on it. Retiring an ID
  costs a `schema_version` conversation.
- **Typed entitlement values make the `entitlements` object heterogeneous.** A consumer that
  assumed `bool` breaks. There is no such consumer yet, which is why this lands now.
- **The rules file becomes the interesting file in the repo.** Adding a check stops being a
  Swift change. That is the point, and it means the YAML parser and its error messages are
  load-bearing quality, not a convenience.
- **Deterministic ordering costs a sort** over records at emit — negligible against the
  Security.framework calls, and it buys golden tests and reviewable diffs.
- **The concurrency cap may stay at 2.** If the measurement says Security.framework is the
  bottleneck, the README's performance claims get corrected rather than the code getting
  faster.
- **Exit code 1 on findings is opt-in.** A harness that wants a gate asks for it with
  `--fail-on high`; a human running a scan does not get a shell error for a `low`.
- **v1.1 is already scoped** by what this ADR pushed out, and load-command analysis is the head
  of that queue.

## Alternatives considered

**Tag the current tree as v1.0 and fix in v1.1.** Rejected. The tool reports `entitlements: {}`
for every binary on the system. Publishing an entitlement scanner that finds no entitlements is
worse for the suite's credibility than publishing nothing, and the first thing anyone would do
is compare it to `codesign`.

**Fix extraction only; defer the contract and the scoring.** Rejected, narrowly. A correctness
release that leaves the JSON unfrozen means the first consumer integrates against a shape we
intend to change, and the additive-only rule starts from the wrong baseline. Freezing is
cheapest before there is a consumer, which is now.

**Keep the bare top-level array.** Rejected. It is the friendlier `jq` target, and it leaves
nowhere to record the tool version or the ruleset digest — so a finding in an archived report
could never be traced to the rules that produced it. `.records[]` is one accessor away.

**Keep the hardcoded rules alongside the YAML and just deduplicate the output.** Rejected. It
treats the symptom. Two sources of truth for what counts as dangerous is the defect;
duplicate findings were only how it surfaced.

**A weighted or learned risk model instead of summed severities.** Rejected for v1.0. A score a
consumer cannot recompute from the published record is a number they have to trust, and this
tool has no standing to be trusted that way yet. Arithmetic that anyone can check is worth more
than a better-tuned opaque number.

**Defer scoring entirely to v1.1.** Rejected. `severity: high` on 300 of 1200 records is not a
ranking, and every consumer would invent their own — inconsistently, and without the ruleset
digest needed to compare two scans.
