# ADR-0005: Findings are classified, and only weakening counts toward the score

Status: Accepted
Date: 2026-08-26
Owner: UnsaltedHash42

## Context

[ADR-0001](0001-v1-0-scope-and-ship-plan.md) set the scoring weights as "a starting position, not
a calibration," and committed to revisiting them "after v1.0 is measured against a full
`/Applications` corpus." That measurement now exists, across two macOS versions, and it says the
model is wrong.

Two corpora, scanned 2026-08-26:

| | `/Applications` (macOS 26.6) | `/usr/bin` + `/usr/libexec` + `/System/Applications` (26.6) |
|---|---:|---:|
| records | 940 | 1410 |
| top rule | `QUARANTINE_PRESENT` — 878 (93.4%) | `NO_HARDENED_RUNTIME` — 1337 (94.8%) |
| band `low` | 781 | 1264 |
| band `none` | 35 | 54 |

**One rule dominates each corpus, and it is a different rule each time.** The failure is the same
either way: a near-universal, low-information finding lands on almost every record, moves it out
of `none` into `low`, and makes the band meaningless. Strip just those two rules and **1229 of
1410 system records (87%) and 806 of 940 application records (86%) have no other finding at all.**
Roughly six of every seven records in a report exist only because of two rules.

Each is wrong for its own reason.

**`NO_HARDENED_RUNTIME` is semantically wrong on platform binaries.** It fires on 1337 system
records, and **1332 of those are `platform_binary: true`**. Apple's platform binaries do not carry
`CS_RUNTIME`, because the hardened runtime is a Developer ID opt-in and platform binaries are
governed by AMFI through a different mechanism entirely. Reporting "Hardened Runtime not enabled"
for `/usr/bin/*` is not a weak finding, it is a false one.

**`QUARANTINE_PRESENT` is not a property of the binary.** The quarantine xattr records where a
file came from. It says nothing about the code's integrity, it is set on almost everything a user
downloads, and it disappears the moment the file is copied. It is provenance, and provenance is
not risk.

**Summing capability entitlements manufactures "high" out of ordinary apps.**
`/System/Applications/Shortcuts.app` scores 32 and bands `high` on
`APPLE_EVENTS, PII_ADDRESSBOOK, PII_CALENDARS, PII_LOCATION, PII_PHOTOS, NETWORK_CLIENT,
FILES_USER_SELECTED_RW`. Every one of those is Shortcuts doing its job. Nothing about that binary
is weakened; it is merely capable. Meanwhile the single most interesting binary in either corpus —
`/usr/bin/auvaltool`, an Apple platform binary shipping `get-task-allow`,
`disable-library-validation`, and `allow-unsigned-executable-memory` together — is one record
among 1264 others also labelled at least `low`.

The model conflates three different statements: *this binary's code integrity is weakened*, *this
binary can reach your contacts*, and *this file was downloaded*. Summing them ranks a
feature-rich app alongside a genuinely weakened one.

## Decision

**Every rule declares a `class`, and only one class is scored.**

| class | meaning | scored |
|---|---|---|
| `weakening` | a code-integrity or signing protection is defeated or absent | **yes** |
| `capability` | the binary declares access to data or devices | no |
| `provenance` | where the file came from | no |

`risk_score` sums the weights of `weakening` findings only. `capability` and `provenance` findings
are still reported, still carry a severity, and still appear in `findings` — they are frequently
what a reader wants — but they do not move the number that sorts the report.

**A rule may match on `platform_binary`.** The schema gains that condition, and
`NO_HARDENED_RUNTIME` uses it:

```yaml
- id: NO_HARDENED_RUNTIME
  severity: medium
  class: weakening
  reason: Hardened Runtime not enabled
  all:
    - flag: runtime
      present: false
    - platform_binary: false
```

The classification for the shipped 24:

- **weakening** — `GET_TASK_ALLOW`, `GTA_NO_HARDENED`, `DLV`, `DYLD_ENV`, `UNSIGNED_EXEC_MEM`,
  `ALLOW_JIT`, `JIT_AND_NETWORK`, `FILES_ALL`, `ADHOC_SIGNING`, `NO_HARDENED_RUNTIME`,
  `NOTARIZATION_REJECTED`
- **capability** — `APPLE_EVENTS`, `DEVICE_CAMERA`, `DEVICE_MICROPHONE`, `PII_ADDRESSBOOK`,
  `PII_CALENDARS`, `PII_LOCATION`, `PII_PHOTOS`, `NETWORK_CLIENT`, `NETWORK_SERVER`,
  `FILES_USER_SELECTED_RW`, `FILES_DOWNLOADS_RW`, `PRINT`
- **provenance** — `QUARANTINE_PRESENT`

Weights are unchanged: `low 1`, `medium 5`, `high 15`, `critical 40`, per-rule override allowed.
The defect was never the numbers; it was summing three incomparable things.

**`class` is additive to the JSON contract.** It appears on each finding and does not bump
`schema_version`, per [ADR-0001](0001-v1-0-scope-and-ship-plan.md)'s rule.

**Acceptance is a re-measurement, not a code review.** After the change, both corpora are rescanned
and the band distributions recorded. `/usr/bin/auvaltool` must remain `critical`, Shortcuts must
fall out of `high`, and the majority of both corpora must land in `none`. If they do not, the
classification is wrong and this ADR is superseded rather than patched.

## Consequences

- **Most records will band `none`, and that is the point.** A report where 87% of rows are `low`
  ranks nothing. A report where 87% are `none` puts the interesting rows at the top.
- **Scores drop across the board.** Anyone who has pinned a threshold against v1.0 scores would
  see it move — nobody has, which is why this lands before the tag rather than after.
- **`--fail-on` changes meaning for capability findings.** A binary declaring camera access no
  longer trips `--fail-on medium`, because it produces no scored finding. Someone who wants to gate
  on capabilities needs a different mechanism; none is offered in v1.0 and that is a real gap.
- **`NO_HARDENED_RUNTIME` stops firing on ~1332 system binaries.** If a platform binary ever does
  ship without `CS_RUNTIME` in a context where that matters, this rule now stays silent about it.
  That is the trade: the rule was wrong 99.6% of the time it fired.
- **Three findings are still unfired on any corpus** — `DYLD_ENV`, `FILES_ALL`, and
  `NOTARIZATION_REJECTED` (the last cannot fire while [ADR-0003](0003-assessment-is-disabled-until-the-bridge-is-correct.md) holds). Their reasons and severities remain unverified against
  real output, and shipping a rule nobody has seen fire is a known risk carried deliberately.
- **The distinction now has to be maintained.** Every new rule must pick a class, and the wrong
  pick reintroduces exactly this defect one rule at a time.

## Alternatives considered

**Drop `QUARANTINE_PRESENT` and fix `NO_HARDENED_RUNTIME`, leave scoring alone.** Rejected,
narrowly — it removes the two measured offenders and would have been the cheap fix. It loses
because Shortcuts would still band `high` on seven capability findings, so the model would still
rank a capable app with a weakened one; the two noise rules were symptoms of that, not the disease.

**Give capability rules a weight of 0 instead of a class.** Rejected. It produces the same numbers
and hides the reasoning in a column of zeroes. A reader asking "why does contacts access score
nothing" deserves an answer in the ruleset, not an inference from arithmetic.

**Emit separate scores per class.** Rejected for v1.0. Three numbers need a document explaining
how to combine them, and every consumer would combine them differently. One score with a stated
meaning is more useful than three with none.

**Keep `QUARANTINE_PRESENT` scored at `low`.** Rejected. It fires on 93% of downloaded software.
A signal present in nearly every sample carries almost no information, and it costs a point on
almost every record.
