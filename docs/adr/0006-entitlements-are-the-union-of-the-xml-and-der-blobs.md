# ADR-0006: Entitlements are the union of the XML and DER blobs, and DER-only keys are marked

Status: Accepted
Date: 2026-08-26
Owner: UnsaltedHash42

## Context

A code signature can carry entitlements twice: as an XML property list, and as a DER-encoded
structure. Both are present in modern binaries. `codesign -d --entitlements :-` prints the **XML
blob only**, and that command is how nearly everyone reads entitlements.

`SecCodeCopySigningInformation` returns three related keys — `entitlements` (the XML blob as
`CFData`), `entitlements-DER` (the DER blob as `CFData`), and `entitlements-dict` (a parsed
dictionary). MachScope reads `entitlements-dict`. Measured 2026-08-26:

```
/usr/libexec/KeychainStasher    entitlements-dict: 4 keys   XML blob: 3 keys
  present only in DER:  com.apple.application-identifier

/usr/libexec/adprivacyd         entitlements-dict: 43 keys  XML blob: 42 keys
  present only in DER:  com.apple.developer.aps-environment
```

**`entitlements-dict` is the union of the two blobs.** MachScope therefore reports entitlements
that `codesign -d --entitlements` does not show.

Measured against `codesign` across two macOS versions:

| corpus | binaries | entitlement sets agree | team id | signature flags |
|---|---:|---:|---:|---:|
| `/Applications`, macOS 26.6 | 940 | 100% | 100% | 100% |
| system paths, macOS 26.6 | 1410 | 95.39% | 100% | 100% |
| system paths, macOS 15.7.7 | 1171 | 96.84% | 100% | 100% |

Every one of the 102 disagreements is MachScope reporting a **superset**. There is no binary in
3521 where MachScope missed an entitlement `codesign` found, and none where team identifier or
decoded signature flags differ. The same keys recur on both OS versions, so the mechanism is
stable rather than a quirk of one release.

Third-party applications show none of this — `/Applications` agrees exactly at 940 of 940. The
divergence is concentrated in Apple's own system binaries, at roughly 4% of them.

This needs a decision because it looks like a bug. A user who checks MachScope against `codesign`
on `/usr/libexec` will find extra keys and reasonably conclude the tool is inventing them.

## Decision

**MachScope reports the union, and says so.**

The union is what the signature actually contains. A tool that audits entitlements should report
every entitlement present, not the subset one command happens to print. An entitlement that is
DER-only is precisely the kind of thing a manual reviewer misses, which makes surfacing it the
most useful thing this tool does on a system binary.

**Each record gains `entitlements_der_only`** — an array of the keys present in the DER blob and
absent from the XML blob, empty for almost every binary. A reader comparing against `codesign` can
see immediately which keys explain the difference, rather than being left to guess. The field is
additive and does not bump `schema_version`, per
[ADR-0001](0001-v1-0-scope-and-ship-plan.md).

**The README states the divergence plainly**, next to the claim of agreement with `codesign`, in
the form: agreement on team identifier and signature flags across 3521 binaries on two macOS
versions; on entitlements a superset, with the DER-only keys named per record.

**The published agreement figure is never "100%".** It is stated per field and per corpus, with the
superset behaviour named. The `/Applications` 940-of-940 number is not quoted on its own, because
it is true only of a corpus that happens to contain no DER-only entitlements and would collapse
the moment a reader pointed the tool at `/usr/libexec`.

## Consequences

- **A user diffing MachScope against `codesign` finds a documented answer** instead of an apparent
  bug, and `entitlements_der_only` tells them which keys to look at.
- **Rules match against the union.** A rule naming a dangerous entitlement fires when that
  entitlement is DER-only — which is the behaviour worth having, and means a rule can fire on
  something `codesign` output would not have shown.
- **The honest claim is longer than the clean one.** "100% agreement with codesign" would have fit
  in a release headline. It is also false, and it would have been falsified by the first reader who
  scanned a system directory.
- **This depends on `entitlements-dict` continuing to be a union.** Apple documents none of this;
  it is measured behaviour on 26.6 and 15.7.7. If a future macOS changes it, the
  `entitlements_der_only` field goes empty and nothing breaks loudly — a quiet failure worth a
  regression test that asserts a known DER-only binary still reports one.
- **MachScope cannot claim to be a `codesign` replacement**, and should not. It answers a
  different question about the same data.

## Alternatives considered

**Read the XML blob only, to match `codesign` exactly.** Rejected. It would buy a clean agreement
number by throwing away real entitlements, and it is the opposite of what an entitlement auditor
is for. The number would be reporting a decision to see less.

**Report the union but say nothing.** Rejected. The first careful user diffs against `codesign`,
finds keys that "should not be there," and stops trusting the tool. An undocumented superset is
indistinguishable from a defect.

**Split the JSON into `entitlements_xml` and `entitlements_der`.** Rejected for v1.0. It doubles
the field every consumer has to read, to express something true of about 4% of system binaries and
none of the third-party ones. `entitlements` plus a list of the DER-only keys carries the same
information at a fraction of the cost.

**Report the union and flag DER-only keys as findings.** Rejected. A DER-only entitlement is not
itself a weakness — it is a representation detail. Turning it into a finding would flood system
scans with exactly the kind of noise [ADR-0005](0005-findings-are-classified-and-only-weakening-is-scored.md) removes.
