# ADR-0003: Gatekeeper assessment is disabled until the bridge calls the real API

Status: Accepted
Date: 2026-08-26
Owner: UnsaltedHash42

## Context

`--assessment` segfaulted on every binary it was pointed at:

```
$ machscope scan /bin/ls --format json --assessment
(no output)                       # exit 139, SIGSEGV
```

`SecBridge.m:45-53` looks the function up with `dlsym` and declares it as:

```objc
typedef OSStatus (*SecAssessmentCopyResultFn)(CFTypeRef, CFOptionFlags, CFDictionaryRef, CFTypeRef *);
OSStatus status = fn(url, 0, assessmentParams, (CFTypeRef *)&assessmentResult);
```

The real API is two calls, and neither matches that signature:

```c
SecAssessmentRef SecAssessmentCreate(CFURLRef path, SecAssessmentFlags flags,
                                     CFDictionaryRef context, CFErrorRef *errors);
CFDictionaryRef  SecAssessmentCopyResult(SecAssessmentRef assessment,
                                         SecAssessmentFlags flags, CFErrorRef *errors);
```

Three errors compound. A `CFURLRef` is passed where a `SecAssessmentRef` belongs, so the callee
dereferences the wrong object. The fourth parameter is a `CFErrorRef` out-parameter, and the
bridge treats what lands there as the result dictionary. The declared return type is `OSStatus`
where the function returns `CFDictionaryRef`, so the status test reads a truncated pointer.
`Assessment.swift:23-30` then indexes the result for a key `decision`, which no Security.framework
constant supplies.

The feature has therefore never worked. `notarization` has been absent from every default scan
and a crash on every requested one.

Two further problems sit behind the crash, and both argue against a quick repair. The operation
requested is `execute`, which asks Gatekeeper for an execution verdict — a policy decision that
depends on the machine's Gatekeeper state, quarantine, and prior user approvals. It is not the
same question as "is this binary notarized", which is answered by a stapled ticket:
`codesign -dv` reports `Notarization Ticket=stapled` for Chrome without consulting policy at
all. A scanner that reports a local policy verdict under the field name `notarization` would be
wrong in a way no consumer could detect. And `SecAssessment.h` is not in the public SDK, which
is why the bridge reached for `dlsym` in the first place; doing it correctly means getting two
signatures right by hand with no header to check them against.

## Decision

**`--assessment` is accepted, disabled, and says so.** It writes one line to stderr, does not
call the bridge, and leaves `notarization` absent from the record. The bridge method stays in
the tree, uncalled, so the next slice starts from the diagnosis above rather than rediscovering
it.

The flag is not removed. Removing it would erase the evidence that the feature was attempted and
would make its absence look like a decision never to have it.

**When it returns, it reports the stapled ticket, not an execution assessment**, and the field
says which question it answered. A policy verdict, if it is ever wanted, is a separate field
under a separate name.

## Consequences

- `machscope scan --assessment` no longer crashes. It also produces no more information than a
  scan without the flag, and the stderr line is the only thing that says so.
- `NOTARIZATION_REJECTED` ships in the default ruleset and cannot fire. That is deliberate: the
  rule is correct, its input is missing, and deleting it would mean re-deriving it later.
- The `notarization` field stays absent from every record, so no consumer can come to depend on
  a value that was never right.
- MachScope claims nothing about notarization in v1.0. The README says so rather than staying
  quiet about it.
- Someone reading `SecBridge.m` finds a method with no callers. This ADR is why.

## Alternatives considered

**Fix the bridge in the same slice.** Rejected on scope, not on difficulty. The slice already
carried the entitlement extraction and the whole rules engine, and this needs two hand-written
`dlsym` signatures verified against an API with no public header — the kind of work that wants
its own attention and its own test, not the tail end of someone else's change.

**Remove `--assessment` entirely.** Rejected. The flag is the record that this was tried; a
silent removal invites the same broken implementation to be written again.

**Keep calling it and catch the crash.** Rejected outright. There is nothing to catch — it is a
segfault from a wrong calling convention, not a raised error, and a signal handler around a
misdeclared function is a way to keep shipping the defect.

**Report the execution assessment under a different field name now.** Rejected for v1.0. It
would mean shipping a value whose meaning depends on the scanning machine's Gatekeeper state,
which makes two scans of the same binary on two machines disagree for reasons that have nothing
to do with the binary.
