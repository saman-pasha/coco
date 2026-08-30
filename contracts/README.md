# Contracts

Rung 3. A contract is a predicate; deployment is a block; the fence is a
static check; gas is the engine's own `--steps`.

```sh
sh contracts/run.sh       # the choreography, narrated
cocolog -s test/contracts.pl      # the same thing, checked: 30 checks
```

| file | what |
|---|---|
| `../library/contract.pl` | the fence, the scoped state, the call door |
| `sources.pl` | the contracts — honest and criminal, side by side |
| `node.pl` | deploy, install from the chain, report |
| `run.sh` | the choreography |
| `token/fungible.pl` | ERC-20's shape: balances, allowances, conservation |
| `token/nonfungible.pl` | ERC-721's: one owner per id, and who may move it |
| `dex/uniswap.pl` | v2: constant-product pools, the quote, the invariant |
| `dex/uniswap-v3.pl` | v3: ranges, positions as NFTs, tick crossing, fee growth |
| `lending/aave.pl` | a pot lent against collateral, priced by an oracle |

## Contracts live here, categorised — and not in `library/`

A **library** is machinery The Coco offers: the fence itself, the money
type `library(u256)`, the encodings. Anything may load one, by name.

A **contract** is a thing deployed on a chain. It holds state, it is
called through `contract_call/2`, and its source is what a block's
payload carries. Contracts go under this directory, one subdirectory per
category — `token/`, `dex/`, `lending/` — and they are reached **by path**
rather than by `library(Name)`: a node should not be able to pick up a
pool by name without having been given it.

`coco.yaml` lists them under `contracts:`, by category, the same way it
lists modules and libraries: one declaration, and the suite reads it.

## A refusal must leave nothing behind

Every contract here writes with `assertz` and `retract`, and **Prolog
backtracking does not undo a write**. So the dangerous shape is an
operation that writes first and checks afterwards: when the check
refuses, the write is already on the ground and only an explicit undo
takes it back — and an undo is code, which can be wrong, skipped, or
retried.

Two of these contracts failed that test, and both failures were found by
an invariant rather than by reading the code:

* **`dex/uniswap-v3.pl`** moved the ticks, the pool's active liquidity
  and the position NFT into place and *paid for them afterwards*. A mint
  nobody could fund therefore raised the pool's depth to 1e18 with no
  position backing it, and every later swap priced itself off liquidity
  that did not exist. `v3_liquidity_agrees/1` — the pool's own
  liquidity against the sum of the positions spanning the price — said
  `drifted`. The fix is an ordering: **the money moves first**, so an
  unfundable operation dies at the ledger before it has touched
  anything.
* **`lending/aave.pl`** granted a loan its own loan-to-value rule
  refused. What is checked now is the ceiling itself, at the wei — 7500
  granted, 7501 refused — and, separately, that the refusal left no
  debt, no payout and no drift in the pot.

Both suites carry a section called *a refused operation leaves NOTHING
behind*, and each check there was run against the unfixed contract
first: two of the v3 ones fail on it. **A regression test that passes on
the broken code is not a regression test**, and the only way to know
which kind you have written is to break the code again and watch.

Where an operation genuinely must write, check and reverse itself, it
ends its refusal with a cut. That is not tidiness: a refusal is an
answer, not a branch to be retried.

## Deployment needed no mechanism

A contract is deployed by sealing an ordinary ledger block whose payload
is the contract's clauses, written as one atom. The block hash already
covers the payload, so the **source** is hash-committed and signed by an
authority the moment it is deployed, gossiped like anything else, and
identical on every node. There is no bytecode, no ABI, no compiler and no
deployment protocol, because a contract is already the same substance as
everything else here.

## The fence

Every goal in every clause body must be in the vocabulary or defined by
the same contract. What is **absent** from the vocabulary is the design:
no `assertz` or `retract` (the only write path is the scoped
`state_put/2`), no files, no `getenv` (a node's signing key lives there),
no clock or random — a contract that can read the time is a contract two
nodes can disagree about — no torch, no `use_module`, no `halt`.

A contract is meant to be a **function of the chain**. Everything it may
touch is its arguments or its own state, and both are rows every node
has.

Three things are refused outright, and each is a hole a whitelist alone
would leave open:

- **`call/1..8`** builds a goal at run time. A static check cannot see
  what `call(X)` will call, so a contract holding it reaches anything.
- **`=../2`** is the other way to build a goal out of parts.
- **a variable in goal position**, for the same reason: nothing to check.

And the meta-predicates that *do* get through — `,` `;` `->` `\+`
`findall/3` `forall/2` — are **recursed into**. A fence that checked
`findall(X, assertz(bad(X)), L)` by looking at the outer functor would be
no fence at all; `smuggler` in `sources.pl` is that attack.

## Isolation is structural

`state_put/2` and `state_get/2` take no contract argument. The name comes
from `contract_enter/1`, which the **node** calls — never the contract.
So a contract has no way to *say* which contract's state it means, and
two contracts each keeping a key called `n` cannot reach each other's.
`spy` tries the underlying `contract_state/3` rows directly and is
refused, because that predicate is not in the vocabulary.

The door is guarded from the outside too: `contract_call/2` refuses any
goal whose functor is not a predicate that contract actually defines, so
`contract_call(escrow, assertz(anything))` is not a call into the escrow
— it is a caller trying to run `assertz` with a contract's name in front
of it.

## All or nothing, and why it needed a mechanism

The ladder said a failed call "rolls back with its turn". **That is not
true of a failed goal in any Prolog** — `assertz` is not undone by
backtracking, so `(state_put(k,v), fail)` would leave the write behind:
half a contract's effects, committed. (The turn's transaction covers a
different accident: a process that dies mid-turn commits nothing.)

So writes are **staged**. `state_put/2` appends to a pending list;
`state_get/2` reads that list first, so a contract sees its own writes
exactly as if they had landed; and the list is flushed to rows only if
the goal succeeds. Fail or throw, and it is dropped — nothing reached the
chain, and there is nothing to undo, which also keeps the state
append-only. Rolling back by retracting would not.

## Gas

A contract that never stops is **admitted**. Nothing is wrong with its
vocabulary, and no static check can know it does not halt. `--steps`
answers it, and it is the engine's own: `start` a contract goal as a
machine, `step` it with a budget, and it suspends at the budget with the
node unharmed. `drop` discards it.

That is also what makes a **long-lived** contract possible, which is the
same mechanism read the other way: a contract waiting on a condition is a
suspended machine, three hundred bytes in a table, and any node can thaw
it and go on.

## Mallory writes contracts too

| contract | attacks | outcome |
|---|---|---|
| `thief` | reads `NODE_KEY` from the environment | refused |
| `saboteur` | asserts a ledger block directly | refused |
| `spy` | reads another contract's state rows | refused |
| `shapeshifter` | `call/1` on a caller-supplied goal | refused |
| `univ` | builds the goal with `=..` first | refused |
| `shadow` | redefines `member/2` for everyone | refused |
| `smuggler` | hides `assertz` inside `findall` | refused |
| `runaway` | loops forever | **admitted** — gas answers it |

**Two layers, two questions.** In the choreography, *alice* — a real
authority — deploys the `thief`. The ledger is content: she is entitled
to seal, and the block is valid. The **fence** refuses it. Who may deploy
and what may run are different questions with different answers, and a
system that conflated them would have to trust its authorities not to
make mistakes.

The other direction is shown too: mallory is not an authority, so her
deployment block never joins the chain, and her contract is never parsed,
never fenced, never seen.

## What is not here yet

**A gas *price*, and metering per call.** `--steps` bounds a machine,
which is the mechanism; deciding what a call costs and who pays is a
policy this rung does not take a position on.

**Contract-to-contract calls.** A contract can only call itself and the
vocabulary. Letting one contract call another needs a rule about whose
state is entered and what the fence says about the callee's name, and
that is a design decision rather than an omission.
