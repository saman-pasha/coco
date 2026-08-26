# The TPS harness

Rung 8, and the last one. Every rung before this produced a GREEN line.
None produced a number.

```sh
sh bench/tps.sh          # the lanes, measured and narrated
sh test/bench.sh         # the harness's RULES, checked: 25 checks
```

| file | what |
|---|---|
| `harness.pl` | what a reading must carry before it may be printed |
| `mallory.pl` | eight ways to inflate a number |
| `tps.sh` | the lanes |

## The number is on the page

One run, on a 4-core Linux container, against a Zigurat server on a
FRESH store -- the server running the Cicili MVCCS engine, which
replaced the C++ one:

| lane | rate | arrangement |
|---|---:|---|
| `verify` | **140/s** | `local_no_database` |
| `validate` | **138/s** | `local_no_database` |
| `seal_batched` | **11.1/s** | `server_one_kb_ONE_TURN` |
| `seal_per_turn` | **1.3/s** | `server_one_kb_per_turn` |
| `parallel_own_kbs` | **17.5/s** | `server_4_kbs_ONE_TURN_each` |
| `parallel_one_kb` | **13.6/s** | `server_1_kb_4_writers` |
| `seal_batched_again` | **8.4/s** | `server_one_kb_ONE_TURN` |

The run before it, same container, same session, on a store aged by a
whole day's suites, read 9.55 / 1.13 / 17.84 / 7.67 -- and the
contended lane was REFUSED under rule 2, because all sixty committed
blocks landed in under one second. The prior recording below is the
same lanes against the C++ engine this one replaced, on a store that
had been in use all session; rule 6 says the two tables are different
runs and stay different claims, so both stand and neither line says
more than its arrangement:

| lane | rate | arrangement (C++ engine, prior recording) |
|---|---:|---|
| `verify` | 181/s | `local_no_database` |
| `validate` | 181/s | `local_no_database` |
| `seal_batched` | 4.4/s | `server_one_kb_ONE_TURN` |
| `seal_per_turn` | 1.2/s | `server_one_kb_per_turn` |
| `parallel_own_kbs` | 9.0/s | `server_4_kbs_ONE_TURN_each` |
| `parallel_one_kb` | 4.3/s | `server_1_kb_4_writers` |
| `seal_batched_again` | 9.3/s | `server_one_kb_ONE_TURN` |

What moved and what did not, by the lanes' own mechanics: the store
lanes carry the engine, and the parallel ones carry its locking -- an
owned-object writer per knowledge base doubled, and four writers
through ONE knowledge base went from 4.3/s to 13.6/s, the one lane
whose whole cost is contention. `seal_per_turn` did not move because
~0.42s of process start-up times ten IS that lane; the two `--local`
lanes never touch the store, so the engine cannot move them and did
not (their drift is the container's); and the scaling shape further
down survives untouched, because fork choice re-derived per seal is
the ledger's cost, not the store's.

**And no sentence here says "competes with".** The ladder set that
condition before the number existed; the number exists now and the
sentence still is not written, because what these lanes measure is this
arrangement on this container.

## Six rules

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

## Rule 6 pays for itself in one line

`seal_batched` and `seal_batched_again` are **the same lane, the same
arrangement, a fresh knowledge base each time**, minutes apart in one
run. They read **4.40/s** and **9.34/s** — 2.1× apart, and neither is
wrong. Across three runs the first of them read 8.11, 6.02 and 4.40.

Meanwhile `verify` and `validate` held at **181–183/s every single
time**, because nothing they do touches the store.

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
| first run | 0.81 s | 1.64 s | 2.59 s | 3.89 s | 5.20 s |
| a later run | 7.01 s | 7.63 s | 8.40 s | 9.88 s | 11.86 s |

The baseline moves with the store's age. **The growth does not.** Cost
per block rises with the length of the chain, because `ledger_head/1`
re-derives fork choice from every head mark on every seal — and a single
averaged rate hides that completely. A system that is quick at length
zero and unusable at length ten thousand has a perfectly respectable
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

The contended lane is the most honest line in the file. Four writers,
one knowledge base, fifteen seals each: **all sixty blocks committed**,
so rule 1 passed and 4.31/s is a real rate.

It is also nearly worthless. Each writer read the head independently, so
they all sealed the **same heights** — sixty blocks at **fifteen
distinct heights**, a bush four wide rather than a chain sixty long.
Fork choice will discard three blocks in four.

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

**The speculative lane.** The ladder aimed at two lanes on one engine —
a `READ_UNCOMMITTED` lane pipelining verification ahead of finality,
against a settlement lane at commit isolation. **cocolog exposes no
isolation-level knob**, so that lane could not be built here. What the
two-lane comparison became instead is the one that *is* available today:
disjoint single-appender knowledge bases against one contended base.
Naming an isolation level per turn is a cocolog capability, and belongs
in cocolog the way TLS in its C client does.

**A tuned number.** Nothing here was tuned. These are the rates the
system has, on a container, with the store in whatever state the session
left it — which is the honest starting point for tuning and not a
substitute for it.
