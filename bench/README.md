# The TPS harness

Rung 8, and the last one. Every rung before this produced a GREEN line.
None produced a number.

```sh
sh bench/tps.sh          # the lanes, measured and narrated
cocolog -s test/bench.pl         # the harness's RULES, checked: 30 checks
sh bench/solana.sh       # the other system on the same box (SKIPs without its toolchain)
sh bench/poh.sh          # rung 5's clock: produce once, verify everywhere
```

| file | what |
|---|---|
| `harness.pl` | what a reading must carry before it may be printed |
| `mallory.pl` | eight ways to inflate a number |
| `tps.sh` | the lanes |
| `solana.sh` | the same rules pointed at a single-node Solana validator |
| `languages.md` | Python, Prolog and cocolog compared across the language aspects -- a benchmark of a different kind, under the same rule: no number that was not printed |
| `langs.sh` | cocolog against CPython on five small programs, in all three arrangements -- the harness that finally printed the sentence `languages.md` had refused to write |
| `langs/` | the ten programs, one pair per task, plus the sqlite implementation the store lanes are actually comparable to |
| `poh.sh` | rung 5's asymmetry -- one producer against four parallel verifiers, at two sizes so the ratio is a trend and not an anecdote, plus the clause oracle against the C loop. It exists because two numbers written from an ad-hoc measurement were wrong by two orders of magnitude, and nothing standing could catch that |

**THE CURRENT NUMBERS ARE FIRST, THE RULES NEXT, AND EVERY RUN EVER TAKEN
IS UNDER *The runs, oldest first*, none of them deleted.** That last part
is rule 6 applied to this file rather than to a run: a superseded reading
is a different claim, not a wrong one, and a benchmark that keeps only its
best number is a benchmark nobody can check. The order was the other way
round until the history grew past two hundred lines and a reader had to
walk all of it to learn what the numbers are today.

## Where it stands, in one place

**EVERYTHING BELOW THIS SECTION IS EITHER A RULE OR A HISTORY.** This file
grew by accretion -- each run appended, none deleted -- and that is right
for the record and wrong for a reader, who had to get to line 250 to find
out what the numbers are today. So the current readings are here, once, and
every one of them is repeated in full with its reasoning further down.

Four benchmarks live in this directory and they measure four different
things. None of them writes a sentence about another system; that is still
the reader's to write.

### The chain: blocks onto a ledger, through the store

`bench/tps.sh`, runs F and G. **The store lanes' counts were raised this
run** -- 30 blocks to 480, 15 per writer to 240 -- because cocolog's
turn-wide write batching made them finish in under a second and rule 2
refused them. Two runs, because one store reading is not a band:

| lane | run F | run G | arrangement |
|---|---:|---:|---|
| `verify` | 492.73 | 490.44 | `local_no_database` |
| `validate` | 492.37 | 492.73 | `local_no_database` |
| `seal_batched` | 239.40 | 196.32 | `server_one_kb_ONE_TURN` |
| `seal_per_turn` | 8.68 | 8.09 | `server_one_kb_per_turn` |
| `parallel_own_kbs` | 428.38 | 339.58 | `server_4_kbs_ONE_TURN_each` |
| `parallel_one_kb` | 363.09 | 230.44 | `server_1_kb_4_writers` |
| `seal_batched_again` | 221.10 | 196.96 | `server_one_kb_ONE_TURN` |

The same-count control against run E, which is the only comparison the
count change leaves intact: thirty blocks in one turn, **194.84/s today
against 18.38 then -- 10.6x at an identical arrangement.**

### The other system, the same box, the same day

`bench/solana.sh`, agave 4.2.1, three runs:

| lane | runs | arrangement |
|---|---:|---|
| `solana_per_process` | 1.95, 1.95, 1.95 | `solana_1node_one_process_per_txn`, 10 of 10 confirmed |
| `solana_pipelined` | 39.48, 39.08, 38.77 | `solana_1node_pipelined_submits`, 100 of 100 confirmed |

### The language: cocolog against CPython

`bench/langs.sh`, Run H -- a SECOND BOX (macOS, i9-9880H; every earlier
run was one Linux machine, so nothing here compares to Run C without
naming both computers). Per rep, two agreeing runs of three medians
each; the `zigurat` column is printed for the first time because it is
finally a measurement rather than a confound:

| task (one rep) | cocolog --local | cpython | cocolog --embed | cocolog zigurat | cpython + sqlite3 |
|---|---|---|---|---|---|
| nrev, 400-element list | 0.030445 s (6.4x) | 0.004751 s | 0.034478 s (7.3x) | 0.035045 s (7.4x) | -- |
| queens, all 92 solutions | 0.021928 s (11.0x) | 0.001989 s | 0.021807 s (11.0x) | 0.022148 s (11.1x) | -- |
| loop, 100 000 additions | 0.078728 s (18.7x) | 0.004218 s | 0.079328 s (18.8x) | 0.078531 s (18.6x) | -- |
| lookup, 1000 probes / 200 facts | 0.001815 s (18.7x) | 0.000097 s | 0.001850 s (19.1x) | 0.001896 s (19.5x) | 0.012222 s (126.0x) |
| sortnums, 5000 integers | 0.010233 s (6.0x) | 0.001700 s | 0.010259 s (6.0x) | 0.010241 s (6.0x) | -- |

**As a language, 6-19x CPython on this box**; as a state machine, all
three cocolog arrangements sit within a few percent of one another on
every task -- the server over a socket included -- and on the one task
with a durable Python counterpart, `--embed` answers the same thousand
probes 6.6x faster than python + sqlite3. The lookup slope stayed flat
(cocolog 0.20 s at 200 facts, 0.22 s at 20 000), with the caveat below
about what that table's ratio column may claim on this box.

### The clock: rung 5's spine

`bench/poh.sh`, Run H's box. Produce once, verify everywhere:

| ticks | produce | verify | verify x4 | speedup | loop rate |
|---:|---:|---:|---:|---:|---:|
| 8 000 000 | 2.09s | 2.08s | 0.67s | **3.1x** | 4.14M/s |
| 32 000 000 | 7.83s | 7.85s | 2.21s | **3.6x** | 4.17M/s |

and the same spine in clauses, as `library(poh)`'s oracle: ~0.4M ticks/s
against the C module's 4.3-4.4M, **11x**, the same hash at both sizes.
(The Linux box read 3.9x for four verifiers and 9-10x for the oracle;
the asymmetry is the claim, and both boxes carry it.)

### The three things these tables do not get to claim

Kept here rather than only in the run sections, because a summary that
carries the numbers and leaves the caveats behind is the thing this whole
file is against:

* **The lookup-slope table on Run H's box is start-up-dominated on both
  sides** -- every wall in it sits within 0.06 s of the lane's own boot --
  so its `1x` ratios claim boot parity, not engine parity. The engine
  reading is cocolog's own column: flat, 0.20 s to 0.22 s across a
  hundredfold more facts.
* **`verify` and `validate` are 7-8% below run E and it is not
  explained.** They are stable across both runs and historically sat within
  a couple of percent, so this is outside their own band. `langs.sh` shows
  four pure-engine tasks not regressing across the same cocolog change,
  which argues against the new clause index; what DID cause it is not
  established, and nothing is attributed.
* **Runs C and H are two computers**, a Linux box and a Mac, and none
  of their numbers compare across without naming both. Rule 6 was
  written for stores ageing between readings; a changed box is the same
  rule with a bigger hammer.


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
## The runs, oldest first

**NONE OF THEM IS DELETED WHEN THE NEXT ONE DISAGREES.** That is rule 6
applied to this file rather than to a run: a superseded reading is a
different claim, not a wrong one, and a benchmark that keeps only its best
number is a benchmark nobody can check.


### The number is on the page

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
### Re-measured after the path fix, and the surprise is in the LOCAL lanes

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
### Rule seven, and the four runs that agree because of it

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
### Run E: the whole stack rebuilt with clang

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
### Run F and G: the write batching lands, and three lanes had to be resized

cocolog batched the whole turn's writes (its STATUS.md carries the change;
`bench/langs.sh`'s Run C is what found it). The first thing that happened
here was not a bigger number -- it was **three lanes REFUSING**:

```
  seal_batched                REFUSED   server_one_kb_ONE_TURN
     why: the run was too short to mean anything
  parallel_own_kbs            REFUSED   server_4_kbs_ONE_TURN_each
  parallel_one_kb             REFUSED   server_1_kb_4_writers
```

**Rule 2 fired because the work got FASTER**, which is the first time that
has happened in this file. Thirty blocks in one turn used to take 1.6
seconds; they take **0.154**. A run under a second is not a measurement, so
the harness threw three lanes away rather than print them -- and it was
right to. So the counts went up, the third such raise here and the first
for this reason: `seal_batched` 30 -> **480**, the two parallel lanes 15 ->
**240 per writer**, `seal_batched_again` with the first, since it is the
first lane over again and has to move with it.

Two runs, both printed (rule 6), against run E:

| lane | run E | run F | run G | arrangement |
|---|---:|---:|---:|---|
| `verify` | 537.35 | 492.73 | 490.44 | `local_no_database` |
| `validate` | 530.22 | 492.37 | 492.73 | `local_no_database` |
| `seal_batched` | 18.38 | **239.40** | **196.32** | `server_one_kb_ONE_TURN` |
| `seal_per_turn` | 7.96 | 8.68 | 8.09 | `server_one_kb_per_turn` |
| `parallel_own_kbs` | 32.77 | **428.38** | **339.58** | `server_4_kbs_ONE_TURN_each` |
| `parallel_one_kb` | 22.89 | **363.09** | **230.44** | `server_1_kb_4_writers` |
| `seal_batched_again` | 16.18 | **221.10** | **196.96** | `server_one_kb_ONE_TURN` |

**THE STORE LANES' COUNTS CHANGED, SO THOSE COLUMNS ARE NOT DIRECTLY
COMPARABLE**, and saying so is the whole reason the count is part of the
arrangement: 480 blocks in one turn amortise the turn's fixed cost better
than 30 did, so some of that rise is the batch and not the fix. **The
control is a same-count reading**: thirty blocks, one turn, measured today
at **194.84/s** against run E's 18.38 -- **10.6x at an identical
arrangement.** The rest of the rise, 18.38 -> 239.40, is that number plus a
bigger batch, and the table above is honest only when read with this
paragraph.

**AND VERIFY AND VALIDATE WENT DOWN 7-8%, WHICH IS NOT EXPLAINED.** They
are the two lanes this file said it would defend, they are stable across
both runs (492.73/490.44 and 492.37/492.73 -- half a percent apart), and
across four gcc runs they historically sat within a couple of percent of
each other. So 7-8% is outside their own band and is recorded rather than
rounded off. What the evidence says: `bench/langs.sh` measured four
pure-engine tasks across the same cocolog change and none regressed --
queens 0.025445 -> 0.025366, and nrev, loop and sortnums all improved -- so
a per-call cost from the new clause index, the obvious suspect, would have
shown there and did not. What the evidence does not say is what DID cause
it. Run E is many commits and a different container state ago, and these
two lanes are mostly secp256k1 in C. **Unexplained, flagged, and not
attributed to anything.**

#### The other system, re-measured beside it

`bench/solana.sh`, same box, same agave 4.2.1 (checked, not assumed), three
runs:

| lane | runs 2-3, before | runs 1-3, now | arrangement |
|---|---:|---:|---|
| `solana_per_process` | 1.93, 1.93 | 1.95, 1.95, 1.95 | `solana_1node_one_process_per_txn`, 10 of 10 confirmed |
| `solana_pipelined` | 31.7, 32.5 | 39.48, 39.08, 38.77 | `solana_1node_pipelined_submits`, 100 of 100 confirmed |

The per-process lane did not move. The pipelined lane reads about 20%
higher, on an unchanged binary -- which is this container, not Solana, and
this file has already measured 39-56% swings between runs of byte-identical
machine code. Nothing in The Coco's changes touches this lane; it is here
because a comparison drawn against a table measured on a different day is
the error the arrangement column exists to prevent.

**Both tables are above, arrangements and all, and this file still does not
write the sentence.** The units differ -- an ed25519-signed transfer
between accounts against a secp256k1-sealed append to a hash chain -- and
`parallel_one_kb`'s own note remains the most honest line here: every block
committed, so rule 1 passed and the rate is real, and it is also nearly
worthless, because four writers reading the head independently seal the
SAME heights and fork choice will discard three blocks in four. A verified
count is not a useful count.
### The other system on the same box

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
### cocolog against CPython, on the same five programs

`sh bench/langs.sh`. This is the number `languages.md` spent a whole
section declining to state, and the answer is that **cocolog is slow --
between one and two orders of magnitude slower than CPython -- and the
spread across tasks is the useful part.**

The rules are `harness.pl`'s, adapted: every lane must answer the SAME
value or nothing is printed; reps are calibrated per lane so no reading
is start-up wearing a number's clothes; the arrangement is named on
every row; the clock is the wall. Two additions this comparison needed:
each lane is measured at R and 2R so a fixed cost can be told from a
per-unit one, and **a lane that calibrates to one rep prints its wall
time instead of a rate**, because at one rep the two cannot be
separated.

**PYTHON IS A LANGUAGE AND COCOLOG IS A LANGUAGE PLUS A STATE MACHINE**,
so the rows are read in two families. `python` against `local` is the
language comparison: an algorithm in memory, nothing kept, on both
sides. `embed` and `zigurat` are a DATABASE -- durable rows, a
committed turn, a second process that can read them -- and their fair
partner is not a dict but `sqlite`, which is in the lookup table for
exactly that reason.

Both runs are kept, oldest first, per this file's own rule. **Run A is
superseded and not deleted**: it printed two rows the one-rep rule now
refuses (a lookup ratio of 1163220x and a sort ratio of 0.0x, both
arithmetic out of two runs dominated by fixed cost), and its numbers
were taken while a stray `--embed lookup` from a killed run was burning
a core -- which is why its store lanes came out FASTER than memory, an
impossibility that is what led to the cap and the stray-killer at the
top of the script.

#### Run A, superseded (a stray process on the box, and no one-rep rule)

```
cocolog vs CPython -- same task, same answer, four arrangements
python3 3.11.15, cocolog cocolog at /home/user/cocolog/cocolog
wall clock, median of three timed runs at each of two sizes

-- nrev: one naive reverse of a 400-element list
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python        256    0.01     0.006650      1.0x    1.99  cpython_process
   local          32    0.00     0.072650     10.9x    2.58  cocolog_local_in_memory_no_database
   embed          32    0.00     0.043933      6.6x    2.02  cocolog_embedded_mvccs_fresh_store
   zigurat        32    0.00     0.046407      7.0x    2.01  cocolog_server_one_kb_emptied

-- queens: one full 8-queens search, all 92 solutions
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python       1024    0.00     0.001891      1.0x    2.01  cpython_process
   local          64    0.03     0.024636     13.0x    1.98  cocolog_local_in_memory_no_database
   embed          64    0.03     0.025542     13.5x    1.98  cocolog_embedded_mvccs_fresh_store
   zigurat        64    0.08     0.024302     12.9x    1.95  cocolog_server_one_kb_emptied

-- loop: one hundred thousand additions, one at a time
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python        512    0.04     0.003156      1.0x    1.98  cpython_process
   local          16    0.00     0.196926     62.4x    2.83  cocolog_local_in_memory_no_database
   embed          16    0.00     0.214648     68.0x    3.08  cocolog_embedded_mvccs_fresh_store
   zigurat        16    0.00     0.107104     33.9x    2.02  cocolog_server_one_kb_emptied

-- lookup: a thousand key lookups over 200 facts
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python      16384    0.00     0.000075      1.0x    2.01  cpython_process
   local         256    0.00     0.006246     83.3x    2.00  cocolog_local_in_memory_no_database
   embed           1   17.03     0.230906   3078.7x    1.01  cocolog_embedded_mvccs_fresh_store
   zigurat         1  125.52    87.241509 1163220.1x    1.41  cocolog_server_one_kb_emptied
   sqlite        512    0.00     0.004568     60.9x    2.01  cpython_sqlite3_file_indexed_committed

-- sortnums: one generate-and-sort of 5000 integers
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python       1024    0.00     0.001455      1.0x    2.02  cpython_process
   local         128    0.00     0.016594     11.4x    2.15  cocolog_local_in_memory_no_database
   embed         128    0.00     0.015543     10.7x    2.07  cocolog_embedded_mvccs_fresh_store
   zigurat         1    6.82     0.000000      0.0x    1.00  cocolog_server_one_kb_emptied

start-up alone, the same wall clock, nothing but boot and exit:
   python         0.02 s
   local          0.01 s
   embed          0.01 s
   zigurat        0.01 s

the shape of the lookup gap -- a thousand probes, three sizes:
      facts     python s    cocolog s      ratio
        200         0.02         0.13         8x
       2000         0.02         0.82        48x
      20000         0.02         8.15       428x
```

#### Run B, the reading

```
cocolog vs CPython -- same task, same answer, four arrangements
python3 3.11.15, cocolog cocolog at /home/user/cocolog/cocolog
wall clock, median of three timed runs at each of two sizes
a lane calibrated to ONE rep prints its wall time instead of a rate:
at one rep the fixed cost and the work cannot be told apart

-- nrev: one naive reverse of a 400-element list
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python        256    0.02     0.006625      1.0x    1.99  cpython_process
   local          32    0.00     0.045423      6.9x    2.02  cocolog_local_in_memory_no_database
   embed          32    0.00     0.043098      6.5x    2.02  cocolog_embedded_mvccs_fresh_store
   zigurat         1    9.50      one rep   no rate       -  cocolog_server_one_kb_emptied

-- queens: one full 8-queens search, all 92 solutions
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python       1024    0.06     0.001754      1.0x    1.97  cpython_process
   local          64    0.00     0.025445     14.5x    2.03  cocolog_local_in_memory_no_database
   embed          64    0.00     0.025698     14.7x    2.00  cocolog_embedded_mvccs_fresh_store
   zigurat         1   10.72      one rep   no rate       -  cocolog_server_one_kb_emptied

-- loop: one hundred thousand additions, one at a time
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python        512    0.01     0.003186      1.0x    1.99  cpython_process
   local          16    0.00     0.110096     34.6x    2.07  cocolog_local_in_memory_no_database
   embed          16    0.00     0.103884     32.6x    2.00  cocolog_embedded_mvccs_fresh_store
   zigurat         1    5.08      one rep   no rate       -  cocolog_server_one_kb_emptied

-- lookup: a thousand key lookups over 200 facts
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python      16384    0.00     0.000075      1.0x    2.00  cpython_process
   local         256    0.10     0.005979     79.7x    1.94  cocolog_local_in_memory_no_database
   embed           1   17.18      one rep   no rate       -  cocolog_embedded_mvccs_fresh_store
   zigurat         1       -            -         -       -  REFUSED: answered NONE, not answer(413500)
   sqlite        512    0.00     0.004530     60.4x    2.00  cpython_sqlite3_file_indexed_committed

-- sortnums: one generate-and-sort of 5000 integers
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python       1024    0.02     0.001408      1.0x    1.98  cpython_process
   local         128    0.00     0.016738     11.9x    2.17  cocolog_local_in_memory_no_database
   embed         128    0.00     0.019811     14.1x    2.40  cocolog_embedded_mvccs_fresh_store
   zigurat         1    9.00      one rep   no rate       -  cocolog_server_one_kb_emptied

start-up alone, the same wall clock, nothing but boot and exit:
   python         0.01 s
   local          0.01 s
   embed          0.01 s
   zigurat        0.01 s

the shape of the lookup gap -- a thousand probes, three sizes:
      facts     python s    cocolog s      ratio
        200         0.02         0.13         7x
       2000         0.02         0.82        49x
      20000         0.02         7.95       411x
```

**What survives both runs, and the container's own noise** -- this file
has already measured 39-56% swings between runs of byte-identical
machine code, so only order-of-magnitude claims are safe:

* **In memory, cocolog is 7-11x slower on list building, 13-15x on
  backtracking search, 11-14x on generate-and-sort, 35-62x on a tight
  counting loop, and 80-83x on a keyed lookup over 200 facts.** Search
  is its best showing, which is the thing a Prolog engine is for; the
  counting loop is its worst, which is the per-inference cost of a
  continuation-passing interpreter with no compilation step.
* **Start-up is not the reason, and the guess that it was is dead**:
  every arrangement boots in 0.01s, the same as Python.
* **Reading costs a constant; writing costs a fortune.** On every
  compute task the embedded store is within a few percent of the
  in-memory arrangement, so the database does not slow the thinking
  down. But 200 `assertz` plus a thousand probes cost 17.2s embedded,
  and over the server the same work did not finish inside a 300-second
  cap -- the answer gate refused to print a number for it, which is the
  most useful thing it could have said.
* **Durability is not free in Python either**: the sqlite lane, with an
  index and one committed transaction, is 60x slower than the dict it
  replaces.
* **The lookup gap is a slope, not a factor** -- 7x at 200 facts, 49x at
  2000, 411x at 20000, against a flat Python dict. That is
  `languages.md`'s "no clause indexing" sentence with numbers on it, and
  first-argument indexing is the one change that would move it. It is
  cocolog's to make.

#### Run C: cocolog made both changes, and the two worst readings are gone

**THE BENCHMARK WAS THE POINT.** Two of Run B's readings named specific
defects rather than a slow interpreter, both were diagnosed in cocolog, and
both were fixed THERE on their own merits with that repository's own gate --
39 of 39 GREEN, `red: 0`, no SKIPs, on a fresh store. The Coco changed
nothing; it measured, and the pillar answered.

* **The turn's writes are batched.** Writing a clause through re-sends the
  whole predicate, and the batching that made a CONSULT cheap was switched
  off before the goal ran -- so `assertz` in a loop paid a
  forget-and-resend per clause.
* **Clauses are indexed on their first argument.** A call used to COPY each
  clause onto the heap and unify its head, so a probe into a table of facts
  copied the table.

The run as it printed:

```

cocolog vs CPython -- same task, same answer, four arrangements
python3 3.11.15, cocolog cocolog at /home/user/cocolog/cocolog
wall clock, median of three timed runs at each of two sizes
a lane calibrated to ONE rep prints its wall time instead of a rate:
at one rep the fixed cost and the work cannot be told apart

-- nrev: one naive reverse of a 400-element list
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python        256    0.01     0.006611      1.0x    1.99  cpython_process
   local          64    0.00     0.102208     15.5x    3.36  cocolog_local_in_memory_no_database
   embed          32    0.06     0.035925      5.4x    1.95  cocolog_embedded_mvccs_fresh_store
   zigurat        32    0.00     0.041589      6.3x    2.08  cocolog_server_one_kb_emptied

-- queens: one full 8-queens search, all 92 solutions
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python       1024    0.06     0.001772      1.0x    1.97  cpython_process
   local          64    0.04     0.025366     14.3x    1.97  cocolog_local_in_memory_no_database
   embed          64    0.03     0.024442     13.8x    1.98  cocolog_embedded_mvccs_fresh_store
   zigurat        64    0.02     0.026193     14.8x    1.99  cocolog_server_one_kb_emptied

-- loop: one hundred thousand additions, one at a time
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python        512    0.04     0.003141      1.0x    1.98  cpython_process
   local          16    0.00     0.106376     33.9x    2.07  cocolog_local_in_memory_no_database
   embed          16    0.00     0.124958     39.8x    2.22  cocolog_embedded_mvccs_fresh_store
   zigurat        16    0.00     0.117044     37.3x    2.22  cocolog_server_one_kb_emptied

-- lookup: a thousand key lookups over 200 facts
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python      16384    0.00     0.000076      1.0x    2.00  cpython_process
   local        1024    0.00     0.003614     47.6x    2.58  cocolog_local_in_memory_no_database
   embed         512    0.06     0.002291     30.1x    1.95  cocolog_embedded_mvccs_fresh_store
   zigurat       512    0.23     0.002494     32.8x    1.85  cocolog_server_one_kb_emptied
   sqlite        512    0.06     0.004432     58.3x    1.97  cpython_sqlite3_file_indexed_committed

-- sortnums: one generate-and-sort of 5000 integers
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python       1024    0.07     0.001392      1.0x    1.96  cpython_process
   local         128    0.04     0.012735      9.1x    1.98  cocolog_local_in_memory_no_database
   embed         128    0.00     0.012850      9.2x    2.00  cocolog_embedded_mvccs_fresh_store
   zigurat       128    0.22     0.013391      9.6x    1.89  cocolog_server_one_kb_emptied

start-up alone, the same wall clock, nothing but boot and exit:
   python         0.01 s
   local          0.01 s
   embed          0.01 s
   zigurat        0.01 s

the shape of the lookup gap -- a thousand probes, three sizes:
      facts     python s    cocolog s      ratio
        200         0.02         0.06         3x
       2000         0.02         0.06         3x
      20000         0.02         0.09         4x
```

The four columns, on the lookup task -- a thousand key lookups over 200
facts, per sweep, Run B against Run C:

| | cocolog --local | cpython | cocolog --embed | cpython + sqlite3 |
|---|---|---|---|---|
| arrangement | in memory, no database | dict, in memory | MVCCS in-process | file, PRIMARY KEY index, one commit |
| **Run B** | 0.005979 s (79.7x) | 0.000075 s | one rep, **17.18 s wall** | 0.004530 s (60.4x) |
| **Run C** | 0.003614 s (47.6x) | 0.000076 s | **0.002291 s (30.1x)** | 0.004432 s (58.3x) |

And the slope, which is the reading this whole file existed to produce --
`--local`, so no store is in it at all:

| facts | Run B | Run C |
|---|---|---|
| 200 | 7x | **3x** |
| 2 000 | 49x | **3x** |
| 20 000 | 411x | **4x** |

**A ratio that grew with N was the signature.** It is flat now, and that is
the whole of the first-argument index in one line.

The other four tasks, per rep, the same four columns (only `lookup` has a
durable-Python counterpart written, so the fourth column is empty by
construction rather than by omission):

| task (one rep) | cocolog --local | cpython | cocolog --embed | cpython + sqlite3 |
|---|---|---|---|---|
| nrev, 400-element list | ~0.0387 s (5.9x) † | 0.006611 s | 0.035925 s (5.4x) | -- |
| queens, all 92 solutions | 0.025366 s (14.3x) | 0.001772 s | 0.024442 s (13.8x) | -- |
| loop, 100 000 additions | 0.106376 s (33.9x) | 0.003141 s | 0.124958 s (39.8x) | -- |
| lookup, 1000 probes / 200 facts | 0.003614 s (47.6x) | 0.000076 s | 0.002291 s (30.1x) | 0.004432 s (58.3x) |
| sortnums, 5000 integers | 0.012735 s (9.1x) | 0.001392 s | 0.012850 s (9.2x) | -- |

**Three things this run does NOT get to claim**, and they are here because
a benchmark that reports only what flatters it is not one:

* **† The `nrev local` row the harness printed is wrong**, and its own
  shape column said so: `2R/R` of **3.36**, where 2.0 is linear. It printed
  0.102208 s and 15.5x. Re-measured at R=64, three runs: 0.039391,
  0.039185, 0.038652 -- so about **5.9x**, an improvement on Run B's 6.9x.
  The R=128 point swung 0.0387-0.0624 across three runs, which is what
  poisoned the second measurement. Container noise, not a regression, and
  the table above carries the re-measurement with a dagger rather than the
  harness's number.
* **The whole `zigurat` column is CONFOUNDED and is not in the tables.**
  It went from "one rep, no rate" (5-11 s wall each, and a REFUSAL on
  lookup) to real rates -- nrev 0.041589, queens 0.026193, loop 0.117044,
  lookup 0.002494, sortnums 0.013391. But the server was restarted on a
  FRESH store between the two runs and Run B measured a 76 MB aged one.
  Some of that column is the fix and some is the restart, and this run
  cannot separate them. `--embed` is clean, because it builds a fresh store
  per run in both.
* **`embed` beating `local` on lookup is not a finding.** 0.002291 against
  0.003614, with the local row's shape at 2.58 -- inside the noise. An
  in-memory lane cannot really be slower than the same lane with a database
  under it.

What DID change, stated as narrowly as the evidence allows: the lookup
slope is flat, the embedded store went from refusing to give a rate at all
to beating Python's own durable store on the same task, and the server lane
answers a task it could not finish inside a 300-second cap. What did NOT
change is cocolog as a LANGUAGE -- 6-34x CPython on the four compute tasks,
because neither fix touches the per-inference cost of a
continuation-passing interpreter with no compilation step. That number is
still the honest one, and it is still the one nobody has attacked.

### Run H: a second box -- macOS, and the first honest zigurat column

**THE BOX CHANGED, SO NOTHING HERE COMPARES ACROSS RUNS WITHOUT SAYING
SO.** Every run above was one Linux machine; this one is a Mac -- Intel
i9-9880H (8 cores/16 threads, 2.3 GHz), 16 GB, macOS, Python 3.11.13,
cocolog at master (mapped embedded store), ZiguratIP server on the same
box with the mapped store and the (kb, name) composite index. Rule 6
applies with both hands: same-run columns compare, cross-run columns are
two claims about two computers.

And one harness finding before any number: **the pyenv shim is not
Python.** `python3` on this box resolves through a pyenv shim that costs
1.8-3.7 s per invocation before the interpreter exists; the real binary
boots in 0.13 s. The shim would have poisoned every python lane's
calibration (the shim alone clears the one-second floor), so the bench
ran with the real interpreter first on PATH. A wrapper that spends
seconds deciding which Python to run is part of nobody's language.

**Two harness findings before the numbers, both fixed in this commit:**
the arrangement-label column was a multi-line `case` inside `$(...)`,
which dash parses and macOS bash-as-sh refuses -- the first run printed
every number correctly and mangled every label beside it, so the label
is a named function now (`arr_name`); and `library(spine)` would not
LINK on a Mac at all, because The Coco's `tools/cc` wrappers had
drifted from cocolog's and lacked the Darwin
`-Wl,-undefined,dynamic_lookup` rule a loadable module needs -- the
wrappers are cocolog's own two files again, copied whole.

**What the run found:**

* **The `zigurat` column is a measurement at last.** Run B refused it,
  Run C confounded it; here it calibrated to real rep counts on all
  five tasks and landed within a few percent of `local` and `--embed`
  on every one -- nrev 7.4x, queens 11.1x, loop 18.6x, lookup 19.5x,
  sortnums 6.0x against python's 1.0x. A turn over a socket, committed
  against a store the harness empties per run, costs this workload
  nothing the two-point method can see: the pipelined client, the
  turn-wide write batch and the mapped store are the difference between
  this column and Run B's five-to-eleven-second walls.
* **As a language, 6-19x CPython on this box** -- search and sort at
  6-11x, the tight loop and the keyed probe at 19x. The Linux box read
  6-34x; the shape (search best, loop worst) survives the box change,
  the constants do not, and per rule 6 neither number corrects the
  other.
* **Durability costs Python more than it costs cocolog here.** The one
  task with a durable Python counterpart has python + sqlite3 at
  0.012222 s per thousand probes against `--embed`'s 0.001850 s --
  6.6x, same run, same promises (a file, an index, a commit).
* **The slope stayed flat, but the slope TABLE is boot-dominated on
  this box** -- every wall in it sits within 0.06 s of the lane's own
  start-up, so its `1x` ratios claim boot parity, not engine parity.
  The engine reading is cocolog's own column: 0.20 s at 200 facts,
  0.22 s at 20 000.
* **The spine produces at 4.1-4.2M ticks/s and four verifiers audit it
  3.1-3.6x faster than one** (the Linux box: 3.2M and 3.9x -- more
  cores in that ratio's denominator, per rule 6 again). The clause
  oracle agrees with the C module at both sizes and costs 11x.

#### `langs.sh`, the clean transcript

```

cocolog vs CPython -- same task, same answer, four arrangements
python3 3.11.13, cocolog cocolog at /Users/a1/Projects/GitHub/cocolog/cocolog
wall clock, median of three timed runs at each of two sizes
a lane calibrated to ONE rep prints its wall time instead of a rate:
at one rep the fixed cost and the work cannot be told apart

-- nrev: one naive reverse of a 400-element list
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python        256    0.23     0.004751      1.0x    1.84  cpython_process
   local          32    0.48     0.030445      6.4x    1.67  cocolog_local_in_memory_no_database
   embed          32    0.23     0.034478      7.3x    1.83  cocolog_embedded_mvccs_fresh_store
   zigurat        32    0.22     0.035045      7.4x    1.84  cocolog_server_one_kb_emptied

-- queens: one full 8-queens search, all 92 solutions
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python       1024    0.14     0.001989      1.0x    1.93  cpython_process
   local          64    0.17     0.021928     11.0x    1.89  cocolog_local_in_memory_no_database
   embed          64    0.19     0.021807     11.0x    1.88  cocolog_embedded_mvccs_fresh_store
   zigurat        64    0.20     0.022148     11.1x    1.88  cocolog_server_one_kb_emptied

-- loop: one hundred thousand additions, one at a time
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python        256    0.16     0.004218      1.0x    1.87  cpython_process
   local          16    0.16     0.078728     18.7x    1.88  cocolog_local_in_memory_no_database
   embed          16    0.18     0.079328     18.8x    1.88  cocolog_embedded_mvccs_fresh_store
   zigurat        16    0.23     0.078531     18.6x    1.85  cocolog_server_one_kb_emptied

-- lookup: a thousand key lookups over 200 facts
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python      16384    0.16     0.000097      1.0x    1.91  cpython_process
   local        1024    0.20     0.001815     18.7x    1.90  cocolog_local_in_memory_no_database
   embed        1024    0.17     0.001850     19.1x    1.92  cocolog_embedded_mvccs_fresh_store
   zigurat      1024    0.18     0.001896     19.5x    1.92  cocolog_server_one_kb_emptied
   sqlite        128    0.11     0.012222    126.0x    1.93  cpython_sqlite3_file_indexed_committed

-- sortnums: one generate-and-sort of 5000 integers
   lane         reps   fixed    per rep s     vs py    2R/R  arrangement
   python       1024    0.19     0.001700      1.0x    1.90  cpython_process
   local         128    0.17     0.010233      6.0x    1.89  cocolog_local_in_memory_no_database
   embed         128    0.20     0.010259      6.0x    1.87  cocolog_embedded_mvccs_fresh_store
   zigurat       128    0.21     0.010241      6.0x    1.86  cocolog_server_one_kb_emptied

start-up alone, the same wall clock, nothing but boot and exit:
   python         0.11 s
   local          0.10 s
   embed          0.11 s
   zigurat        0.16 s

the shape of the lookup gap -- a thousand probes, three sizes:
      facts     python s    cocolog s      ratio
        200         0.17         0.20         1x
       2000         0.16         0.19         1x
      20000         0.17         0.22         1x

```

The first attempt of the same day -- the one with the mangled labels --
agreed within noise on every reading (per rep: nrev 6.2/7.2/7.0x, queens
11.3/11.2/10.9x, loop 19.0/18.6/18.8x, lookup 19.2/19.4/19.6x with
sqlite 124.7x, sortnums 6.2/6.2/5.9x), so the table above rests on two
runs of three medians each rather than one.

#### `poh.sh`, as it printed

```

the PoH spine -- produce once, verify everywhere
cocolog at /Users/a1/Projects/GitHub/cocolog/cocolog, wall clock around the whole process

start-up alone (boot, load library(spine), exit): 0.16 s

the asymmetry: one producer, then one verifier, then four at once
        ticks    produce     verify  verify x4   speedup  loop rate
      8000000      2.09s      2.08s      0.67s      3.1x     4.14M/s
     32000000      7.83s      7.85s      2.21s      3.6x     4.17M/s

the same spine in clauses, as library(poh)'s oracle
        ticks     C module      clauses      ratio         agree?
       400000        0.09s        0.98s        11x      same hash
      1000000        0.23s        2.46s        11x      same hash

```
