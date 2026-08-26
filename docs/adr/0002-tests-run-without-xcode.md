# ADR-0002: Tests run on Command Line Tools, without Xcode

Status: Accepted
Date: 2026-08-26
Owner: UnsaltedHash42

## Context

`CLAUDE.md` calls this "the repo with real test coverage" and requires `make test` to stay
green. It has never run on the machine it is developed on:

```
$ swift test
Tests/MachScopeCoreTests/GoldenOutputTests.swift:1:8: error: no such module 'XCTest'
```

`xcode-select -p` reports `/Library/Developer/CommandLineTools`. No Xcode is installed, and
Command Line Tools ships no `XCTest.framework` — only `libswiftXCTest.dylib` under the
long-dead `usr/lib/swift-5.0/` layout and an `XCTestSupport.tbd` in the SDK's PrivateFrameworks.
Neither gives SwiftPM a module to import. Any XCTest-based suite is unrunnable here.

Command Line Tools *does* ship swift-testing:

```
/Library/Developer/CommandLineTools/Library/Developer/Frameworks/Testing.framework
/Library/Developer/CommandLineTools/Library/Developer/usr/lib/lib_TestingInterop.dylib
```

Neither path is on SwiftPM's default search path, so `import Testing` fails out of the box too,
and adding only the framework search path gets a bundle that links but cannot `dlopen` —
`Testing` resolves, then `@rpath/lib_TestingInterop.dylib` does not.

Verified working on 2026-08-26 (Swift 6.3.3, macOS 26.5, CLT-only), on a throwaway package with
one `@Test`:

```sh
F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
swift test \
  -Xswiftc -F -Xswiftc "$F" \
  -Xlinker -F -Xlinker "$F" \
  -Xlinker -rpath -Xlinker "$F" \
  -Xlinker -rpath -Xlinker "$L"
```

```
✔ Test twoIsTwo() passed after 0.001 seconds.
✔ Test run with 1 test in 0 suites passed after 0.001 seconds.
```

One warning comes with it: `building for macOS-13.0, but linking with dylib
'@rpath/Testing.framework/Versions/A/Testing' which was built for newer version 14.0`.

## Decision

**The suite moves from XCTest to swift-testing, and `make test` picks its own flags.**

1. `GoldenOutputTests`, `ParserTests`, and `RulesTests` are rewritten against `import Testing`
   — `@Test`, `@Suite`, `#expect`, `#require`. There is no XCTest left in the tree.

2. **`make test` detects the selected toolchain.** If `xcode-select -p` names an Xcode, it runs
   plain `swift test`. Otherwise it adds the four flags above, after probing that
   `Testing.framework` and `lib_TestingInterop.dylib` are where it expects; if they are not, it
   fails with a message naming both paths and pointing at this ADR, rather than at a linker
   error.

3. **The detection lives in the Makefile, not in `Package.swift`.** `unsafeFlags` in a manifest
   bars the package from being consumed as a dependency by anything else, and it would bake an
   absolute workstation path into a public repo. The Makefile is the right place for a local
   toolchain accommodation.

4. **The package keeps its macOS 13 floor.** The 14.0 link warning lands on the test bundle,
   not on `machscope`, and the shipped binary's minimum stays where `README.md` says it is.

## Consequences

- `make test` works with or without Xcode. A GitHub macOS runner has Xcode selected and takes
  the plain path, so CI needs no special case.
- **Running the suite needs macOS 14**, because that is what the CLT `Testing.framework` was
  built for. The shipped binary still supports macOS 13. A contributor on 13 with no Xcode can
  build MachScope and cannot run its tests — an acceptable gap for a tool whose own floor moves
  up in time.
- XCTest idioms are gone. `XCTAssertEqual` becomes `#expect(a == b)`; `XCTestCase` subclasses
  become free `@Test` functions or a `@Suite` struct. Anyone who has written XCTest and not
  swift-testing pays a small learning cost, once.
- The Makefile now carries two hardcoded Apple paths. They rot if Apple moves them; the probe
  in step 2 is what turns that rot into a legible message instead of a wall of `ld` output.
- swift-testing runs tests in parallel by default, where XCTest did not. Tests that shared
  mutable state would newly interfere. The current three files share none, and
  [ADR-0001](0001-v1-0-scope-and-ship-plan.md)'s W7 fixtures are read-only, so this is a
  constraint on new tests rather than a migration cost.

## Alternatives considered

**Install Xcode.** The clean fix, and about 10 GB plus a manual step that no ADR can perform.
Not rejected so much as not sufficient: it fixes this workstation and does nothing for a
contributor who has only Command Line Tools. The Makefile takes the plain path when Xcode is
present, so installing it later costs nothing and changes nothing.

**Keep XCTest and require Xcode to run the suite.** Rejected. The repo's stated invariant is
that `make test` is green, and an invariant that cannot be checked on the development machine
is not an invariant.

**Add `swift-corelibs-xctest` as a package dependency.** Rejected. On Darwin, SwiftPM links the
system XCTest; the corelibs package exists for Linux and would fight the platform rather than
fill the gap.

**Vendor `Testing.framework` into the repo.** Rejected outright. Redistributing an Apple
framework in a public repo, to work around a search path, is the wrong trade at any size.
