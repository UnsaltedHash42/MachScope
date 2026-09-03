# Architecture Decision Records

Each significant architectural choice in MachScope gets a numbered ADR. Format is Michael
Nygard's, lightly adapted, and kept identical to the other repos in this suite so they all
read the same way:

```markdown
# ADR-NNNN: short title

Status: Proposed | Accepted | Deprecated | Superseded by ADR-XXXX
Date: YYYY-MM-DD
Owner: name

## Context
## Decision
## Consequences
## Alternatives considered
```

Records in this repo:

ADR-0005 and ADR-0006 have locally executed test evidence, but this index does not establish
merge or release provenance. Consult tracked refs and releases before describing either behavior
as shipped.

| ADR | Title | Status |
|---|---|---|
| [0001](0001-v1-0-scope-and-ship-plan.md) | MachScope v1.0 scope and ship plan | Accepted |
| [0002](0002-tests-run-without-xcode.md) | Tests run on Command Line Tools, without Xcode | Accepted |
| [0003](0003-assessment-is-disabled-until-the-bridge-is-correct.md) | Gatekeeper assessment is disabled until the bridge calls the real API | Accepted |
| [0004](0004-the-security-api-cap-is-four.md) | The Security.framework call cap is four, and `--concurrency` does not mean what it says | Accepted |
| [0005](0005-findings-are-classified-and-only-weakening-is-scored.md) | Findings are classified, and only weakening counts toward the score | Accepted |
| [0006](0006-entitlements-are-the-union-of-the-xml-and-der-blobs.md) | Entitlements are the union of the XML and DER blobs, and DER-only keys are marked | Accepted |

Conventions:

- One ADR per file, `NNNN-kebab-case-title.md`. Numbering is per-repo.
- **Never delete — supersede.** A superseded record keeps its file and gains a `Superseded by`
  status line.
- When a later record changes one clause of an earlier one rather than the whole decision,
  amend in place: leave an inline **AMENDED by ADR-XXXX** note at the exact clause. A reader
  who lands mid-file never sees the `Status` line.
- An ADR lands in the same change as the work it justifies, or immediately before it.
- Before citing an ADR, read its `Status` line. If it is superseded, quote the successor.
