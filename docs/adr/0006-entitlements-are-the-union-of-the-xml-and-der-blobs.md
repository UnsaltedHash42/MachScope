# ADR-0006: Entitlements are the union of the XML and DER blobs, and DER-only keys are marked

Status: Accepted
Date: 2026-08-26
Owner: UnsaltedHash42

Release-state boundary: Accepted records the architectural decision, not merge or release
provenance. At acceptance, the implementation had locally executed test evidence on a feature
branch. A shipped claim requires a tagged release containing the implementation.

## Context

A code signature can carry entitlements as an XML property list and as a DER-encoded structure.
Tools may expose different views of that signing data.

`SecCodeCopySigningInformation` returns three related keys — `entitlements` (the XML blob as
`CFData`), `entitlements-DER` (the DER blob as `CFData`), and `entitlements-dict` (a parsed
dictionary). MachScope relies on Security.framework's `entitlements-dict` as the entitlement set
it reports. It does not independently decode DER.

Local design work on 2026-08-26 compared `entitlements-dict` with the XML plist and observed that
the reported dictionary could contain keys absent from XML on some binaries with DER data. Those
observations are historical design input only. This implementation phase did not reproduce them,
and they are not tracked release, publication, performance, determinism, or current corpus
evidence. They do not satisfy a corpus acceptance gate for this decision.

This needs a decision because a difference between Security.framework's reported set and an
XML-only view can look like an extraction bug unless the source boundary is explicit.

## Decision

**MachScope reports Security.framework's `entitlements-dict` and makes its relationship to XML
visible.**

The implementation treats `entitlements-dict` as the reported entitlement set so rules and output
use the same Security.framework view. When `entitlements-DER` data is present, MachScope compares
the reported dictionary's keys with the keys in the XML plist. It does not independently parse or
validate the DER blob.

**Each record gains `entitlements_der_only`** — an array of keys from `entitlements-dict` that are
absent from the XML plist when DER data is present. If the XML plist data is absent, its key set is
treated as empty. If XML data exists but is malformed or is not a dictionary, MachScope
conservatively reports no DER-only keys rather than attributing every reported key to DER. The
field is additive and does not bump `schema_version`, per
[ADR-0001](0001-v1-0-scope-and-ship-plan.md).

**Before this behavior is claimed as shipped, release documentation must explain the reported
entitlement set and the DER-only comparison.** It must state that MachScope relies on
Security.framework's `entitlements-dict`, compares its keys with the XML plist only when DER data
is present, and does not independently decode DER. The conservative malformed-XML boundary must
also be documented. No such shipped claim is valid until a tagged release contains the
implementation.

## Consequences

- **A user comparing MachScope's reported set with an XML-only view gets an explicit difference**
  instead of an unexplained extra key.
- **Rules match against `entitlements-dict`.** A rule can therefore match a reported entitlement
  even when that key is absent from the XML plist.
- **This depends on Security.framework's `entitlements-dict` behavior.** The historical local
  observations are not current evidence that the behavior is stable across macOS versions or
  corpora. Focused tests cover MachScope's comparison logic, while current corpus validation
  remains separate work.
- **MachScope cannot claim to be a `codesign` replacement**, and should not. It answers a
  different question about the same data.

## Alternatives considered

**Read the XML blob only.** Rejected. It would discard entitlements present in the
Security.framework-reported dictionary solely to match an XML-only view.

**Report `entitlements-dict` but say nothing about the XML difference.** Rejected. Extra keys
would be indistinguishable from an extraction defect to a reader comparing with an XML-only view.

**Split the JSON into `entitlements_xml` and `entitlements_der`.** Rejected for this change.
MachScope does not independently decode DER, so separate source dictionaries would claim a
distinction it does not establish. `entitlements` plus the derived key-difference list states the
implemented boundary.

**Flag DER-only keys as findings.** Rejected. A key absent from XML is not itself a weakness; it is
a representation difference. Turning it into a finding would add the kind of noise
[ADR-0005](0005-findings-are-classified-and-only-weakening-is-scored.md) removes.
