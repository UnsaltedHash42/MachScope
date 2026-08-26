# ADR-0004: The Security.framework call cap is four, and `--concurrency` does not mean what it says

Status: Accepted
Date: 2026-08-26
Owner: UnsaltedHash42

## Context

`SignInfoExtractor` guards its only expensive call with
`private static let secAPISem = DispatchSemaphore(value: 2)`. Every
`SecCodeCopySigningInformation` in the process queues on those two slots, so `--concurrency 8`
has never meant eight concurrent extractions. Nobody recorded why the gate was there.

[ADR-0001](0001-v1-0-scope-and-ship-plan.md) refused to delete it on faith: if Security.framework
misbehaves under load, that is a fact worth writing down rather than a limit worth quietly
removing. It required a measurement first.

Measured 2026-08-26 on an Apple M5 Max, macOS 26.6 (build 25G72), Swift 6.3.3, debug build, over
940 records
under `/Applications`. Three runs per cell, median reported, wall-clock seconds:

| cap | `-c 4` | `-c 8` | `-c 16` |
|---|---:|---:|---:|
| **2** (current) | 4.91 | 4.81 | 4.82 |
| 4 | 4.50 | 4.50 | 4.50 |
| 8 | 4.49 | 4.49 | 4.50 |
| removed | 4.50 | 4.49 | 4.50 |

All 36 runs produced 940 records. Every sorted `records` array was byte-identical to the cap-2
baseline. No run introduced a non-empty `errors` array where the baseline had none. Nothing
crashed or hung.

Two things fall out, and the second matters more than the first.

**The cap costs about 0.31 seconds, once.** Raising it from 2 to 4 removes the entire measured
penalty — 4.81 to 4.50, roughly 6%. Going beyond 4 buys nothing: cap 4, cap 8, and no cap at all
are indistinguishable at this corpus size.

**Worker count is not what bounds this scan.** At every cap from 4 upward, `-c 4`, `-c 8`, and
`-c 16` land within 0.01 seconds of each other. The scan is bound by something other than how
many extractions run at once — enumeration, per-file I/O, or simply the call being fast enough
that four in flight saturate it. The `--concurrency` flag has been documented as a performance
knob and measurably is not one past four.

The evidence about thread safety is weaker than it looks. Thirty-six clean runs over one corpus
on one machine is consistent with Security.framework being safe under load, and it is also
consistent with a race we did not happen to lose. Absence of a crash is not proof.

## Decision

**The cap becomes 4. It is not removed.**

Four captures every second the measurement found. Removing the bound entirely wins nothing
measurable and gives up the only protection the process has against fanning an unbounded number
of concurrent calls into a framework whose thread-safety guarantees are not documented and which
we did not write. A bound we can point at a number for is worth keeping; a bound at 2 that costs
6% for no stated reason is not.

**`--concurrency` is documented as what it is.** The README states that values above four do not
change throughput measurably, and gives the number and the hardware it was measured on rather
than a claim about scaling. The flag stays — it still governs the enumeration and evaluation
queue — but it stops being advertised as a way to go faster.

**The number is provisional and its evidence is named.** This ADR is superseded, not amended, if
a larger corpus or a different machine shows either a crash at cap 4 or a real gain above it.
`.docs/bench/2026-08-26-concurrency.md` holds the raw timings.

*(Corrected 2026-08-26: the host line first read macOS 26.5. The machine is 26.6; 26.5 was the
SDK directory name misread as the OS version. The timings and the decision are unaffected — the
same binary on the same hardware produced them.)*

## Consequences

- A `/Applications` scan gets about 6% faster and nothing else changes. That is a small return
  for the work, and knowing the gate is not load-bearing is worth more than the 0.31 seconds.
- **Two concurrent `SecCodeCopySigningInformation` calls become four.** If the original gate was
  a fix for a real crash that nobody recorded, this is where it comes back. The measurement above
  is the whole of the evidence that it will not, and it is one machine and one corpus.
- The README stops implying that raising `--concurrency` speeds up a scan. Anyone tuning for
  throughput on a big tree now knows to look at enumeration instead.
- The next person to want more parallelism has a baseline to beat and a file of raw timings to
  compare against, rather than a semaphore with no comment on it.
- The cap is still a magic number in a source file. It is now a magic number with an ADR.

## Alternatives considered

**Remove the semaphore entirely.** Rejected, narrowly — this is the option the numbers most
nearly support, since cap 8 and no cap measured identically. It loses because the upside is zero
by measurement and the downside is unbounded concurrent entry into a framework we do not control,
on corpora larger than the one tested. If a later measurement finds a real gain above four, this
becomes the obvious successor.

**Leave it at 2.** Rejected. It costs 6% and no one can say what it buys. Keeping an unexplained
limit because it has always been there is how it survived this long.

**Raise it to 8.** Rejected. Identical timings to 4, twice the concurrent entry into
Security.framework. Where two settings measure the same, take the smaller one.

**Make the cap a flag.** Rejected. It is not a decision a user has the information to make, and a
knob whose only honest documentation would be "leave this alone" should not exist.
