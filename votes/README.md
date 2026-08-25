# PoS and BFT votes

Rung 6. Who may vote is a query over the chain; a quorum is a counting
rule; and a block a quorum has precommitted is **final**.

```sh
sh votes/run.sh          # the choreography, four validators, narrated
sh test/votes.sh         # the same rules, checked: 37 checks
```

| file | what |
|---|---|
| `../library/stake.pl` | stake as a query, the thresholds, the weighted draw |
| `../library/bft.pl` | votes, quorum certificates, the lock, the evidence |
| `federation.pl` | whose key is whose — and nothing about weight |
| `node.pl` | a validator: read stake, draw, vote, lock, finalise |
| `mallory.pl` | eight attacks from inside the validator set |
| `run.sh` | the choreography |

## What this rung adds to the ledger under it

**Rung 2's federation is a file.** Every node is handed the same
`authority/2` roster, and changing the membership means redistributing
it. That is the right shape for *admission* and the wrong shape for
*weight*.

So the roster still answers one question — whose key is this — and the
**stake answers the other**. A validator's weight is `stake(Name,
Amount)` sealed as an ordinary block, and `stake_from_chain/0` reads it
back off blocks the node already holds. In the choreography **alice
seals every entry and bob reads them**: nobody distributed anything.

**Rung 2's fork choice may revisit any tip.** A longer chain wins, and
"longer" is a fact that can change tomorrow. A precommit certificate
makes a block **final**, and `extends_final/1` is one rule: a chain that
omits a finalised block is not a candidate, at any length. The
choreography ends with mallory's fork three blocks longer and losing.

## Counted by weight, never by head

| | |
|---|---|
| alice | 40 |
| bob | 25 |
| carol | 20 |
| mallory | 15 |
| dave | **0** — in the federation, and not a validator |

Total 100, quorum **67**, fault bound **33**. Two of four validators can
be short (alice + mallory is 55) and three can be enough (85). A head
count would get both wrong.

**dave is the reason the two questions are two questions.** His
signature verifies perfectly and his vote counts for nothing.

## Why 2/3, exactly

A quorum must be big enough that **two of them overlap in more than a
third of the stake**, because that overlap is the set of validators who
voted for two different blocks at one height. With `Q = 2T/3 + 1`, two
quorums share at least `2Q − T = T/3 + 2`: strictly more than the fault
bound.

That is not a convention, it is the whole safety argument — and
`culprits/3` turns it into a list of names. **Byzantine fault tolerance
here is not "the bad case cannot happen"; it is "the bad case names the
validators who caused it"**, and a name is what a slashing rule needs.

## Two phases, and the lock

A **prevote** says *I would accept this*. A **precommit** says *I am
bound to it*. A validator that has precommitted is locked, and the only
thing that releases it is a quorum of prevotes for something else in a
**later** round.

Without the second phase, two quorums at one height need nobody to have
done anything provably wrong. With it, they need a third of the stake to
have ignored its own rule.

**The vote and the lock are one goal, so they are one transaction.** A
precommit visible without its lock would be a validator that had voted
and was still free to vote again; a lock without its vote would be a
validator bound to a block it never endorsed. Neither is reachable, and
that is a property of the store rather than of care taken here.

## The draw

The leader is `sha256(Seed | Height)` reduced into the stake table, where
the seed is the head's hash. Every node computes the same leader for the
same height without being told, and a node that was offline computes it
too. Over 400 heights the draw tracks the stake — alice drawn most,
mallory least, which the suite checks as an **ordering** rather than as
exact counts, since exact counts would be a test of sha256.

And a voter checks the proposer from the block's **own parent**, not from
the reader's current head — so "was this author drawn for this height"
has the same answer forever, on every node, including one reading the
chain a year later.

## mallory is an insider

Every earlier rung's criminal was a stranger: she sealed without being an
authority, wrote contracts that were fenced out, submitted models she had
not trained. Here she is **admitted, staked and entitled to vote**,
because that is what a Byzantine fault is — and a rung about tolerating
faults that only tested strangers would have tested nothing.

| attack | what she tries | outcome |
|---|---|---|
| `attack_no_stake` | vote with dave's key, which never staked | refused |
| `attack_stuff_quorum` | one real vote, repeated four times | refused |
| `attack_forge_vote` | relabel a signature as a vote for another block | refused |
| `attack_replay_phase` | present a prevote as a precommit | refused |
| `attack_equivocate` | sign two blocks at one height | refused |
| `attack_unlock` | vote away from a lock with no proof | refused |
| `attack_double_qc` | two certificates, bought with a coalition | refused |
| `attack_grind` | bias the leader draw | **succeeds** |

**She cannot make two certificates alone, and the attack does not pretend
she can.** Fifteen is nowhere near sixty-seven, and even her best pairing
reaches fifty-five. So she buys alice and carol, and both certificates
are *real* — a node holding either is not being deceived about anything.
What the arithmetic guarantees is that they could not both exist without
an overlap heavier than a third of the stake, and `culprits/3` returns
`[alice, carol]` weighing 60 against a bound of 33.

**Equivocation is the one fault that proves itself.** Both of her votes
are valid; no checker looking at one could say a thing. What she cannot
do is stop the pair existing, and the pair is the whole of the case —
nothing to corroborate, nobody to believe.

## The grind succeeds, and is supposed to

The leader is a function of the head's hash, and the head's hash is a
function of the payload of the block that made it. So a proposer tries
payloads until the next draw favours her. With 15% of the stake she
expects about seven attempts; here the first payload that worked was the
**twenty-fourth**. There is nothing to detect: every payload she tried
was legitimate, and the one she published is a legitimate block.

**This is the price of a schedule anyone can recompute from rows.**
Inside a certificate-gated federation — where every validator is a named
party who had to be admitted and can be removed — biasing your own turn
is a cost worth paying for a draw with no beacon, no committee and no
extra round of messages. Outside one it is not, and it would want a VRF
or an unbiasable beacon. The trade is stated where it is made, in
`library(stake)`.

## What is not here

**Nobody is slashed.** `culprits/3` and `equivocation/3` produce the
evidence; burning a bond is a policy question — how much, on whose
judgement, with what appeal — that this rung takes no position on.

**There is no round timer, and so no liveness argument.** Rounds advance
because the choreography advances them. Deciding when a validator gives
up on a proposer needs a clock, and the honest form of a clock here is
rung 5's spine, not wall time.

**The genesis distribution needs an authority.** The first stake entries
are sealed by a founding authority, because a chain with no stake on it
has no quorum to admit any. Bootstrapping is a real problem and this rung
does not solve it — it inherits rung 2's federation for exactly one
block's worth of trust.
