# Status

Where this stands, what is proven, and what is not. Written to be picked
up again rather than to look finished. What is proven HERE is the
assembly and the first rung: `test/run.sh` GREEN with a server up, and
sixty-two crypto checks against numbers published by other people.
Everything from rung 2 down is aimed, not built. The missions below moved here from cocolog's
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
4. **Training as settlement — proof of useful work.** A contract term
   names data, architecture and seed; workers train in `--local` and
   publish signed, hash-chained parameter rows; settlement is the
   acceptance predicate over held-out data. The discipline in one
   sentence: train freely, verify deterministically, commit rows.
   Federated learning gains an audit trail — "where did this model come
   from" becomes a query.
5. **A PoH spine.** An iterated sha256 chain as a clock nobody can
   backdate — produced sequentially, verified in parallel by splitting
   the range balancer-style across coworkers.
6. **PoS and BFT votes, where the trust model wants them.** Stake is a
   query over the ledger's own entries; the leader draw is a
   deterministic function of chain state (hash-seeded — grindable, an
   accepted trade inside a certificate-gated federation, not outside
   it); a quorum certificate is a counting rule over verified
   signatures, and a turn makes vote-and-lock atomic.
7. **The aggregator.** A chain is a kb, so one node hosts many chains
   under different consensus regimes — and each chain publishes its own
   validity and fork-choice rules as entries on itself, so a foreign
   chain is verified by consulting its rules under the same fence
   contracts run under: **the chain carries its own light client**.
   Bridges are suspended-machine escrows that thaw on a rule-verified
   finality proof; an anchor chain checkpoints member heads
   accumulator-style; unification is the translation layer, so
   cross-chain provenance is a join. (Aggregating foreign ecosystems
   needed primitives `Cryptography/` does not carry — secp256k1,
   keccak, RIPEMD-160. Rung 1 built them, so what remains here is
   architecture rather than arithmetic.)
8. **The TPS harness, from day one.** Two lanes on one engine: a
   speculative lane at READ_UNCOMMITTED — peers read a block while its
   turn is still open, pipelining verification ahead of finality, dirty
   state a hint and never a settlement — and a settlement lane at
   commit isolation, with the contended few paying SERIALIZABLE through
   the claim-of-one while single-appender kbs stream uncoordinated,
   Sui's owned-object fast path as an isolation parameter. The harness
   prints transactions per second the way cocolog's hunt printed its
   944ms, and no sentence anywhere says "competes with" until that
   number is on this page.

One capability on the ladder's path belongs to a pillar, not to this
repository: **TLS in cocolog's C client**, over Zigurat's own TLS/X509,
so a cocolog node presents its certificate and the permission gate
covers node-to-node links — a ledger node never listens in the clear,
because the gate only judges what a TLS port presents. That is
cocolog's feature to build in cocolog; The Coco uses it once it exists,
and until then node-to-node links ride a TLS tunnel that presents the
certificate.

## Done here

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
