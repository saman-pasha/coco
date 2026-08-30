# The aggregator

Rung 7. Many chains, one node, and **none of them known in advance**.

```sh
sh hub/run.sh            # three chains, one host, narrated
cocolog -s test/hub.pl           # the same rules, checked: 41 checks
```

| file | what |
|---|---|
| `../library/hub.pl` | rules as entries, the namespace, the accumulator, the bridge |
| `chains.pl` | three chains and the rules each publishes about itself |
| `node.pl` | learn, verify, checkpoint, bridge, join |
| `mallory.pl` | eight attacks on a host that runs code it did not write |
| `run.sh` | the choreography |

`../docs/rules-to-settlement.html` is the flowchart: the same arc as a
diagram, stage by stage, with the choreography written out invocation by
invocation and the process that runs each step named beside it.

## The chain carries its own light client

A chain is a knowledge base, so one node hosts many of them the way one
server hosts many databases. Nothing about that is new. What is new is
that **the chains do not have to agree about anything** — not their
consensus, not their block shape, not their idea of a better head —
because each one publishes its own rules *as entries on itself*.

Publishing is sealing: a chain's rules are a block payload, so they are
hash-committed, signed, gossiped and identical on every node that holds
the block. There is no rule-distribution mechanism because there did not
need to be one.

In the choreography the aggregator consults `ledger/node.pl` and
`hub/node.pl` and **never consults `chains.pl`**. Everything it knows
about zeta, omega and psi it read off their blocks.

## Foreign rules are untrusted code, which rung 3 already solved

`rules_admit/3` is `contract_admit/3` — the same fence, the same
vocabulary, the same three outright refusals — plus **one rule**.

The vocabulary fits a validity rule without alteration. It already
carries `sha256`, `keccak256`, `secp256k1_verify`, `ed25519_verify`,
`block_hash/5`, `valid_block/6`, `in_turn/2` and the list and atom
builtins; it already refuses `assertz`, `getenv`, files, the clock,
`call/1`, `=..` and a variable in goal position. That it fits is not
luck: **a validity rule and a contract are the same kind of thing**, a
function of the chain.

### The one rule the contract fence never needed

A contract is alone in its own state. A chain is not. So every predicate
a chain defines must be named for that chain — `zeta` may define
`zeta_valid/1` and nothing else.

Without it, two chains would both define `valid/1` and whichever
installed second would answer for both. Worse, a hostile chain could
define `zeta_valid/1` *on purpose* and become the authority on somebody
else's chain. That is `attack_namespace_squat`, and it is refused rather
than noticed later.

## Two regimes, one host, opposite answers

| | zeta | omega |
|---|---|---|
| regime | proof of authority | stake-weighted |
| better head | the **longest** | the **heaviest** |
| given `[head(9,…,10), head(4,…,90)]` | picks 9 | picks 4 |

Same list, same host, same code path. **The difference between the two
chains is data.**

## The rules are pinned to a height

A block at height 4 is judged by the rules that were on the chain at
height 4, never by the rules published at height 9.

Without that a chain could publish permissive rules today and make last
year's invalid blocks valid, retroactively. It is the difference between
a chain that may **change** its rules — which any chain may — and one
that may **rewrite what its old blocks meant**, which none may. Both
readings are defensible until you write one down; `rules_at/3` is the one
written down.

## The anchor chain

One hash for the whole federation: a binary Merkle tree over the member
heads, sealed onto the anchor chain as an ordinary payload.

A fold would have been shorter and given the same root. What it would not
give is an **inclusion proof** — with a fold, showing that one member's
head is in the root means handing over every other member's head, and a
checkpoint that can only be verified by replaying the whole federation is
a checkpoint nobody will verify.

Two details that are not decoration: an odd level **promotes** its last
leaf rather than duplicating it (the duplicate is the classic Bitcoin
flaw — two different leaf lists hashing to one root), and each leaf
carries its **chain name**, so a checkpoint for zeta at height 4 cannot
be presented as one for omega at height 4.

## The bridge is a suspended machine

Rung 3's gas mechanism, doing a job it was not built for. A bridge
waiting for a proof is not a process, not a timer and not a poll loop —
it is a **frozen machine in a table**, and any node at all can thaw it
and go on:

```
started 'bridge1'
bridge1: suspended at 301 inference(s), 0 answer(s) this turn
a finality proof arrives from omega: released
bridge1: finished after 306 inference(s), 1 answer(s) this turn
```

`bridge_ready/3` checks the chain, the height and the block **before**
running the chain's own finality rule — a perfectly good proof for the
wrong chain is `attack_wrong_chain`, and it is the shape of a real bridge
hack rather than a hypothetical. What counts as *final* is the foreign
chain's business, so it supplies its own goal: zeta counts depth, omega
counts stake, and the host does not have to know which.

## Cross-chain provenance is one query

A fact imported from a chain keeps the chain's name beside it, and asking
where something came from is one `findall` whose shared variable does the
joining:

```
zeta   trained(d1, alice, 0.99)
omega  paid(d1, carol, 100)
```

**No schema mapping and no adapter.** Two facts that mention the same
digest already agree about it; unification is the translation layer.

## mallory attacks a host that runs code it did not write

| attack | outcome |
|---|---|
| rules that read the host's `NODE_KEY` | refused |
| rules that `assertz` onto the host | refused |
| rules that build a goal with `call/1` | refused |
| rules for somebody else's chain | refused |
| new rules applied to old blocks | refused |
| a real finality proof at the wrong bridge | refused |
| a head moved after the checkpoint | refused |
| **owning the chain** | **succeeds** |

**The last one is the most important line in this rung.** psi's published
rules are impeccable: they pass the fence, they are correctly namespaced,
the signature check is real, and the finality threshold is the same
two-thirds rung 6 uses. The host reads them, admits them, installs them
and runs them exactly as it runs zeta's.

And every validator on psi is mallory. So a block she signed is a valid
block, a head she alone voted for carries all of psi's stake, psi's own
`psi_final/2` says it is final, and the bridge thaws.

**Nothing went wrong.** The host verified correctly, under the correct
rules, and reached the correct answer to the question it was asked —
which was *is this final on psi*, not *is psi honest*. **An aggregator
cannot be stronger than the chains it aggregates**, and every bridge that
has ever been drained was drained through this door rather than through a
broken signature check. Saying so is worth more than one more refusal.

## What is not here

**A rule for admitting a member.** Any chain whose rules pass the fence
can be learned. Deciding *which* chains a hub is willing to aggregate is
a policy question — a certificate, a stake bond, a governance vote — and
this rung takes no position on it. `attack_captured_chain` is exactly
why that decision matters, and exactly why it is not a technical one.

**Rule upgrades across a fork.** `rules_at/3` pins by height on one
chain. Which rules apply to a block on a chain that forked *at* a rules
change is a question with more than one defensible answer, and none of
them is written down here.

**The bridge moves nothing.** It thaws. What an escrow releases, to
whom, and what happens if the source chain later reorganises below its
finalised block are asset questions, and this rung is about the proof.
