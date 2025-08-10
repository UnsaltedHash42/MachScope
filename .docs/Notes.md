# Project Development Notes

## Project Overview
[Date: 2025-08-10]
- **Project Name**: MachScope
- **Description**: macOS CLI that scans Mach-O binaries and app bundles to extract signing info, assess Gatekeeper/notarization, and generate JSON/HTML reports with opinionated security findings.
- **Goals**: MVP that builds on macOS 13+, scans /Applications, produces JSON/HTML, and identifies ≥5 meaningful findings under 2 minutes.

## Design Decisions

### [Date: 2025-08-10] Decision to use direct Security.framework APIs via Objective-C bridge because Swift-only access to required C/CF APIs is cumbersome and error-prone
- **Context**: The design mandates native API usage (no subprocesses) and requires `SecStaticCodeCreateWithPath`, `SecCodeCopySigningInformation`, and `SecAssessmentCopyResult`.
- **Alternatives Considered**: Shelling out to `codesign`/`spctl` (rejected for performance/stealth); Swift-only CF wrappers (rejected due to unsafe unmanaged handling complexity).
- **Impact**: Introduces a small ObjC target for bridging and clear Swift wrappers; links `Security.framework` at build time.

## Challenges & Solutions

### [Date: 2025-08-10] **Challenge**: Establishing project scaffold that compiles before full bridge is implemented
**Solution**: Create SwiftPM targets with stubbed modules and tests; link `Security.framework` but defer calls behind placeholders.
**Impact**: Enables iterative development with green builds while implementing bridges incrementally.

## Development Progress

### [Date: 2025-08-10] [ ] Scaffold SwiftPM package and module skeletons - [PRIORITY: High] [2.5h]
- **Status**: In Progress
- **Dependencies**: None
- **Notes**: Creating `Package.swift`, `Sources/` structure, and placeholder tests.

## Technical Decisions

### Architecture
- **Pattern**: Library core (`MachScopeCore`) + CLI front-end (`MachScopeCLI`) with modular subpackages per domain (Discovery, SignInfo, Rules, Report, Model).
- **Rationale**: Supports testability, separation of concerns, and reuse.

### Dependencies
- **Framework**: Security.framework (linked via SwiftPM linker settings)
- **Libraries**: None at this stage
- **Constraints**: macOS 13+, Swift 5.10+

## Performance Considerations
- **Bottlenecks Identified**: None yet (scaffolding stage)
- **Optimizations Applied**: N/A
- **Monitoring**: Plan perf test scanning `/Applications` with concurrency controls.

## Security Considerations
- **Data Protection**: Read-only operations; no network; local-only analysis.
- **Vulnerabilities**: Avoid subprocesses; handle CF memory safely in bridge.

## Future Considerations
- **Scalability**: Concurrency via DispatchQueue/OperationQueue; back-pressure in traversal.
- **Maintenance**: Keep bridge API minimal and well-documented; comprehensive tests.
- **Enhancements**: TCC correlation and stapled ticket checks post-MVP.
