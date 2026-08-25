# Status

Where this stands, what is proven, and what is not. Written to be picked
up again rather than to look finished. Nothing is proven HERE yet beyond
the assembly (`test/run.sh`, local and wire, `red: 0`); everything else
on this page is aimed. The missions below moved here from cocolog's
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
this repository's three materials only — Prolog modules, The Coco's own
Parsi objects, choreography — with the three pillars used and
unmodified.

1. **Crypto — the chains' primitives, in-process.** The hashes and
   curves the aggregator needs to read foreign chains, as loadable
   Cicili modules on `$COCOLOG_LIBRARY` (and, where the work belongs on
   the server, Parsi procedures over Zigurat's `Cryptography/`).
   **`library(keccak)` and `library(secp256k1)` are done**; the story
   below says what they cost and what they prove. Still ahead on this
   rung: Blake2b and RIPEMD-160 (Sui, Aptos, Bitcoin's addresses), and
   Ed25519 (Solana, Cardano, TON, Near). Polkadot's sr25519 is
   deliberately out of the first wave — Ristretto plus a transcript
   protocol is a different animal, and saying so is cheaper than
   pretending otherwise.

2. **The PoA federation ledger** (`ledger/`): a federation CA issues
   per-node certificates with append grants
   (`--permission=LEDGER::ENTRIES`); signed, sha256-chained entries;
   blocks committed with their head mark in one turn; balancer-style
   gossip; validity and fork choice as Prolog rules; a Zeytun page so
   anyone can audit the chain without a write path existing.
3. **Contracts.** A contract is a predicate; deployment is a signed
   entry whose payload is clauses. Contract goals run against a
   restricted goal vocabulary (no clock, no files, no torch) under
   `max_steps` — gas — and a failed or over-budget call rolls back with
   its turn. Long-lived contracts suspend as machines and thaw when
   their condition arrives.
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
   cross-chain provenance is a join. (Aggregating foreign ecosystems —
   Bitcoin, Ethereum — would need secp256k1 and keccak, which
   `Cryptography/` does not carry; new primitives, not new
   architecture.)
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
