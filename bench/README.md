# The TPS harness

Rung 8, and the last one. Every rung before this produced a GREEN line.
None produced a number.

```sh
sh bench/tps.sh          # the lanes, measured and narrated
sh test/bench.sh         # the harness's RULES, checked: 25 checks
sh bench/solana.sh       # the other system on the same box (SKIPs without its toolchain)
```

| file | what |
|---|---|
| `harness.pl` | what a reading must carry before it may be printed |
| `mallory.pl` | eight ways to inflate a number |
| `tps.sh` | the lanes |
| `solana.sh` | the same rules pointed at a single-node Solana validator |
| `languages.md` | Python, Prolog and cocolog compared across the language aspects -- a benchmark of a different kind, under the same rule: no number that was not printed |

**THE TABLES BELOW ARE IN THE ORDER THEY WERE MEASURED, oldest first,
and none of them is deleted when the next one disagrees.** That is rule
6 applied to this file rather than to a run: a superseded reading is a
different claim, not a wrong one, and a benchmark that keeps only its
best number is a benchmark nobody can check. The latest is **run E**,
under *The whole stack rebuilt with clang*.

## The number is on the page

One run, on a 4-core Linux container, against a Zigurat server on a
FRESH store. The whole stack is a RELEASE build -- ZiguratIP -O3
workspace-wide, the engine and the interpreter through Cicili's
`--release` set (-O3, -falign-loops=32 for C), the compiled procedure
objects through the conf's own -O3 -- and fork choice is INCREMENTAL:
`head_mark/3` carries each chain's in-turn count, computed once at
accept time, so `ledger_head/1` is one pass over the marks instead of
a walk of every chain from every mark:

| lane | rate | arrangement |
|---|---:|---|
| `verify` | **168/s** | `local_no_database` |
| `validate` | **160/s** | `local_no_database` |
| `seal_batched` | **15.5/s** | `server_one_kb_ONE_TURN` |
| `seal_per_turn` | **1.5/s** | `server_one_kb_per_turn` |
| `parallel_own_kbs` | **22.1/s** | `server_4_kbs_ONE_TURN_each` |
| `parallel_one_kb` | REFUSED | `server_1_kb_4_writers` |
| `seal_batched_again` | **11.1/s** | `server_one_kb_ONE_TURN` |
| `spec_read_ahead` | **88 blk** | `server_1kb_READ_UNCOMMITTED_reader` |
| `committed_beside_it` | **0 blk** | `server_1kb_default_isolation_reader` |

## Re-measured after the path fix, and the surprise is in the LOCAL lanes

`libMVCCS.so` was rebuilt when ZiguratIP's 51 absolute paths came out,
and The Coco's own modules were rebuilt when `--release` was added to
their Cicili step, so the table above stopped describing the tree. Two
runs, minutes apart, same machine, same server, every bench knowledge
base vacuumed first (the lanes `forget` but never reclaim, and this
store had run two full suites that day):

| lane | recorded above | today, run 1 | today, run 2 | arrangement |
|---|---:|---:|---:|---|
| `verify` | 168/s | — | **233/s** | `local_no_database` |
| `validate` | 160/s | — | **249/s** | `local_no_database` |
| `seal_batched` | 15.5/s | — | 7.6/s | `server_one_kb_ONE_TURN` |
| `seal_per_turn` | 1.5/s | — | 1.2/s | `server_one_kb_per_turn` |
| `parallel_own_kbs` | 22.1/s | — | 13.5/s | `server_4_kbs_ONE_TURN_each` |
| `seal_batched_again` | 11.1/s | 12.2/s | 7.2/s | `server_one_kb_ONE_TURN` |

**Neither direction is the code, and the local lanes are the ones that
prove it.** `--release` was added to `modules/crypto/build.sh` and
`modules/math/build.sh` on the day of this run, which is exactly the
kind of change a 168-to-233 jump invites you to credit. It gets no
credit: the emitted `.c` is byte-identical with and without the flag,
and so is the `.so` — same md5 for a module built each way and for the
one actually installed. Cicili's `--release` governs how *Cicili*
compiles and links, and that script never uses Cicili's compile step;
the `-O3` that matters is on its own `gcc` line and has always been
there. The flag is passed now so nobody has to measure that again.

So a 39% and a 56% rise in two lanes that execute **identical machine
code** is the machine: this container's spare CPU, on that afternoon.

**Which corrects a claim made further down this file.** The note under
the third table says the two `--local` lanes "held at 181-183/s every
single time, because nothing they do touches the store". The first half
of that is now false — 233 and 249 are not 181-183, from the same
bytes. The second half still stands and is the useful part: those lanes
do not touch the store, so they are immune to *ageing*. Immune to
ageing is not the same as invariant, and this run is what showed the
difference.

The store lanes moving the other way needs no new explanation: 7.6/s
sits inside the spread this file already records for that lane across
runs (8.11, 6.02, 4.40), and `seal_batched_again` reading 12.2 and then
7.2 in two runs an hour apart is rule 6 restated. **Rule 6 applies to
every lane, not only the ones that write.**

The REFUSED is rule 1 doing its job. All four contended writers are
the same author sealing the same fifteen heights, so identical blocks
race for the same rows, a writer's whole transaction can lose the
commit, and on this run fewer than sixty rows landed: the harness
refuses the count rather than print a rate the store does not back.
The lane has committed all sixty on other days -- 17.8/s on a
debug-build run of the same stack, 13.6/s in the walk-era column
below -- and rule 6 keeps every run its own claim: those lines are as
real as this refusal.

The `spec_` lines are the SPECULATIVE LANE, and they are counts, not
rates: one writer held ONE HUNDRED blocks staged in ONE open
transaction for 149 seconds; a reader that named `READ_UNCOMMITTED`
through cocolog's `library(zigurat)` audited EIGHTY-EIGHT of them --
every hash recomputed, every signature checked, every parent link
followed, `ledger_audit(ok)` -- BEFORE the commit landed. Three polls
caught the writer mid-edit and audited `broken`: the price
READ_UNCOMMITTED names up front, printed on its own line and never
folded into the claim in either direction. The reader at the default
commit isolation, polled at the same moments, saw no chain at all,
and after the commit the store answered every one of the hundred.
On the debug build, same lane, the reader managed twenty-eight: the
release build is the difference, and it shows HERE, in the one lane
that is pure compute, rather than in the store rates above.
The lane still refuses itself if no staged block was audited whole
ahead of finality, or if the default-isolation reader ever saw an
unfinished chain -- and it did refuse, twice, on the way here: when
one torn poll at the top was allowed to poison the claim, and when
the fork-choice speedup closed a 40-block window in 7.087s, faster
than one poll could land. The 100-block window is the fix for the
second; the first is why torn polls print instead of deciding.

Three prior recordings stand below, per rule 6 different claims: the
same lanes on the debug build with the same incremental fork choice,
on the debug build while fork choice still WALKED every chain, and
before that on the C++ engine the Cicili one replaced (also debug):

| lane | debug, incremental | debug, walk | C++ engine | arrangement |
|---|---:|---:|---:|---|
| `verify` | 163/s | 140/s | 181/s | `local_no_database` |
| `validate` | 167/s | 138/s | 181/s | `local_no_database` |
| `seal_batched` | 14.8/s | 11.1/s | 4.4/s | `server_one_kb_ONE_TURN` |
| `seal_per_turn` | 1.5/s | 1.3/s | 1.2/s | `server_one_kb_per_turn` |
| `parallel_own_kbs` | 23.1/s | 17.5/s | 9.0/s | `server_4_kbs_ONE_TURN_each` |
| `parallel_one_kb` | REFUSED | 13.6/s | 4.3/s | `server_1_kb_4_writers` |
| `seal_batched_again` | 9.5/s | 8.4/s | 9.3/s | `server_one_kb_ONE_TURN` |

What moved and what did not, by the lanes' own mechanics: the ENGINE
replacement carried the store lanes (4.4 to 11.1 batched; the
contended lane, whose whole cost is locking, 4.3 to 13.6); the FORK
CHOICE change carried the sealing lanes again (11.1 to 14.8 batched,
17.5 to 23.1 uncoordinated), because every seal reads the head and
the head stopped costing a walk. The RELEASE build moved the store
lanes barely at all -- 14.8 to 15.5 batched, 23.1 to 22.1
uncoordinated, inside run-to-run noise -- because those lanes carry
process start-up, wire turns and the ledger's own choreography, none
of which -O3 can touch; what it moved is the speculative reader,
28 to 88 blocks audited, the one lane that is crypto from end to
end. `seal_per_turn` moved with none of the three, because ~0.42s of
process start-up times ten IS that lane; and the two `--local` lanes
never touch the store, so nothing here can move them (their drift is
the container's).

**And no sentence here says "competes with".** The ladder set that
condition before the number existed; the number exists now and the
sentence still is not written, because what these lanes measure is this
arrangement on this container.

## Rule seven, and the four runs that agree because of it

Every table above is a run against whatever the last run left behind.
Four consecutive runs, nothing changed between them, showed it:

| lane | run 1 | run 2 | run 3 | run 4 |
|---|---:|---:|---:|---:|
| `seal_batched` | 11.46 | 9.18 | 7.13 | 6.03 |
| `parallel_own_kbs` | 21.00 | 17.63 | 15.45 | 12.53 |
| `parallel_one_kb` | 12.92 | 9.22 | 7.25 | 5.82 |
| `seal_batched_again` | 11.77 | 7.56 | 6.48 | 5.70 |

**Monotone down, four lanes, four runs.** Noise does not do that. It is
the hazard cocolog's CLAUDE.md names: deleted rows are kept under MVCC
and nothing reclaims them, so each run walks past what the last one
left. `fresh` does not help — `forget` DELETES, and under MVCC a delete
is a write. A `vacuum` put the same four lanes back to 15.73, 28.28,
20.33 and 13.25, *above the first run*.

7. **A run starts from a vacuumed store.** `tps.sh` does it in setup;
   it is not timed and it is not a lane. cocolog's own `test/groups.sh`
   and `test/ruler.sh` already did this, for exactly this reason.

Four vacuumed runs afterwards, all gcc, agree within **6%** where four
had drifted 2-3x:

| lane | A | B | C | D |
|---|---:|---:|---:|---:|
| `seal_batched` | 15.13 | 15.68 | 15.37 | 15.79 |
| `parallel_own_kbs` | 26.56 | 25.01 | 25.66 | 26.08 |
| `parallel_one_kb` | 18.25 | 18.08 | 19.18 | 18.40 |
| `seal_batched_again` | 13.00 | 13.56 | 12.88 | 13.19 |

**It does not make the lanes immune, and rule 6 still stands.** In run C
`seal_batched` reads 15.37 and `seal_batched_again` 12.88 — a 16% slide
inside ONE run, on a fresh knowledge base, minutes apart. Starting from
a known point is the difference between a reading and an anecdote; it is
not the difference between a reading and a truth.

## Run E: the whole stack rebuilt with clang

Every layer is clang 18 now — ZiguratIP's C++ libraries and the server,
cocolog's binary and its five `.so`s, The Coco's nine modules. That is
not a preference: these modules are `dlopen`'d into the cocolog binary,
which itself links ZiguratIP's `libCore`, so one process holds all three
repositories' output and a mixed toolchain is two ABIs in one address
space.

Run E, vacuumed per rule seven, against run D — the last gcc run, also
vacuumed, the D column of the table above:

| lane | gcc (run D) | clang (run E) | | arrangement |
|---|---:|---:|---:|---|
| `verify` | 389.18 | **537.35** | +38% | `local_no_database` |
| `validate` | 391.39 | **530.22** | +35% | `local_no_database` |
| `seal_batched` | 15.79 | **18.38** | +16% | `server_one_kb_ONE_TURN` |
| `seal_per_turn` | 7.22 | **7.96** | +10% | `server_one_kb_per_turn` |
| `parallel_own_kbs` | 26.08 | **32.77** | +26% | `server_4_kbs_ONE_TURN_each` |
| `parallel_one_kb` | 18.40 | **22.89** | +24% | `server_1_kb_4_writers` |
| `seal_batched_again` | 13.19 | **16.18** | +23% | `server_one_kb_ONE_TURN` |

**THE TWO LOCAL LANES ARE THE ONLY HALF OF THIS I WOULD DEFEND.**
`verify` and `validate` touch no database, no socket and no other
process: they are ECDSA and the interpreter. Across the four vacuumed
gcc runs they sat within a couple of percent of each other, and a 35-38%
jump is many times that spread. It also lands where a compiler change
should — the hot loop is secp256k1 field arithmetic compiled from
Cicili's C, which is the one thing in these lanes that is pure compute.

**The five store lanes are one run against one run**, and rule seven
exists because those lanes drift. The gcc band is 6%, so +16 to +26% is
outside it and probably real; *probably* is the honest word until there
are four clang runs to put beside the four gcc ones. Rule 6 has not been
suspended for a toolchain: a store reading is comparable to another
store reading from the same run, and one clang run is not a band.

**These lanes have corrected a compiler claim before.** The section
above records `--release` being credited with a 168-to-233 rise it had
nothing to do with, because the emitted `.c` was byte-identical either
way. What is different here is that the toolchain change is real down to
the object file — `readelf -p .comment` on every `.o`, `.so` and binary
in the three repositories names clang — and the lanes that moved most
are the ones with the most compiled arithmetic in them. That is a
consistent story, not a proof.

## Seven rules

Five are in `harness.pl` and a reading that breaks one prints REFUSED
and says which:

Five are in `harness.pl` and a reading that breaks one prints REFUSED
and says which:

1. **The count is verified against rows.** A lane claims N; the harness
   counts what is actually in the store afterwards. A transaction that
   did not commit is not a transaction, and this is the only rule that
   can catch it.
2. **A run under a second is not a measurement** — that is start-up and
   scheduler noise wearing a number's clothes.
3. **The arrangement is on every line.** A rate without it is not a
   smaller truth, it is a different claim.
4. **The clock is the wall.** `date +%s.%N` is the only clock in
   `tps.sh`. CPU time makes four parallel workers look like one worker
   that got four times faster.
5. **The first run of every lane is discarded.**

The sixth is not in `harness.pl`, because no predicate can enforce it:

6. **A store reading is only comparable to another store reading from
   the same run.**

And the seventh is in `tps.sh` rather than the harness, because it is
setup and not a check: **a run starts from a vacuumed store.** Why, and
the four monotone runs that bought it, are above.

## Rule 6 pays for itself in one line

`seal_batched` and `seal_batched_again` are **the same lane, the same
arrangement, a fresh knowledge base each time**, minutes apart in one
run. On the recorded run they read **15.54/s** and **11.14/s** — 1.4×
apart, and neither is wrong; on the C++-engine recording they read
4.40/s and 9.34/s, 2.1× apart the other way. Across three runs of
that era the first of them read 8.11, 6.02 and 4.40.

Meanwhile `verify` and `validate` hold within a few percent of each
other every single time, because nothing they do touches the store.

That contrast is the harness's most useful output. cocolog's CLAUDE.md
warns that a slow suite is the store ageing; **a slow benchmark is the
same thing wearing a number**, and the only defence is to measure the
same lane twice and print both.

## The ceiling is the curve, not the store

`verify` and `validate` are within 1% of each other. Validating a block
— recompute the hash, look up the author, check the signature — costs
what one `secp256k1_verify/3` costs and nothing measurable more.

Both include ~0.42 s of process start-up in the denominator, so they are
floors; the work alone is nearer 245/s. **The harness does not subtract
it.** A number you had to adjust is a number you have to explain, and
this file explains rather than adjusts.

## The shape a single rate hides

Seconds per ten seals, as the chain grows:

| chain length | 0 | 10 | 20 | 30 | 40 |
|---|---|---|---|---|---|
| recorded run (release, incremental) | 0.95 s | 1.34 s | 2.06 s | 3.17 s | 4.69 s |
| debug build, incremental fork choice | 0.83 s | 1.43 s | 2.24 s | 3.33 s | 5.46 s |
| debug, walk fork choice, fresh store | 0.81 s | 1.64 s | 2.59 s | 3.89 s | 5.20 s |
| debug, walk fork choice, aged store | 7.01 s | 7.63 s | 8.40 s | 9.88 s | 11.86 s |

The baseline moves with the store's age. **The growth does not** — and
the incremental fork choice did not remove it, only its walk: every
seal still reads EVERY head mark (one `findall` over the marks instead
of a chain walk from each), so cost per block still rises with the
length of the chain, more shallowly per mark. What the change bought
shows in the batched lanes above, not in this shape. A single averaged
rate hides the shape completely: a system that is quick at length zero
and unusable at length ten thousand has a perfectly respectable
average.

**A tip-only filter was tried, measured, and did not help.** The idea:
a mark whose hash is some block's parent cannot win fork choice, so skip
it. It is sound — dropping non-tips changes no answer. It made no
difference at all (5.16 s against 5.17 s at length 40), because
`block/6` is not indexed on the parent, so the filter costs a scan per
mark: exactly what it saves. **It was reverted rather than shipped.**
An optimisation nobody measured is a claim, and this rung is about not
making those.

## A verified count is not a useful count

The contended lane is the most honest line in the file, in either of
its outcomes. Four writers, one knowledge base, fifteen seals each: on
the runs where **all sixty blocks commit** (17.8/s on a debug-build
run of the same stack, 4.31/s on the C++ recording), rule 1 passes and
the rate is real. On the recorded run a writer's whole transaction
lost the commit race and rule 1 REFUSED the count instead.

A committed sixty is also nearly worthless. Each writer read the head
independently, so they all sealed the **same heights** — sixty blocks
at **fifteen distinct heights**, a bush four wide rather than a chain
sixty long. Fork choice will discard three blocks in four.

No rule in the harness can tell you that. Only the arrangement can,
which is why rule 3 exists.

The uncoordinated lane — four writers, four knowledge bases, nobody
contending — is the same work at roughly twice the rate, and every block
of it is on a chain. That is the owned-object fast path, and here it is
not a feature: it is what happens when writers do not share a chain.

## mallory reads the benchmark

Every earlier rung's criminal attacked a rule. This one attacks the
**measurement**, which is the softest target on the ladder: a number
nobody can check is worth exactly what a signature nobody verifies is
worth, and it is far easier to publish.

| attack | outcome |
|---|---|
| count work that never committed | refused |
| call one transaction a hundred of them | refused |
| divide by CPU time, not the wall | refused |
| report a no-database run as a store rate | refused |
| report the cold run | refused |
| a run too short to mean anything | refused |
| a rate with nothing attached to it | refused |
| **choose which workload to run** | **succeeds** |

**The last one works and no harness can stop it.** Every reading she
picks from is honest and passes every rule; she simply publishes the
largest. The spread she is choosing from is **250/s down to 1.48/s** —
a hundred and sixty-nine-fold, all of it true.

A benchmark is only ever a statement about the workload it ran, and
choosing the workload is upstream of every rule a harness can have. The
only defence is the one this repository already uses everywhere else:
print the whole table, name the arrangement on every line, and do not
write the sentence.

## The other system on the same box

`bench/solana.sh` — a SINGLE-NODE Solana test validator
(`solana-test-validator`, agave 4.2.1) on the SAME container every
Coco lane ran on, driven by Solana's own CLI, measured under the same
six rules. The founding rule — no sentence says "competes with" until
the number is on the page — was never a refusal to compare; it was the
price of comparing, and this lane pays it.

Two runs, the first run before them discarded (rule 5), both printed
(rule 6):

| lane | run 2 | run 3 | arrangement |
|---|---:|---:|---|
| `solana_per_process` | 1.93/s | 1.93/s | `solana_1node_one_process_per_txn`, 10 of 10 confirmed |
| `solana_pipelined` | 31.7/s | 32.5/s | `solana_1node_pipelined_submits`, 100 of 100 confirmed |

What is held equal: the hardware; the finality bar (a transaction
counts only when ITS OWN SIGNATURE reads `confirmed` afterwards —
rule 1 per transaction, and the reason votes are never in the count);
the wall clock; the batching, matched lane for lane — ten CLI
processes each waiting for its own confirmation against
`seal_per_turn`, a hundred submits in waves of ten with every
signature verified against `seal_batched`; and the first run
discarded. The per-process lane pays a CLI process start-up per
transaction exactly the way `seal_per_turn` pays a cocolog one, which
is why those two lines are twins and why both are floors.

What cannot be held equal, and is printed rather than adjusted: the
unit of work. A Solana transaction is an ed25519-signed lamport
transfer between two accounts; a Coco block is a secp256k1-sealed
append to a hash chain whose every seal reads the whole head. Close
enough to put side by side, different enough that the arrangement
column is the truth of each line. The discarded warm-up transfer also
carries the destination past Solana's rent-exempt minimum, so every
measured transfer is a plain lamport move of the same shape — the
lane's own rule-1 lesson: its first version measured ten rent
refusals in 0.139s and would happily have printed 0.00/s over them.

Both tables are on the page now, arrangements and all. The units
differ and both columns say so; the sentence is still the reader's to
write — this file does not write it.

**These two lanes have not been re-run since the toolchain changed**,
and they do not need to be for their own sake: `solana-test-validator`
is a prebuilt agave binary and nothing here rebuilt it. But the Coco
side of the comparison moved — `seal_per_turn` 7.22 to 7.96,
`seal_batched` 15.79 to 18.38 — so a reader putting the columns side by
side is now comparing a clang Coco against the same Solana as before.
Same box, same rules, different day for one of the two columns. That is
rule 6 again, and it is why the arrangement column exists.

## What is not here

**The speculative lane is not "not here" any more.** The ladder aimed
at two lanes on one engine — a `READ_UNCOMMITTED` lane pipelining
verification ahead of finality, against a settlement lane at commit
isolation — and could not build it, because cocolog exposed no
isolation-level knob. It does now: `library(zigurat)` names the level
per turn (`zigurat_isolation/1`, all five), which is exactly where that
capability belonged — in cocolog, the way TLS lives in its C client —
and the lane is in `tps.sh` with its counts in the table above.

**A tuned number.** Nothing here was tuned. These are the rates the
system has, on a container, with the store in whatever state the session
left it — which is the honest starting point for tuning and not a
substitute for it.
