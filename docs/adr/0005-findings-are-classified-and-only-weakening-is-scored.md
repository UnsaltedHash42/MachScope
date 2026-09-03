# ADR-0005: Findings are classified, and only weakening counts toward the score

Status: Accepted
Date: 2026-08-26
Owner: UnsaltedHash42

Release-state boundary: Accepted records the architectural decision, not merge or release
provenance. At acceptance, the implementation had locally executed test evidence on a feature
branch. A shipped claim requires a tagged release containing the implementation.

## Context

[ADR-0001](0001-v1-0-scope-and-ship-plan.md) set the scoring weights as "a starting position, not
a calibration," and committed to revisiting them "after v1.0 is measured against a full
`/Applications` corpus." Local design work on 2026-08-26 examined application and system-path
corpora on two macOS versions and indicated that the model conflated distinct kinds of findings.
Those observations are historical design input only. This implementation phase did not reproduce
them, and they are not tracked release, publication, performance, determinism, or current corpus
evidence. They do not satisfy the corpus acceptance gate below.

The historical review indicated that high-frequency, low-information rules could dominate risk
bands and make them poor ranking signals. The underlying problem did not depend on the exact
distribution: findings about weakened code integrity, declared capability, and file provenance
were being added into one score even though they answer different questions.

Each is wrong for its own reason.

**`NO_HARDENED_RUNTIME` is semantically wrong on platform binaries.** Apple's platform binaries
do not rely on `CS_RUNTIME` in the same way as Developer ID software. Reporting "Hardened Runtime
not enabled" for a platform binary is therefore not a useful weakening finding.

**`QUARANTINE_PRESENT` is not a property of the binary's code integrity.** The quarantine xattr
records where a file came from and can change when the file is moved or copied. It is provenance,
and provenance is not a weakening score.

**Summing capability entitlements can manufacture a high score for ordinary software.** Access
to data, devices, or network services may be central to an application's purpose. Those
capabilities deserve visibility, but their presence alone does not mean code-integrity controls
are weakened.

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

The classification for the 24 rules present in v1.0.0:

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

**Corpus evidence requires a fresh re-measurement, not a code review or unit-test result.** A
versioned public corpus must be rescanned and its band distributions recorded before claiming the
classification is calibrated in practice. This implementation phase did not perform that work,
so the corpus acceptance gate remains unsatisfied. If a later re-measurement contradicts the
classification, this ADR should be superseded rather than patched around the evidence.

## Consequences

- **More records are expected to band `none`, but that outcome is not established here.** The
  intended score ranks weakening findings instead of counting every reported observation.
- **This is follow-up work targeting a release after v1.0.0.** Consumers comparing that future
  release with v1.0.0 should expect scores and thresholds to move because the score's meaning is
  narrower.
- **`--fail-on` changes meaning for capability and provenance findings.** Only weakening findings
  can trigger its threshold. v1.0.0 had no separate capability gate, and this change does not add
  one.
- **`NO_HARDENED_RUNTIME` stops firing on platform binaries.** If absence of `CS_RUNTIME` becomes
  meaningful for a platform binary, this rule will stay silent. That is the deliberate trade.
- **Historical corpus observations are not current validation.** Rules not exercised by focused
  implementation tests still need separate corpus evidence before making broader claims about
  their real-world output.
- **The distinction now has to be maintained.** Every new rule must pick a class, and the wrong
  pick reintroduces exactly this defect one rule at a time.

## Alternatives considered

**Drop `QUARANTINE_PRESENT` and fix `NO_HARDENED_RUNTIME`, leave scoring alone.** Rejected,
narrowly — it removes two known sources of noise but leaves capability findings able to rank a
feature-rich application alongside a weakened one. The individual rules were symptoms of the
classification defect, not the whole defect.

**Give capability rules a weight of 0 instead of a class.** Rejected. It produces the same numbers
and hides the reasoning in a column of zeroes. A reader asking "why does contacts access score
nothing" deserves an answer in the ruleset, not an inference from arithmetic.

**Emit separate scores per class.** Rejected for this change. Three numbers need a document
explaining how to combine them, and every consumer would combine them differently. One score with
a stated meaning is more useful than three with none.

**Keep `QUARANTINE_PRESENT` scored at `low`.** Rejected. A common provenance signal carries little
information about code-integrity weakening and should not add risk points merely because it is
present.
