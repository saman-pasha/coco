# Status

Where this stands, what is proven, and what is not. Written to be picked
up again rather than to look finished. What is proven HERE is the
assembly and **all eight rungs**: `test/run.sh` GREEN with a server up —
local, crypto, ledger, contracts, training, spine, votes, hub, bench,
wire — which is sixty-two crypto checks against numbers published by
other people, plus a federation ledger, contracts under a fence,
settlement that measures rather than believes, a proof-of-history spine
held to constants computed outside this project, a stake-weighted BFT
vote whose safety arithmetic names the validators who break it, an
aggregator that verifies three chains under three regimes by reading
each chain's own rules off its own blocks, and a harness that prints
transactions per second with the arrangement on every line. The ladder
is walked; what is left is depth, not rungs.
The missions below moved here from cocolog's
STATUS.md, where they were conceived — the foundations they stand on are
proven THERE, story by story, and stay there.

## The thesis

Every blockchain is structurally forbidden from learning: its contract
VM must be deterministic arithmetic, so intelligence lives off-chain
behind oracles and the chain only ever sees the oracle's word. The Coco
dissolves the wall, because here the contract language, the consensus
rules, the ledger entries and the trained models are all the same
substance — clauses and rows in a transactional store — executed by an
engine that is already deterministic and already metered. One binary
that is the engine, the store, the crypto, the trainer and the
consensus: **a ledger that learns**, and above the single ledger, a
host to many — chains as knowledge bases, each carrying its own
consensus as data — **an aggregator hub with a mind**.

## What already stands under it

Each of these is a tested story in cocolog's STATUS.md, not a hope:

* An append-only entry is a clause; `assertz` appends and nothing
  deletes, which also sidesteps the MVCC-ageing hazard entirely.
* A turn is one transaction — a block and its head mark commit
  together, the exact property `part_ready/1` proves in the balancer.
* The balancer IS gossip (seed own work, then poll peers, fetch,
  verify, adopt); the accumulator IS fan-in settlement — and its
  held-out acceptance test (`accuracy >= 90%`) is a settlement rule.
* The machines table's SERIALIZABLE claim-of-one is leader election,
  proven under twelve concurrent workers; freeze/thaw is a suspended
  contract — an escrow that waits as rows and resumes on any node.
* Model parameters are ledger-ready TODAY: rows in `cocolog::tensors`,
  in every arrangement including the embedded one. A row is hashable; a
  hashable row chains.
* ZiguratIP carries a full in-house crypto stack (`Cryptography/`):
  SHA-1..512 with HMAC, RSA with OAEP and both signature schemes
  (RSASSA-PSS, PKCS#1 v1.5), AES, X509 with the `ca` tool — and a
  certificate-borne permission system (`PERMISSIONS_MODE`): grants
  over a schema or one object are written INTO the certificate by the
  issuer, membership is a file per subject, refusal happens at the
  TLS handshake. Who may append is the server's decision, not a rule's.
* The engine's builtins are deterministic by design and `max_steps` is
  a gas meter already in the struct; the store's isolation ladder runs
  READ_UNCOMMITTED to SERIALIZABLE, per turn; the shared read side is
  parallel and proven; Zeytun is a read-only public audit plane by
  construction.

## The missions, as a ladder

Each rung is a working arrangement that ends in a GREEN line, built of
this repository's four materials only — Prolog libraries, Cicili modules
against cocolog's SDK, The Coco's own Parsi objects, choreography — with
the three pillars used and unmodified.

1. **Crypto — the chains' primitives, in-process.** The hashes and
   curves the aggregator needs to read foreign chains, as loadable
   Cicili modules on `$COCOLOG_LIBRARY` (and, where the work belongs on
   the server, Parsi procedures over Zigurat's `Cryptography/`).
   **Seven modules are done** — `library(keccak)`, `library(secp256k1)`,
   `library(sha512)`, `library(ed25519)`, `library(sha256)`,
   `library(ripemd160)` and `library(blake2b)` — and two Prolog
   libraries compose them, `library(eth)` and `library(btc)`. Between
   them: the signature schemes of Bitcoin, the whole EVM family,
   Solana, Cardano, TON, Near, Stellar and the Ed25519 halves of Cosmos,
   Sui and Aptos; Bitcoin's `hash160` and its transaction ids; and the
   Blake2b that Sui object ids, Aptos addresses, Polkadot, Cardano and
   Zcash are built from. The stories below say what they cost and what
   they prove.

   **The encodings are done too**, and in Prolog where they belong:
   `library(base58)`, `library(bech32)` and `library(bytes)`. One public
   key now reaches both of its published addresses —
   `1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH` and
   `bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4` — through four
   libraries, two compiled and two Prolog, and nothing in the calling
   text says which is which. **Rung 1 is finished** at sixty-two checks.

   Polkadot's sr25519 was deliberately out of the first wave and stays
   out: Ristretto plus a transcript protocol is a different animal, and
   saying so is cheaper than pretending otherwise.

2. **The PoA federation ledger** (`ledger/`) — **DONE**, except the
   certificate gate. Signed, sha256-chained blocks; committed with their
   head mark in one turn; balancer-style gossip; validity, the round-robin
   schedule and fork choice all as Prolog rules; **and mallory, a criminal
   node that attacks every law the chain has**. Twenty-four checks. The
   story below says what holds and what does not. Still ahead on this
   rung: the certificate gate (`--permission=LEDGER::ENTRIES`), which
   waits on TLS in cocolog's C client, and a Zeytun page — the read path
   is proven, the page is choreography not yet written.
3. **Contracts** (`contracts/`) — **DONE**. A contract is a predicate,
   deployment is a block whose payload is its clauses, the fence is a
   static check over every clause body, and gas is the engine's own
   `--steps`. Twenty-seven checks, and mallory writes contracts too.
   The story below says what holds, and corrects one thing this rung
   claimed before it was built. Still ahead: a gas *price* and metering
   per call (`--steps` is the mechanism; who pays is policy), and
   contract-to-contract calls, which need a rule about whose state is
   entered.
4. **Training as settlement — proof of useful work** (`training/`) —
   **DONE**. A task names data, architecture, seed, a hash-committed
   holdout and a threshold; workers train in `--local` and publish
   signed, hash-chained parameter rows; settlement re-measures every
   submission on the committed holdout. Eighteen checks, and mallory is
   a criminal worker now. Still ahead: nobody is PAID — turning a
   verdict into a reward is a policy question this rung takes no
   position on.
5. **A PoH spine** (`spine/`) — **DONE**. An iterated sha256 chain as a
   clock nobody can backdate: produced sequentially in one process,
   verified in parallel by splitting the range across four. Sixteen
   checks, three implementations agreeing, and mallory attacks the
   order five ways — four refused, and the fork succeeds because that
   is what a clock is. Still ahead: a spine is a lower bound on *work*,
   not a reading of a wall clock, and choosing between two honest forks
   is the ledger's question, not this rung's.
6. **PoS and BFT votes** (`votes/`) — **DONE**. Stake is a query over
   the ledger's own entries; the leader draw is a deterministic
   function of chain state; a quorum certificate is a counting rule over
   verified signatures; and a turn makes vote-and-lock atomic.
   Thirty-seven checks, finality that beats length, and mallory is an
   INSIDER for the first time — admitted, staked, voting, with one of
   her eight attacks succeeding because a hash-seeded draw is grindable.
   Still ahead: nobody is SLASHED (the evidence is produced; burning a
   bond is a policy question), and there is no round timer, so no
   liveness argument — the honest form of a clock here is rung 5's
   spine, not wall time.
7. **The aggregator** (`hub/`) — **DONE**. A chain is a kb, so one node
   hosts many under different consensus regimes; each chain publishes
   its own validity and fork-choice rules as entries on itself, and a
   foreign chain is verified by consulting those rules under the fence
   contracts run under — **the chain carries its own light client**.
   Bridges are suspended-machine escrows that thaw on a rule-verified
   finality proof; an anchor chain checkpoints member heads with a
   Merkle accumulator that gives inclusion proofs; unification is the
   translation layer, so cross-chain provenance is a join. Forty-one
   checks, and mallory's eighth attack SUCCEEDS: own every validator on
   your own chain and the host verifies you correctly, because an
   aggregator cannot be stronger than what it aggregates. Still ahead:
   nothing decides WHICH chains a hub will admit, and rule upgrades
   across a fork have no written-down answer.
8. **The TPS harness** (`bench/`) — **DONE**, with one part of it
   redirected and said so. The harness prints transactions per second
   the way cocolog's hunt printed its 944ms: six rules a reading must
   pass, the arrangement on every line, twenty-five checks on the rules
   rather than on the timings, and mallory attacking the MEASUREMENT —
   seven refused and the eighth, choosing the workload, succeeding
   because it is upstream of anything a harness can check. **The number
   is on the page and the sentence still is not written.** What could
   not be built: the speculative `READ_UNCOMMITTED` lane, because
   cocolog exposes no isolation-level knob — that is a pillar
   capability, filed below beside TLS. The two-lane comparison became
   the one that exists today: disjoint single-appender knowledge bases
   against one contended base.

Two capabilities on the ladder's path belong to a pillar, not to this
repository.

**An isolation level named per turn.** ZiguratIP's store runs the whole
ladder from READ_UNCOMMITTED to SERIALIZABLE, and cocolog uses it
internally — the coworker claim is SERIALIZABLE and hands back to READ
COMMITTED. What a caller cannot do is ask for one: there is no flag, no
option and no predicate. Rung 8's speculative lane needed exactly that
and so does not exist. It is cocolog's feature to build in cocolog, and
the shape is already there.

**TLS in cocolog's C client**, over Zigurat's own TLS/X509,
so a cocolog node presents its certificate and the permission gate
covers node-to-node links — a ledger node never listens in the clear,
because the gate only judges what a TLS port presents. That is
cocolog's feature to build in cocolog; The Coco uses it once it exists,
and until then node-to-node links ride a TLS tunnel that presents the
certificate.

## Done here

### The TPS harness: the number, and the six ways it lies

**The number is on the page.** On a 4-core container, against a server
whose store had been in use all session: `verify` 181/s and `validate`
181/s with no database in them at all; `seal_batched` 4.4/s;
`seal_per_turn` 1.2/s; `parallel_own_kbs` 9.0/s; `parallel_one_kb`
4.3/s. **And the sentence still is not written**, because what those
lanes measure is that arrangement on that container.

**Five rules live in `harness.pl` and a reading that breaks one prints
REFUSED and says which.** The count is verified against rows actually in
the store; a run under a second is not a measurement; the arrangement is
on every line; the clock is the wall; the first run of every lane is
discarded. Seven of mallory's eight attacks are one of those rules.

**The sixth rule earned itself in one line.** `seal_batched` and
`seal_batched_again` are the same lane, the same arrangement, a fresh
knowledge base each time, minutes apart in one run — and they read
**4.40/s and 9.34/s**. Neither is wrong. Across three runs the first of
them read 8.11, 6.02 and 4.40. Meanwhile the two `--local` lanes held at
181–183/s *every single time*, because nothing they do touches the
store. cocolog's CLAUDE.md says a slow suite is the store ageing; **a
slow benchmark is the same thing wearing a number**, and the only
defence is to run the same lane twice and print both.

**The ceiling is the curve, not the store.** `verify` and `validate` are
within one per cent of each other: validating a block costs what one
`secp256k1_verify/3` costs and nothing measurable more. Both include
~0.42 s of process start-up in the denominator, so they are floors — and
the harness does not subtract it, because a number you had to adjust is
a number you have to explain.

**A single averaged rate hid a shape.** Seconds per ten seals rise with
the chain's length — 0.81 to 5.20 on one run, 7.01 to 11.86 on a later
one. The baseline moves with the store's age; the growth does not.
`ledger_head/1` re-derives fork choice from every head mark on every
seal, and a system that is quick at length zero and unusable at length
ten thousand has a perfectly respectable average.

**A fix was tried, measured, and reverted.** A mark whose hash is some
block's parent cannot win fork choice — dropping non-tips is sound and
changes no answer. It made *no difference at all*: 5.16 s against
5.17 s at length 40, because `block/6` is not indexed on the parent, so
the filter costs a scan per mark, exactly what it saves. It was reverted
rather than shipped. **An optimisation nobody measured is a claim**, and
this rung is the one about not making those.

**And the most honest line in the file is a rate that passed every
rule.** The contended lane put all sixty blocks in the store, so rule 1
passed and 4.31/s is real. It is also nearly worthless: four writers
each read the head independently, so they sealed the *same* heights —
sixty blocks at **fifteen distinct heights**, a bush four wide rather
than a chain sixty long, and fork choice will discard three in four. **A
verified count is not a useful count**, and no rule in a harness can
tell you that. Only the arrangement can, which is why rule 3 exists.

**One attack succeeds, and it closes the ladder the way the others
did.** Every reading mallory picks from is honest and passes every rule;
she publishes the largest. The spread is **250/s down to 1.48/s** — a
hundred and sixty-nine-fold, all of it true. A benchmark is only ever a
statement about the workload it ran, and choosing the workload is
upstream of every rule a harness can have. The only defence is the one
this repository already uses everywhere: print the whole table, name the
arrangement on every line, and do not write the sentence.

**What could not be built, and where it belongs.** The ladder aimed at a
speculative `READ_UNCOMMITTED` lane pipelining verification ahead of
finality, against a settlement lane at commit isolation. **cocolog
exposes no isolation-level knob**, so that lane does not exist here.
Naming an isolation level per turn is a cocolog capability and belongs
in cocolog, exactly as TLS in its C client does — and the two-lane
comparison became the one available today: disjoint single-appender
knowledge bases against one contended base, 9.0/s against 4.3/s, with
the contended one writing a bush.

### The aggregator: the chain carries its own light client

**Every rule the host uses to judge a foreign chain is read off that
chain.** Publishing rules is sealing a block whose payload is the
clauses, so they are hash-committed, signed, gossiped and identical on
every node — and there is no rule-distribution mechanism because there
did not need to be one. In the choreography the aggregator consults a
ledger node and an aggregator node and **never consults `chains.pl`**;
everything it knows about zeta, omega and psi it read off their blocks.

**Foreign rules are untrusted code, and rung 3 already solved that.**
`rules_admit/3` is `contract_admit/3` with one rule added. The fence's
vocabulary fits a validity rule *without alteration* — it already carries
`block_hash/5`, `secp256k1_verify/3` and the rest, and already refuses
`assertz`, `getenv`, `call/1`, `=..` and a variable in goal position.
That it fits is not luck: a validity rule and a contract are the same
kind of thing, a function of the chain.

**The one added rule is a namespace**, and it is the thing a contract
fence never had to think about. A contract is alone in its own state; a
chain is not. Without it two chains would both define `valid/1` and the
second would answer for the first — or a hostile chain would define
`zeta_valid/1` on purpose and become the authority on somebody else's.

**Two regimes, one host, opposite answers.** Given the same list of two
heads, zeta picks the longest and omega picks the heaviest, on one node
with one code path. The difference between the two chains is data.

**The rules are pinned to a height.** A block at height 4 is judged by
the rules that were on the chain at height 4. That is the difference
between a chain that may *change* its rules, which any chain may, and one
that may *rewrite what its old blocks meant*, which none may — and both
readings are defensible until somebody writes one down.

**The bridge is rung 3's gas mechanism doing a job it was not built
for.** A bridge waiting for a proof is a frozen machine in a table:
`suspended at 301 inference(s)`, then a proof arrives and it is
`finished after 306`. Not a process, not a timer, not a poll loop. And
what counts as *final* is the foreign chain's business, so it supplies
its own goal.

**One attack succeeds, and it is the most important line in the rung.**
psi's rules are impeccable — fenced, namespaced, real signature checks,
the same two-thirds threshold rung 6 uses. And every psi validator is
mallory. The host verifies correctly, under the correct rules, and
answers the question it was asked, which was *is this final on psi* and
not *is psi honest*. **An aggregator cannot be stronger than the chains
it aggregates**, and that is the door every drained bridge went through
rather than a broken signature check.

**Two bugs found by building, and both were silent.**

`ledger_export/0` wrapped payloads in hand-written quotes around `~w`
instead of using `~q`. A payload containing a quote therefore came out
malformed, the peer's reader stopped early, and blocks vanished with
nothing logged. Rung 2's payloads were prose and never showed it; rung
7's are *source code*, and the first one broke every gossip hop in the
aggregator — the symptom was an aggregator that had learned zero chains.
`votes_export/0` had the same shape and was fixed with it: a rule that is
only right because of what its data happens to look like is a rule
waiting for different data.

And **rules come back from a payload as a variant, not the identical
term** — fresh variables, same structure — because a payload is text and
a clause's variables are local to the clause. That is right rather than a
defect, and it made the obvious round-trip check (`Cs2 == Cs`) fail. The
check that replaced it installs what came back and asks it about a real
signed block, which is the claim that actually matters; a term comparison
would have been testing the writer.

**A pillar gap, fixed in the pillar.** The namespace check is `does this
atom start with that one`, which anyone writes as `atom_concat(Prefix, _,
Name)` — and cocolog raised `instantiation_error` instead of answering.
Only the concatenating mode existed; the two splitting modes ISO 8.16.6
requires were unreachable. Fixed in cocolog on its own merits with seven
regression checks (`8021435`), including that a wrong prefix now *fails*
rather than raising. The enumerating mode `(-,-,+)` stays refused there,
deliberately: it needs a choice point, and that file's own note says a
builtin holding the choice stack would be the one piece of the system
nobody else could have written.

**What is honestly not here:** nothing decides *which* chains a hub is
willing to aggregate. Any chain whose rules pass the fence can be
learned, and `attack_captured_chain` is exactly why that decision matters
— and exactly why it is a policy question rather than a technical one.
Rule upgrades across a fork have no written-down answer either, and the
bridge thaws rather than moving anything.

### PoS and BFT votes: a quorum that names its own traitors

**Rung 2's federation is a file; a validator set here is a query.** The
roster still answers one question — whose key is this — and the stake
answers the other. A validator's weight is `stake(Name, Amount)` sealed
as an ordinary block, read back by `stake_from_chain/0` off blocks the
node already holds. In the choreography **alice seals every entry and bob
reads them**: nobody distributed anything, and there is no roster of
weights to keep in step.

**dave is why those are two questions.** He is in the federation, his
signature verifies perfectly, and his vote counts for nothing. Admission
and weight are different facts with different sources, and a system that
conflated them could not change its validator set without redistributing
a file.

**A quorum is counted by weight and never by head.** Two of four
validators can be short (alice + mallory is 55 of 100) and three can be
enough (85). The cheapest attack in the rung is one real vote repeated
four times, which a length check would pass, so the rule requires as many
distinct voters as votes before it counts a single token.

**The 2/3 threshold is not a convention, it is the whole safety
argument.** With `Q = 2T/3 + 1`, two quorums must share at least
`2Q − T = T/3 + 2` of the stake — strictly more than the fault bound. So
two certificates for different blocks at one height cannot exist without
naming the validators whose keys signed both sides, and `culprits/3` is
that list. **Byzantine fault tolerance here is not "the bad case cannot
happen"; it is "the bad case names the validators who caused it"**, and
a name is what a slashing rule needs.

**The vote and the lock are one goal, so they are one transaction.** A
precommit visible without its lock would be a validator that had voted
and was still free to vote again; a lock without its vote would be a
validator bound to a block it never endorsed. Neither is reachable —
the same guarantee `ledger_seal/1` leans on one rung down, doing a
different job.

**Finality is one rule, and it beats length.** Rung 2's fork choice may
revisit any tip; `extends_final/1` says a chain that omits a finalised
block is not a candidate at all. The choreography ends with a real
partition: mallory forks at the same height, grows her chain three blocks
longer, and loses — fork choice alone prefers her height 7, and the
finalised block at height 4 is not on it.

**mallory is an insider, for the first time on the ladder.** Every
earlier criminal was a stranger — sealing without authority, writing
fenced-out contracts, submitting models she never trained. A Byzantine
fault is an admitted party, so she holds fifteen tokens of real stake and
votes on every block. Seven of her eight attacks are refused, and the
double-certificate attack does not pretend she could act alone: fifteen
is nowhere near sixty-seven and her best pairing reaches fifty-five, so
she buys alice and carol, both certificates are genuinely valid, and the
arithmetic hands back `[alice, carol]` weighing 60 against a bound of 33.

**Equivocation is the one fault that proves itself.** Both of her votes
are valid and no checker looking at one could say a thing. What she
cannot do is stop the pair existing, and the pair is the whole of the
case — nothing to corroborate and nobody to believe.

**One attack succeeds and is in the suite as a success.** The leader is a
function of the head's hash, and the head's hash is a function of the
payload of the block that made it, so a proposer tries payloads until the
next draw favours her. With fifteen per cent of the stake she expects
about seven attempts; here the first that worked was the twenty-fourth,
and there is nothing to detect because every payload she tried was
legitimate. **That is the price of a schedule anyone can recompute from
rows**, and inside a certificate-gated federation — named parties who had
to be admitted and can be removed — it is worth paying. Outside one it is
not, and it would want a VRF. The trade is stated where it is made.

**One bug was found by writing the choreography rather than the rule.**
The first draft of "finality beats length" had mallory extending the
finalised chain instead of forking from its parent, because she had
already gossiped alice's block — so the demonstration printed *yes* to
"does the longer tip contain the finalised block" and proved nothing. The
fix was not to the rule but to the arrangement: a partition is a gossip
list that is short for a while, so who a node hears from became an
argument. **A demonstration that cannot fail is not a demonstration.**

**And one hazard is written into the code rather than remembered.**
`stake_from_chain/0` asserts rows, and entries accumulate on purpose — a
top-up is a second block, not an edit. Nothing can tell a genuine second
entry from the same entry read twice except the block it came from, so
the reader keys on the block hash. Without that, a validator that ran it
twice would hold double the stake and disagree with every peer about the
quorum, from rows that were all perfectly correct.

**What is honestly not here:** nobody is slashed — the evidence is
produced, and burning a bond is a policy question this rung takes no
position on. And there is no round timer, so there is no liveness
argument: rounds advance because the choreography advances them, and
deciding when a validator gives up on a proposer needs a clock. The
honest form of a clock here is rung 5's spine, not wall time.

### The PoH spine: a clock nobody can wind backwards

**`h(n+1) = sha256(h(n))`, and that is the whole mechanism.** To know
`h(n)` you must have computed the `n−1` hashes before it. An event is
timestamped by being mixed in — `h(n+1) = sha256(h(n) ‖ event)` — so
everything after that tick depends on the event having existed by then.

**The asymmetry is the point, and it was measured rather than asserted.**
At 32,000,000 ticks: produce in one process 9.3 s, verify in one process
10.0 s, verify in four processes 3.5 s — **2.8× on four cores**. The work
is paid once, in order, by one party, and audited by everybody at once.

**The speedup is 2.8× and not 4×, and the reason is in the README.** Every
verifier pays about 0.4 s of process start-up, so the ratio depends on
how much work it is amortised over: the same script reads 1.8× at 12M
ticks and 2.8× at 32M. **The dilution is the harness, not the
mechanism** — the tight loop alone runs at 2.57M ticks/s with start-up
subtracted. Publishing 2.8× alone would have been true and misleading;
the trend is what makes it a measurement.

**A tick through the module seam costs about 600 µs** — a goal, an atom
intern and a 64-character atom — against a hash over 32 bytes in C. That
ratio is why the loop is Cicili and not clauses, and it is the clearest
case yet for the second of The Coco's four materials.

**Three implementations, and two of them exist to disagree.**
`library(poh)` keeps the same loop in clauses as `poh_slow_run/3`, roughly four
thousand times slower and never used for anything, purely so the suite
can require the same hash from both. The third check comes from outside
the project entirely: `sha256` of 32 and of 64 zero bytes are published
constants, and the first tick and the event fold are pinned to them. An
implementation checked only against itself proves that it is consistent,
which is not the claim.

**Segments verifying is not the spine verifying.** A set of perfectly
good pieces that were never one sequence passes a segment-by-segment
check. `spine_sound/0` checks the joins too, and mallory's splice — a
genuine segment lifted from another spine — is exactly what happens when
nobody does.

**Mallory attacks order, because order is the only thing a spine sells.**
There are no signatures in a spine, so there is nothing to forge. She
claims a tick count without doing the ticks, does fewer ticks than
claimed, backdates a block to an earlier tick, splices in a foreign
segment: all four refused. **The fifth succeeds and must.** Two spines
from the same genesis, differing only in what was mixed in, both verify
— both are real work, and nothing inside a hash chain prefers one
sequence over another. That is not a hole; it is what a clock *is*. A
spine orders what is **on** it; which spine is the chain's is the
**ledger's** question, and `poh_anchor/3` is the seam between the two.

**What is honestly not here:** a spine is not a proof of wall-clock time.
A faster machine ticks faster, so "a million ticks apart" is a lower
bound on work, not a reading of the time of day — anyone quoting a spine
in seconds is quoting the producer's CPU. And it does not prove *who*:
`anchor_block/1` folds in a block hash whose contents are signed one rung
down, and the spine only says when that appeared relative to everything
else.

### Training as settlement: the chain pays for a model that works

**The discipline in one sentence: train freely, verify
deterministically, commit rows.**

Training is expensive, non-deterministic and unverifiable — two honest
workers with the same data land on entirely different weights, which the
suite proves rather than assumes, and nobody can audit a gradient step
after the fact. Evaluation is none of those things. So settlement never
asks *did you really train this*; it asks the only question with a
checkable answer: **does it work**.

**Every worker claims 0.99** — the honest ones and the liar alike — and
settlement reaches different verdicts, because it measures. alice and bob
are accepted at 1.0 from different weights; carol, who trained for one
epoch and claimed the same 0.99, is rejected at the 0.36 she actually
delivers. A worker's word about its own model is not evidence and is
never treated as any. That is what makes this proof of *useful* work
rather than proof of effort.

**A task names what is needed to CHECK an answer and nothing about how
to get one** — no epochs, no optimiser, no learning rate. And the data is
a function of the index rather than a file, so there is no dataset to
distribute, no file hash to agree on, and no way for two nodes to be
evaluating different things.

**The split between block and rows is forced.** A row must fit in a page
and a model does not, so the block carries the submission term and the
weights travel as chunked rows. The digest is the join: signed and
hash-chained inside the block, and the rows are believed only if they
hash back to it.

**The holdout is committed before any worker exists**, and re-checked on
every submission. Without that, a settler could read the submissions and
then choose the range that gave the answer it wanted — an attack nobody
would ever see in the result, because the accuracy would be real,
measured honestly, on the wrong points. It is caught by arithmetic
rather than by trust, and it is the rung's insider attack, as rung 2 had
one and rung 3 had one.

**Long compute never sits inside a database turn**, so training runs in
`--local` with no connection open and prints its weights as facts; a
second process consults them and a third seals the submission. That is
cocolog's law, learned over there in blood, obeyed here without argument.

**One attack was found by accident and kept.** An early draft had every
worker training from the task's seed, so alice and bob produced
byte-identical weights — one digest, two sets of rows under it, and a
join twice as long as it should be. Every submission failed its digest
check, and the cause was not fraud but determinism. Workers now train
from their own seed, and the duplicate rule that caught it is the same
one that catches deliberate plagiarism.

**And the rung's real payload is a query.** "Where did this model come
from" answers: the digest, the worker, the measured accuracy, the block,
and the authority that sealed it. Federated learning with an audit trail
is a `findall` over signed, hash-chained, gossiped blocks — and a second
node that did none of the training settles to the same verdicts, which
the suite checks, because determinism is the whole reason any of this
holds.

**What is honestly not here:** a worker who trains on the held-out points
cannot be caught by evaluation. The commitment stops the settler moving
the goalposts and stops a worker knowing the range in advance, but
nothing stops a worker who simply trains on everything. Catching that
needs a holdout the worker never sees, or a proof of what it trained on,
and neither is on this rung.

### Contracts: a predicate, a block, a fence, and gas

**Deployment needed no mechanism.** A contract is deployed by sealing an
ordinary ledger block whose payload is its clauses. The block hash
already covers the payload, so the *source* is hash-committed and signed
by an authority the moment it is deployed, gossiped like anything else,
identical on every node. No bytecode, no ABI, no compiler, no deployment
protocol — because a contract is already the same substance as
everything else here. That is the thesis paying out rather than being
restated.

**The fence is a static check, and it is sound rather than decorative.**
Every goal in every clause body must be in the vocabulary or defined by
the same contract. What is absent is the design: no `assertz` (the only
write path is the scoped `state_put/2`), no files, no `getenv` — a
node's signing key lives there — no clock or random, because a contract
that can read the time is a contract two nodes can disagree about.

Three things are refused outright, and each is a hole a whitelist alone
would leave open: `call/N` and `=..` both build goals at run time, so a
static check cannot see what they will call, and a variable in goal
position has nothing to check at all. The meta-predicates that do get
through — `,` `;` `->` `\+` `findall/3` `forall/2` — are recursed into,
because a fence that checked `findall(X, assertz(bad(X)), L)` by its
outer functor would be no fence.

**Isolation is structural, not polite.** `state_put/2` and `state_get/2`
take no contract argument: the name comes from `contract_enter/1`, which
the node calls and the contract cannot. A contract has no way to *say*
which contract's state it means. And the door is guarded from outside
too — `contract_call/2` refuses any goal whose functor the contract does
not define, so `contract_call(escrow, assertz(anything))` is a caller
trying to run `assertz` with a contract's name in front of it.

**One thing this rung claimed, before it was built, was wrong.** The
ladder said a failed call "rolls back with its turn". It does not:
`assertz` is not undone by backtracking in any Prolog, so
`(state_put(k,v), fail)` leaves the write behind — half a contract's
effects, committed. The turn's transaction covers a different accident,
a process that dies mid-turn. So contract writes are **staged**: pending
until the goal succeeds, readable by the contract itself as it runs, and
dropped on failure or exception. Nothing reaches the chain, so there is
nothing to undo — which also keeps the state append-only, as rolling
back by retracting would not.

**Gas is the engine's own, and it was already there.** A contract that
loops forever is *admitted* — nothing is wrong with its vocabulary and no
static check can know it halts. `--steps` answers it: the goal runs as a
machine, suspends at its budget, and the node is unharmed. That is the
same mechanism a long-lived contract needs, read the other way — a
contract waiting on a condition is a suspended machine, three hundred
bytes in a table, thawable anywhere.

**Mallory writes contracts too.** Seven refused: reading the node's
signing key out of the environment, asserting a ledger block directly,
reading another contract's state rows, `call/1` on a caller-supplied
goal, building the goal with `=..` first, redefining `member/2` for
everyone, and hiding `assertz` inside `findall`. The eighth loops
forever and is admitted, because gas is its answer and not the fence's.

**Two layers, two questions.** In the choreography *alice* — a real
authority — deploys the thief. The ledger is content: she is entitled to
seal and the block is valid. The fence refuses it. Who may deploy and
what may run are different questions with different answers, and a system
that conflated them would have to trust its authorities never to make a
mistake. The other direction is shown too: mallory is not an authority,
her deployment block never joins the chain, and her contract is never
parsed, fenced or seen.

**The escrow is a real one.** A deposit is held until the *buyer* signs a
release over the escrow's own id — a secp256k1 signature the contract
checks itself. The seller's signature is refused; the buyer's moves the
status to released; the id cannot be opened twice.

### The PoA federation ledger, and mallory

Three authorities on three knowledge bases, no centre and no daemon. A
node is not a process that runs: it is a `cocolog` invocation that seals
or syncs and exits, and everything it knows is rows.

**The consensus is clauses.** `library(poa)` is the whole of it —
`block_hash/5`, `valid_block/6`, `in_turn/2`, `better_head/2` — and every
one is a rule a node reads, a peer checks, and the chain itself could
eventually carry. The aggregator's premise arriving four rungs early.

**Five laws, and validity is not position.** The hash is recomputed
rather than believed; the author is a member; the signature is that
author's over that hash; the parent is held; the height follows. The
first three are validity and the last two are position, and they are
deliberately separate — a block can be perfectly signed and simply
early, and conflating the two is what makes a gossip loop drop blocks it
should have kept.

**The fork closes by rule.** Two authorities seal at the same height
while neither has heard the other, which is what a partition looks like
from inside: two valid chains of equal length. After gossip all three
nodes land on the same head, and on the *in-turn* one — length, then
in-turn count, then the lower hash as a coin toss every node makes the
same way. A head mark is a candidate and not an answer: every accepted
block gets one, marks are appended and never removed, and the head is
whatever fork choice says over the whole set. That is why a reorg needs
no retraction, and why arrival order — the one thing that differs
between nodes — cannot change the answer.

**Mallory.** A federation that has only ever been offered honest blocks
has not been tested, it has been rehearsed. So the criminal node is part
of the arrangement, not an afterthought in a test file: a real key, the
real protocol, and everything a real attacker starts with, because a
chain is public. Seven attacks refused — sealing as a non-member,
impersonating alice, tampering with a payload, forging a hash, replaying
a real signature onto another block, re-pointing a parent, and offering
an orphan.

**And one attack succeeds, which is the point.** For every ECDSA
signature `(r, s)` the pair `(r, n−s)` is equally valid and anyone can
compute it without the key, so mallory *can* produce a different
signature for alice's block and it *will* verify. A test suite reporting
that every attack was refused would be lying. What she gains is nothing:
the block's hash covers height, parent, author and payload and **not the
signature**, so the malleated block is the same block. Bitcoin's
transaction ids did cover the signature, and that was transaction
malleability.

**The last attack comes from inside.** A member of the federation seals
a valid block that rewrites settled history. Nothing refuses it — every
check passes, because somebody entitled to sign signed it. It is not
refused, it is **outweighed**: the rewrite is shorter, fork choice
prefers the longer chain, the head does not move. The suite asserts the
block *is* valid before asserting the head *did not* move, because the
distinction between what is valid and what is agreed is the whole of
what a consensus rule is for.

**What this cost in the pillars, and both went to the pillars.**
`library(secp256k1)` gained signing — RFC 6979 deterministic nonces
derived by HMAC-SHA256 inside the module, held to the RFC's own vectors
byte for byte, low-s per BIP-62. That is The Coco's own module and its
own work. But cocolog was missing `getenv/2` (a node's signing key must
never become a row, and a consulted file becomes rows), and cocolog was
losing `:- dynamic` declarations across processes despite its README
saying a declaration has to outlive the process. Both were diagnosed and
fixed **in cocolog**, on their own merits, with their own tests. Nothing
here works around either.

### base58 and bech32: the last step to an address

`library(base58)`, `library(bech32)` and `library(bytes)` — all three
Prolog, all three on the same library path as the compiled modules, and
`library(btc)` composing four of them into `btc_address/2` and
`btc_segwit/2`.

**This is the argument for the seam, made concrete.** Every hash and
every curve here is a compiled Cicili module, because a permutation over
a byte buffer is what C is for. An encoding is not that. base58 is a
change of base over an arbitrarily long integer and the whole of it is
long division over a list; bech32 is a BCH checksum over 5-bit values and
a change of grouping. Prolog holds a list better than C does, and the
code reads as the algorithm rather than as an implementation of it. A
caller cannot tell the two kinds apart — `btc_address` and `btc_segwit`
sit side by side, one reaching two compiled modules and two Prolog ones,
the other reaching three, and both read the same.

**One key, two spellings.** Private key 1 → secp256k1 → sha256 →
ripemd160 → base58check gives
`1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH`; the same hash160 through bech32
gives `bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4`. Both are published
constants and The Coco computed neither.

**Where the checks earn their place.** bech32's checksum is a BCH code,
not a truncated hash: it *guarantees* detection of up to four wrong
characters, where base58check's four bytes catch a typo only on average.
That guarantee lives entirely in five generator constants — and three of
the five were transcribed wrong in the first draft of the library. Every
address it produced was well-formed, self-consistent, internally
verifiable, and worthless. Only a published address caught it. The
constants are written in hex now, as BIP-173 writes them.

**And one check is a consensus rule.** BIP-350 changed the final
constant for witness version 1 and up, so a taproot address built with
the BIP-173 constant looks perfectly good and no node will accept it.
`segwit_encode/4` picks the constant from the witness version rather
than taking it as an argument — the caller cannot get it wrong because
the caller is not asked — and the suite proves the wrong one is
*rejected*, not merely not produced.

The cocolog side of this: `/\`, `\/`, `xor`, `\` and `msb` did not
exist. bech32's polymod needs them, and `X is 12 /\ 10` did not fail —
it succeeded, binding X to 12, because `/\` is a symbolic token whether
or not it is an operator, so the reader stopped early and left the rest
of the term unread. Diagnosed and fixed in cocolog, with the operator
table changed to hold each name as the text the reader sees. Nothing was
worked around here.

### Bitcoin's hashes, and a transaction from 2009

`library(blake2b)`, `library(ripemd160)` and `library(sha256)`, and
`library(btc)` composing the last two.

SHA-256 came in beside RIPEMD-160 rather than on its own account.
Almost nothing hashes with RIPEMD-160 alone: its one job in the chain
world is `hash160` — RIPEMD-160 over SHA-256 — so RIPEMD-160 without
SHA-256 is a hash with nothing to hash. BLAKE2b is here because it is
what Sui, Aptos, Polkadot, Cardano and Zcash reach for, at 256 bits
(Sui's object ids, Aptos's addresses) and at 512, which are the same
function differing in one constant.

RIPEMD-160 is two parallel lines of eighty rounds over the same message
words in different orders, with different constants and rotations,
folded together at the end in a rotation that is easy to write down
wrong. The eight tables — word orders, shift amounts, two sets of round
constants — are three hundred and twenty numbers, and one wrong entry
anywhere in them changes every digest. They were **checked in Python
against the three published vectors before a line of the module was
written**, which is the only way to trust three hundred and twenty
numbers. All eight vectors then matched on the first pass.

The end-to-end proof is a key and a transaction, and The Coco computed
neither constant. `btc_hash160` of private key 1's compressed public
key is `751e76e8199196d454941c45d1b3a323f1433bd6`, which is the payload
of `1BgGZ9tcN4rm9KBzDn7KprQz87SZ26SAMH` — an address anyone can look
up. And **the Bitcoin genesis coinbase transaction**, 204 bytes, 3
January 2009, hashes to
`4a5e1e4baab89f3a32518a88c31bc87f618f76673e2cc77ab2127b7afdeda33b`:
SHA-256 twice over and then read *backwards*, because Bitcoin displays
hashes in the reverse of the byte order it hashes them in, which is the
single most common way to get a txid wrong.

That transaction is also what found a bug in a pillar. 204 bytes is 408
hex characters, and cocolog's reader had truncated every atom at 255
characters since the project began — silently, because the reader's own
buffer grows and the atom table stores by length, and the 256 bytes
were between the two. The module was handed 255 digits, an odd count,
and correctly refused it as not hexadecimal: an error that was true of
what it received and false of what was written. Two independently
written hex decoders failing identically on the same atom is what said
the fault was upstream of both.

**The freeze held, and the freeze is what made this the right outcome.**
The Coco could have chunked the input, or read the transaction from a
file, and the genesis txid would have printed today with the truncation
still in place for everyone else. Instead the diagnosis went to cocolog
and the fix went in there, on its own merits, with its own regression
test at three lengths in the three places the copy happened. The Coco
changed nothing. cocolog's STATUS has the paragraph; `git status` in
all three pillars is empty.

### Ed25519, held to RFC 8032 byte for byte

The other half of the chain world signs with Ed25519 — Solana,
Cardano, TON, Near, Stellar, and the Ed25519 side of Cosmos, Sui and
Aptos — so `library(ed25519)` followed, and `library(sha512)` with it,
because the challenge scalar of an Ed25519 signature is a SHA-512 over
three concatenated things and no Prolog round trip belongs in the
middle of that. The hash lives in `lib-sha512.cicili` and is compiled
into both modules; its constants were generated from their definition
(the fractional parts of the square roots of the first eight primes and
the cube roots of the first eighty) rather than copied from a table,
which is the only way to be sure of eighty-eight sixteen-digit numbers.

The curve is the twisted Edwards one over 2^255 - 19, in extended
coordinates. Its addition formula is **unified** — the same expression
adds two points and doubles one — so unlike secp256k1 there is no
second formula to get subtly wrong and no branch to leak a bit. Three
things run backwards from secp256k1 and each has bitten somebody: the
encoding is little-endian, a point is 32 bytes of y with the sign of x
in the top bit of the last byte, and the message is signed whole
rather than pre-hashed.

**Signing is in this module and was deliberately not in secp256k1.**
Ed25519 is the curve a Coco node would hold its own identity on, and
its signing is deterministic — there is no nonce — which means the
published RFC 8032 signatures can be reproduced exactly. That is the
strongest test a signature scheme admits: every part of it (SHA-512,
the clamping, the scalar multiply, the point encoding, the challenge
hash, the arithmetic mod L) has to be right or the 64 bytes differ.
**Both RFC 8032 vectors come back byte for byte**, and verification
accepts them and refuses a changed message and a changed key.

**1.5ms a verification, about 650 a second** — faster than
secp256k1's, because Ed25519 needs no modular inversion mod the group
order and the Edwards addition is cheap.

An honest note on how it was built: the Python oracle written to
generate the constants disagreed with the RFC vector on the first run,
because Z and T came out swapped in its addition. The RFC's published
bytes are what caught it. An oracle is only worth what checks it.

### The chains' primitives: keccak256 and secp256k1

The aggregator's first contact with a foreign chain is READING ITS
PROOFS, and on every EVM or Bitcoin chain that comes down to one
question: who signed this. Two loadable Cicili modules answer it, both
written against cocolog's `lib/sdk.cicili`, compiled by
`modules/crypto/build.sh` into `library/*.so`, and reached by
`use_module` — **no cocolog source touched**, which is the whole point
of the fourth material.

**`library(keccak)`** is Keccak-256, not SHA3: Ethereum froze on the
original submission's `0x01` domain padding before NIST finalised its
own with `0x06`, and the two disagree on every input. `keccak256/2`
takes the bytes of a text or code list; `keccak256_hex/2` decodes hex
first, which is the one a chain needs, because RLP is arbitrary bytes
and a code list cannot carry a zero.

**`library(secp256k1)`** is the curve, from the ground up and borrowing
nothing. 256-bit numbers are eight 32-bit limbs with 64-bit
intermediates — no compiler extension, no 128-bit type. The field
modulus p = 2^256 - 2^32 - 977 gets its fast reduction (2^256 folds
back as one limb-shifted add plus a multiply by 977, repeated until the
top half empties); the group order n has no such form and gets honest
binary long division, which a verification needs only a handful of
times. Inversion is Fermat rather than extended Euclid, because a wrong
Euclid is a subtle bug and a wrong exponentiation is an obvious one.
Points live in Jacobian coordinates, so a scalar multiply pays for ONE
inversion at the end instead of one per addition — the difference
between milliseconds and seconds. Three predicates:
`secp256k1_pubkey/2`, `secp256k1_verify/3` (which FAILS on a bad
signature rather than throwing — an invalid signature is an ordinary
answer to an ordinary question), and `secp256k1_recover/4`.

**`library(eth)` is nine lines of Prolog that pull in both compiled
modules**, and it is the demonstration the loader was built for: three
of The Coco's four materials meeting in one file, resolved at run time.
`eth_address/2` is the last twenty bytes of keccak over the key;
`eth_signer/4` recovers and addresses in one step — the whole question
an EVM chain asks of a transaction.

`test/crypto.sh` holds all of it to fifteen checks: the published
Keccak vectors including a 200-byte input across the 136-byte rate; the
generator and 2G, which between them exercise every piece of the field
and point arithmetic; a good signature verifying and the same signature
against another hash failing; recovery answering the signing key and a
wrong recovery id not; and **the address of private key 1 —
`7e5f4552091a69125d5dfcb7b8c2659029395bdf`, the one number in that file
that comes from the world rather than from The Coco**. Both modules
compiled clean on the first pass and every vector matched an
independent implementation written for the purpose.

**The number, since the rule is that claims wait for one**: 200
verifications in 966ms of engine time — **4.8ms per signature, about
207 a second, single-threaded**. That is not libsecp256k1's
microseconds and does not try to be; for a hub verifying headers and
settlement proofs it is the right trade, and when it stops being one
the replacement will arrive with its own measurement.

## The disciplines

They hold across every rung, and every one was already paid for in
cocolog's stories: long compute never inside a turn; anything big
travels chunked because a row fits in a page; permission gates the door
and the signature rides in the row; dirty reads accelerate and never
finalize; and a claim is only made after `test/run.sh` — with the
server up — ends `red: 0`.
