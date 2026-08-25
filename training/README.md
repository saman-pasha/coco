# Training as settlement

Rung 4. Proof of **useful** work: the chain pays for a model that
performs, not for cycles burned.

```sh
sh training/run.sh        # the choreography, narrated
sh test/training.sh       # the same thing, checked: 18 checks
```

## The discipline in one sentence

**Train freely, verify deterministically, commit rows.**

Training is expensive, non-deterministic and unverifiable. Two honest
workers with the same data can land on entirely different weights — the
suite proves it — and nobody can audit a gradient step after the fact.
**Evaluation is none of those things.** Given the weights and the
held-out points, every node computes the same number every time.

So settlement never asks *did you really train this*. It asks the only
question with a checkable answer: **does it work**.

Every worker in the choreography claims accuracy `0.99` — the honest ones
and the liar alike — and settlement reaches different verdicts, because
it measures. A worker's word about its own model is not evidence and is
never treated as any.

## What a task is

| part | why |
|---|---|
| `data(0, 899)` | the training range — the data is a **function of the index**, not a file, so there is nothing to distribute and no way for two nodes to evaluate different things |
| `holdout(900, 1049)` | the points nobody trains on |
| `holdout_commit(Hash)` | sha256 of that range, published **before any worker exists** |
| `arch([...])` | the architecture the weights must fit |
| `seed(7)` | for rebuilding the architecture, not for training |
| `accept(accuracy, 0.90)` | the threshold |

A task names everything needed to **check** an answer and nothing about
how to get one — no epochs, no optimiser, no learning rate. A worker that
finds the weights by gradient descent, by copying a paper, or by luck is
judged identically, because the chain can check the answer and cannot
check the method.

## How a submission travels

A block carries the submission **term**; the weights travel as separate
rows. That split is forced: a row must fit in a page and a model does
not. The **digest** is the join — the block is signed and hash-chained
with the digest inside it, and the rows are believed only if they hash
back to it.

```
block  →  submission(rings, alice, <digest>, claim(accuracy, 0.99), 354)
rows   →  param_chunk(<digest>, 0..7, [50 floats each])
```

## The acceptance predicate

Five questions, cheapest first, so a bad submission never gets the
expensive work:

1. do the rows hash to the digest the signed block committed to?
2. is the holdout the one the task committed to?
3. is the parameter count this architecture's?
4. what accuracy do these weights **actually** reach?
5. is that at or above the threshold?

The worker's claim is read last and only to be reported.

## Where the compute goes, and why it is split

`train_and_export/1` runs in `--local` with **no connection open at all**
and prints its weights as facts. A second process consults them; a third
seals the submission. Three short turns, none containing three seconds of
gradient descent.

That is not fastidiousness — cocolog's CLAUDE.md carries it as law: long
compute never sits inside a database turn, because the server's idle
timeout takes the connection and the whole turn is lost. A worker that
trained inside its turn would lose the training too.

## Mallory, as a criminal worker

Rung 2 gave her a criminal node, rung 3 criminal contracts. Here nothing
she does is malformed: every submission is a well-formed, correctly
signed block from an entitled author. She is not attacking the ledger —
she is attacking **settlement**, trying to be paid for a model that does
not work.

| attack | outcome |
|---|---|
| `liar` — train one epoch, claim 0.99 | `rejected(accuracy(0.36))` |
| `junk` — submit untrained weights, claim 0.99 | `rejected(accuracy(…))` |
| `shapeshifter` — weights for another architecture | `rejected(shape(arch))` |
| forge — commit one digest, publish other rows | `rejected(digest_mismatch)` |
| plagiarise — resubmit an accepted digest as her own | `rejected(duplicate)` |
| **corrupt settler** — move the holdout after seeing submissions | `rejected(holdout_moved)` |

**The last one is not mallory.** It is whoever runs settlement, looking
at the submissions and then choosing a range that gives the answer they
wanted. Nobody would ever see it in the result — the accuracy would be
real, measured honestly, on the wrong points. The commitment is what
catches it, and it is caught by arithmetic rather than by trust.

**One attack was found by accident and kept.** An early draft had every
worker training from the task's seed, so alice and bob produced
byte-identical weights: one digest, two sets of rows under it, and a join
that came back twice as long. Every submission then failed its digest
check — not from fraud, from determinism. Workers now train from their
own seed, and the duplicate rule that caught it is the same one that
catches deliberate plagiarism.

## Where did this model come from

The rung's real payload, as one query:

```
model 5345773f by alice accuracy 1.0000 in block 0 sealed by alice
model 5bc06420 by bob   accuracy 1.0000 in block 1 sealed by bob
```

Federated learning with an audit trail is not a slogan here. It is a
`findall` over blocks that are signed, hash-chained and gossiped, and any
node can re-derive every verdict from the chain alone — the suite proves
a second node, which did none of the training, settles to the same
answers.

## What is honestly not here

**A worker who trains on the held-out points cannot be caught by
evaluation.** The commitment stops the *settler* moving the goalposts and
stops a worker knowing the range in advance, but nothing here stops a
worker who simply trains on everything. That is a real limit of
measurement-based settlement, not an oversight: catching it needs either
a holdout the worker never sees (a sealed second party) or a proof of
what the worker trained on, and neither is on this rung.

**Nobody is paid.** Settlement decides *accepted* or *rejected*. Turning
a verdict into a reward is a policy question — who funds the task, what
an accepted model is worth, what happens when two workers both succeed —
and this rung takes no position on it.
