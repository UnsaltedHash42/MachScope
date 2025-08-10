# Development Task List

## Task Status Definitions
- **Pending**: Not yet started
- **In Progress**: Currently being worked on
- **Complete**: Finished and all tests pass
- **Blocked**: Waiting for dependencies

## Priority Levels
- **High**: Critical for MVP/acceptance criteria
- **Medium**: Important but not blocking
- **Low**: Nice to have

## Phase 1: Project Setup (SwiftPM + Structure)
| ID | Description | Dependencies | Status | Priority | Estimation | Notes |
|----|-------------|--------------|--------|----------|------------|-------|
| 1.1 | Scaffold SwiftPM package with `MachScopeCLI` and `MachScopeCore` targets | None | In Progress | High | 1h | Platforms: macOS 13+, Swift 5.10 |
| 1.2 | Add `Security.framework` linker setting in `Package.swift` | 1.1 | Pending | High | 0.5h | Use SwiftPM linkerSettings to link `Security` |
| 1.3 | Create source skeletons for core modules (`Discovery`, `SignInfo`, `Rules`, `Report`, `Model`) | 1.1 | Pending | High | 1.5h | Files per design structure |
| 1.4 | Create CLI `main.swift` with argument parser stub | 1.1 | Complete | High | 1h | Support `scan`, `quick`, output opts (no-op) |
| 1.5 | Set up test target `MachScopeCoreTests` | 1.1 | Pending | High | 1h | Add placeholder tests and fixtures dir |

## Phase 2: Objective-C Bridge for Security.framework
| ID | Description | Dependencies | Status | Priority | Estimation | Notes |
|----|-------------|--------------|--------|----------|------------|-------|
| 2.1 | Add `SecurityBridge` Clang target (ObjC) with public headers | 1.1 | In Progress | High | 2h | Wrap `SecStaticCodeCreateWithPath`, `SecCodeCopySigningInformation`, `SecAssessmentCopyResult` |
| 2.2 | Expose safe Swift wrappers for CF types and unmanaged memory | 2.1 | Pending | High | 2h | Convert CFDictionary→Swift Dictionary |
| 2.3 | Integration: call bridge from `SignInfoExtractor` | 2.2 | Pending | High | 1h | Error propagation with OSStatus |

## Phase 3: Core Functionality
| ID | Description | Dependencies | Status | Priority | Estimation | Notes |
|----|-------------|--------------|--------|----------|------------|-------|
| 3.1 | Implement `FileWalker` (recursive traversal with filters) | 1.3 | In Progress | High | 2h | Concurrency-aware traversal |
| 3.2 | Implement `MachOMagic` (magic number/arch detection) | 1.3 | Pending | High | 1.5h | Support FAT/Universal |
| 3.3 | Implement `BundleIntrospector` (Info.plist parsing) | 1.3 | Pending | High | 1h | Extract CFBundleIdentifier |
| 3.4 | Implement `Entitlements` parsing from signing info | 2.3 | Pending | High | 1.5h | Map to Swift types |
| 3.5 | Map signature flags incl. Hardened Runtime | 2.3 | Pending | High | 1h | Human-readable flags |
| 3.6 | Implement Gatekeeper/Notarization assessment | 2.3 | Pending | High | 1h | execute/install types |
| 3.7 | Implement `RulesEngine` with default YAML rules | 3.4,3.5,3.6 | Pending | High | 2h | Single + combination rules |

## Phase 4: Reporting & CLI
| ID | Description | Dependencies | Status | Priority | Estimation | Notes |
|----|-------------|--------------|--------|----------|------------|-------|
| 4.1 | Implement `JSONWriter` | 3.x | Complete | High | 1h | One record per target |
| 4.2 | Implement `HTMLReport` (single-file with embedded assets) | 3.x | In Progress | High | 2h | Sort/filter client-side |
| 4.3 | Wire CLI options (`--format`, `--out`, `--rules`, `--exclude`, `--max-depth`, `--follow-symlinks`, `--concurrency`, `--verbose`) | 1.4,3.x,4.1,4.2 | In Progress | High | 2h | Defaults per design |

## Phase 5: Testing
| ID | Description | Dependencies | Status | Priority | Estimation | Notes |
|----|-------------|--------------|--------|----------|------------|-------|
| T1 | Unit: Entitlements parser | 2.3,3.4 | Complete | High | 1h | Cover edge cases |
| T2 | Unit: Flag mapping | 2.3,3.5 | Complete | High | 1h | Map kSecCodeInfoFlags |
| T3 | Unit: Rules engine (single+combo) | 3.7 | Pending | High | 1.5h | Deterministic IDs/severity |
| T4 | Integration: E2E scan of fixtures | 3.x,4.x | Pending | High | 2h | Use sample signed apps |
| T5 | Golden output tests | 4.1,4.2 | Pending | Medium | 1h | JSON/HTML snapshots |
| T6 | Performance: scan /Applications < 120s | 3.x | Pending | Medium | 1h | Measure on M-series |

## Phase 6: Packaging & Release
| ID | Description | Dependencies | Status | Priority | Estimation | Notes |
|----|-------------|--------------|--------|----------|------------|-------|
| 6.1 | Homebrew tap (arm64 bottle) | 4.x, T4 | Pending | Medium | 2h | Formula + GitHub release |
| 6.2 | README usage examples | 4.x | Pending | Medium | 0.5h | CLI examples |

## Checkpoints
| ID | Description | Required Tasks | Status | Notes |
|----|-------------|----------------|--------|-------|
| C1 | Project scaffold builds | 1.1, 1.2, 1.3, 1.4, 1.5 | Pending | swift build + swift test pass |
| C2 | Core extraction + rules working | 2.x, 3.x | Pending | Identify findings on sample apps |
| C3 | Reporting and CLI | 4.x | Pending | JSON+HTML output stable |
| C4 | Test coverage and performance | T1–T6 | Pending | >80% coverage, perf target met |
| C5 | Packaging | 6.x | Pending | Homebrew tap works |

## Notes
- Update status as work progresses
- Commit only after passing tests at checkpoints
- Document design deviations in `.docs/Notes.md`
