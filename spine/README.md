# The PoH spine

Rung 5. A clock nobody can wind backwards.

```sh
sh spine/run.sh          # the choreography, narrated and timed
sh test/spine.sh         # the same thing, checked: 16 checks
```

| file | what |
|---|---|
| `../modules/crypto/spine.cicili` | `library(spine)`: the tick loop, the event fold, the segment check — in C |
| `../library/poh.pl` | `library(poh)`: segments, parallel verification, the ledger seam, the oracle |
| `node.pl` | produce, verify one segment, anchor a block, read the order |
| `mallory.pl` | five attacks on a clock |
| `run.sh` | the choreography |

`../docs/tick-to-settlement.html` is the flowchart: the same arc as a diagram,
stage by stage, with the choreography written out invocation by invocation.

## What it is

`h(n+1) = sha256(h(n))`, over the raw 32 bytes. To know `h(n)` you must
have computed the `n−1` hashes before it: there is no shortcut through a
hash chain, and that is the entire mechanism. An event is timestamped by
being **mixed in** — `h(n+1) = sha256(h(n) ‖ event)` — so everything
after that tick depends on the event having existed by then.

## The asymmetry, measured

Producing the spine is sequential and cannot be otherwise. Checking it is
embarrassingly parallel, *provided the producer published checkpoints*.
The work is paid once, in order, by one party, and audited by everybody
at once.

| | 32,000,000 ticks |
|---|---|
| produce, one process | **9.3 s** (3.43M ticks/s, including the turn) |
| verify, one process | **10.0 s** |
| verify, 4 processes | **3.5 s** — 2.8× on 4 cores |

The tight loop alone runs at **2.57M ticks/s** with process start-up
subtracted. The 2.8× is short of 4× because every verifier pays about
0.4 s of process start-up: at 12M ticks the same script reads 1.8×, at
32M it reads 2.8×. **The dilution is the harness, not the mechanism** —
and reporting the flattering number without the trend would have been
the easy lie here.

## Why the loop is in C

A tick through the module seam costs a goal, an atom intern and a
64-character atom: about **600 µs**, measured. In C it is a hash over 32
bytes. That difference is what makes a spine of any length possible.

`library(poh)` keeps the same loop in clauses anyway, as `poh_slow_run/3`, and
it exists to **disagree**: two implementations of one definition, one in
C and one in clauses, and the suite requires the same hash from both. A
third check comes from outside the project entirely — `sha256` of 32 and
of 64 zero bytes are published constants, and the suite pins the first
tick and the event fold to them.

## Mallory against a clock

There are no signatures in a spine, so she cannot forge one. What she can
try is to be paid for work she did not do, or to claim an event happened
earlier than it did — both attacks on **order**, which is the only thing
a spine sells.

| attack | outcome |
|---|---|
| claim a tick count without doing the ticks | refused |
| do fewer ticks than claimed | refused |
| backdate a block to an earlier tick | refused |
| splice a genuine segment from another spine | refused |
| **fork the clock** | **succeeds** |

**The fork succeeds and is supposed to.** Two spines from the same
genesis, differing only in what was mixed in, both verify — both are real
work, and nothing inside a hash chain prefers one sequence over another.
That is not a hole in the implementation; it is what a clock *is*. A
spine orders what is **on** it. Which spine is the chain's is the
**ledger's** question, and `poh_anchor/3` is the seam between them.

## What a spine does not prove

**It is not a proof of wall-clock time.** A faster machine ticks faster,
so "one million ticks apart" is a lower bound on *work*, not a reading of
a clock. Anyone quoting a spine in seconds is quoting the producer's CPU,
not the time of day.

**It does not prove who.** There is no identity in a spine. `anchor_block/1`
folds in a block hash whose *contents* are signed by an authority — the
signature lives in the ledger, one rung down, and the spine only says
when it appeared relative to everything else.

**Segments verifying is not the spine verifying.** A set of perfectly good
pieces that were never one sequence would pass a segment-by-segment
check. `spine_sound/0` checks the joins as well, and the splice attack is
what happens when nobody does.
