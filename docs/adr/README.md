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

| ADR | Title | Status |
|---|---|---|
| [0001](0001-v1-0-scope-and-ship-plan.md) | MachScope v1.0 scope and ship plan | Accepted |
| [0002](0002-tests-run-without-xcode.md) | Tests run on Command Line Tools, without Xcode | Accepted |

Conventions:

- One ADR per file, `NNNN-kebab-case-title.md`. Numbering is per-repo.
- **Never delete — supersede.** A superseded record keeps its file and gains a `Superseded by`
  status line.
- When a later record changes one clause of an earlier one rather than the whole decision,
  amend in place: leave an inline **AMENDED by ADR-XXXX** note at the exact clause. A reader
  who lands mid-file never sees the `Status` line.
- An ADR lands in the same change as the work it justifies, or immediately before it.
- Before citing an ADR, read its `Status` line. If it is superseded, quote the successor.
