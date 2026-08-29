# The Coco

![Coco, the engineer](art/banner.svg)

**An intelligent aggregator hub: chains as knowledge bases, consensus as
clauses, contracts that learn — built of cocolog programs.**

The Coco uses [Cicili](https://github.com/saman-pasha/cicili),
[ZiguratIP](https://github.com/saman-pasha/ziguratip) and
[cocolog](https://github.com/saman-pasha/cocolog), and **modifies none of
them** — the same discipline cocolog holds toward its own two pillars, one
level up. cocolog is a Prolog with advanced knowledge-base machinery; The
Coco is what gets built when that machinery is pointed at one problem:
hosting many ledgers, under many consensus regimes, on one engine that can
also train.

## What lives here, and what does not

Everything in this repository is one of four things:

* **Prolog** — `.pl` files consulted by the one `cocolog` binary. A
  consensus rule, a contract, a validity predicate, a fork choice: all
  clauses, all data.
* **Parsi** — The Coco's OWN schema objects, compiled by ZiguratIP's
  `parsi` compiler into a server home. This is how The Coco reaches
  capability the engine has but Prolog does not: a Parsi procedure's
  backticks call straight into Zigurat's C++ — `` `Zigurat::`SHA::`checksum ``
  is a stored procedure away, and Zigurat's `Cryptography/` carries
  SHA-1..512 with HMAC, RSA with both signature schemes, AES and X509
  with its own `ca` tool. Hashing and signing are the warrior's job,
  reached over the wire, no repository touched.
* **Cicili modules** — when The Coco needs a predicate Prolog cannot
  reach, it writes the C half in Cicili against cocolog's
  `lib/sdk.cicili`, compiles it to a shared object, and
  `use_module(library(Name))` loads it at run time. cocolog is not
  modified; the module is The Coco's, and MODULES.md over there is the
  developer guide to both ways of writing one.
* **Choreography** — `run.sh` arrangements in the mold of cocolog's
  coworker tasks: processes, knowledge bases, and the order between them.

What does NOT live here: raw C or C++, or any change to the three
pillars. C-shaped work is written in Cicili and its macros, always --
only inside ZiguratIP is there a choice between C++ and Cicili. When a
rung genuinely needs a new engine capability (TLS in cocolog's C
client, say), that capability is built in ITS repository on its own
merits, and The Coco uses it once it exists.

That rule has already paid once. Reading the Bitcoin genesis
transaction meant handing cocolog a 408-character atom, and cocolog had
been truncating atoms at 255 characters since the day it was written.
The Coco could have worked around it in an afternoon and nobody would
have known. The diagnosis went to cocolog instead, the fix landed there
with its own regression test, and the workaround was never written.

## The thesis

Every blockchain is structurally forbidden from learning: its contract VM
must be deterministic arithmetic, so intelligence lives off-chain behind
oracles. Here the contract language, the consensus rules, the ledger
entries and the trained models are the same substance — clauses and rows
in a transactional store — executed by an engine that is already
deterministic and already metered (`max_steps` is gas). A chain is a
knowledge base; one node hosts many chains under different consensus
regimes; each chain publishes its own validity rules as entries on
itself, so **the chain carries its own light client**. A ledger that
learns, and above it, a hub with a mind.

The foundations are proven in cocolog's STATUS.md, story by story: turns
as transactions, the balancer as gossip, the accumulator as fan-in
settlement with a held-out acceptance test, claim-of-one as leader
election, freeze/thaw as suspended contracts, model parameters as rows in
the tensors table, the certificate-borne permission system that decides
who may append — the certificate names the grants, and the server checks
them per operation against the peer TLS identified — and the isolation
ladder from READ_UNCOMMITTED to SERIALIZABLE, chosen per turn.

The thesis picks a language, and the pick is argued rather than assumed:
[bench/languages.md](bench/languages.md) compares Python, Prolog and
cocolog across the language aspects, the backend work, and the four
separate senses of "AI-friendly" — honestly, which means cocolog loses
often and the file says where. It opens with the everyday row, where
most language choices are actually made — ease, syntax weight,
readability, how much code a thought costs — and there the "less code"
claim is this repository's own measurement rather than an adjective:
the whole of `library/poa.pl`'s consensus is 39 non-comment lines,
outnumbered by its explanatory prose nearly three to one, with the
concessions attached (Python wins ease of entry outright; Prolog's
steepness lives in semantics, not syntax; misapplied Prolog is MORE
code, not less). What the thesis actually needs is the
rows where cocolog differs in POSITION rather than in language: a clause
is a row other processes read, a turn is a transaction, a suspended
proof is data any process can finish, and determinism and metering are
the engine's guarantee rather than the application's promise. Those four
rows are this repository's load-bearing wall; the rest of the comparison
— the everyday row included — is there so nobody mistakes the wall for
the whole house.

## The ladder

STATUS.md carries the missions in full — what stands under each and the
disciplines that hold across all of them. The short of it, each rung an
arrangement that ends in a GREEN line before it is claimed: crypto as
The Coco's own Parsi objects; the PoA federation ledger; contracts as
predicates under `max_steps`; **COCO, the native token, where gas is the
engine's own inference count rather than a price list somebody
maintains, and where a validator's weight is coin it can lose**;
training as settlement; a PoH spine; PoS and BFT votes where the trust
model wants them; the aggregator, where a chain carries its own light
client; and the TPS harness, whose number is printed before any sentence
uses it.

The token rung is where the thesis pays a bill. Every other chain has to
*write down* what each operation costs, and keep that table in step with
an implementation nobody can check it against; here the engine meters
every proof and `call_metered/4` hands the count to the clause that
charges for it — deterministically, so two nodes that never met compute
the same fee. Gas stops being a specification and becomes a
measurement.

And once the chain has money, the rung above it is the one proof of
stake was missing: `stake_entry/2` — the table `library(pos)` demands
and refuses to own — becomes a **rule over bonded COCO**, so a
validator's weight is coin it has locked and `library(bft)`'s evidence
has something to take. Two signed votes that cannot both be honest cost
their author the whole bond.

Above that, assets: a game's units as **NFTs the chain carries** —
production mints, capture transfers without the holder's consent, the
kill burns the id forever, and a unit's whole life is a query over the
blocks. Which needed the capability none of the contracts had: a
contract that cannot ask **who is calling** cannot own anything, so the
fence gained `caller/1`, answered by the node out of the signature it
already verified rather than by an argument a stranger could write.

One arrangement runs **across** rungs rather than being one of them.
`test/secure.sh` re-runs the three consensus rungs — 2, 5 and 6 — with
the node-to-store link encrypted, and requires every verdict to be
unchanged. A ladder whose rungs meant something different over TLS would
not be a ladder worth climbing.

## Running

The Coco needs its three pillars built and beside it:

```sh
git clone https://github.com/saman-pasha/cicili
git clone https://github.com/saman-pasha/ziguratip ZiguratIP
git clone https://github.com/saman-pasha/cocolog
git clone https://github.com/saman-pasha/coco Coco
```

Cloned side by side like that, **nothing needs to be exported at all**:
`coco.yaml` names the pillars as siblings of this repository, and every
script reads it through `test/config.sh`. Checkouts somewhere else are a
line of exports rather than an edit to a tracked file, because the
environment always wins over the file:

```sh
export CICILI="$HOME/Projects/GitHub/cicili"        # for building the pillars
export ZIGURATIP="$HOME/Projects/GitHub/ZiguratIP"  # a BUILT ZiguratIP
export ZIGURATIP_HOME="$ZIGURATIP/home"
export COCOLOG="$HOME/Projects/GitHub/cocolog"      # a BUILT cocolog beside it
```

Build ZiguratIP (`make` in its checkout), then cocolog (`make` and
`make schema` in its checkout), then:

```sh
cd Coco
sh test/run.sh        # every case; the wire cases SKIP without a server
```

`coco.yaml` is also where the crypto module list lives, so adding a
module is a line there and nothing else — `build.sh` and `crypto.sh`
both read it rather than carrying their own copy. Four copies of one
fact drift; one does not.

### Over an encrypted link

Every node here reaches its chain through one dial string that
`test/config.sh` builds from `coco.yaml`'s `arrangement:` block, so the
whole hub goes secure with a line:

```sh
ZIGURAT_TRANSPORT=tls ZIGURAT_CACERT=/etc/ssl/ca.crt sh test/run.sh
```

`tcp` is the binary protocol in the clear; `tls` is the **same port**
with ZiguratIP's `SERVER/TLS_MODE: TRUE` on the other end, because
TLS_MODE changes what is on 2160 rather than where it is. A client
certificate (`ZIGURAT_CERT` and `ZIGURAT_KEY`, both or neither) is
**optional** — `SERVER/TLS_CLIENT_AUTH` takes REQUIRED, OPTIONAL or NONE
— and **mandatory for permissions**: under
`SECURITY/PERMISSIONS_MODE: TRUE` a TLS peer without one is identified
with an empty permission set and reaches nothing, while a plain
connection is not identified at all and reaches everything. Turning TLS
on is what turns access control on.

**It changes the link and not one verdict**, and `test/secure.sh` is
where that is demonstrated rather than asserted. `ledger`, `spine` and
`votes` run again behind a TLS terminator, and every verdict line must
come back byte for byte identical:

| rung | consensus | verdicts | over TLS |
|---|---|---|---|
| 2 | `library(poa)` — proof of authority | 25 | identical |
| 5 | `library(poh)` — proof of history | 16 | identical |
| 6 | `library(pos)`, `library(bft)` — stake and votes | 37 | identical |

All seventy-eight, **including the three attacks that are supposed to
succeed** — ECDSA malleability, which buys nothing because a block's hash
does not cover its signature; two valid spines from one genesis, which is
what a clock *is*; and a grindable leader draw, an accepted trade inside
a gated federation. A run where mallory suddenly failed to grind would be
as much of a failure as one where a real attack got through.

That identity is not luck. Every law those rungs enforce is a law about
*content*: a hash recomputed from the block's own fields, a signature
checked against the author's published key, a tick count re-run, a quorum
weighed against a stake table read out of rows. Not one of them asks who
handed the bytes over.

Which is also the trap the case exists to close. An encrypted transport
invites a node to treat an authenticated peer as a trusted one, so
mallory arrives over a **verified** TLS connection to the very store the
honest nodes use — at the transport layer exactly as authenticated as
alice — and offers a block signed with her own real key. It is refused,
for the reason it was always refused: she is not in the federation, and a
handshake has no opinion about that.

Three more checks a plaintext run cannot make: plaintext against the TLS
port reaches no chain, so the terminator really is TLS; a node whose
`ZIGURAT_CACERT` names an unrelated authority reads **zero** blocks
rather than some; and it is told why by name — the refusal says
`certificate`, not `read failed`.

**And the public audit plane goes through a tunnel too.** The binary
port is the writers' road; the chain's public face is Zeytun, read-only
by construction, and behind a Cloudflare-shaped tunnel it is https-only.
So the same case stands a TLS edge in front of Zeytun and reads alice's
ledger through it both ways a public reader exists: `library(curl)`
fetches the pages from inside a query (`curl_get` with an `https://`
URL, the edge's certificate vouched for by name), and an `--https`
auditor warms the whole knowledge base through the edge, loads the
consensus rules from its **own** library path — never from the chain
being audited — and re-verifies every block. An auditor does not need
the writers' port, and that sentence is now tested rather than assumed.

**A missing client certificate is not a failed handshake**, and anything
built on this should know it. Under TLS 1.3 the server does not examine
what the client sent until the client has finished talking, so the
connect SUCCEEDS and the refusal arrives as an alert on the first read.
The property to check is never whether a peer connected — it is what the
peer can *reach*.

The terminator is a rehearsal and says so, exactly as cocolog's own
`test/zigurat-tls.sh` does: turning `TLS_MODE` on for real means
restarting the shared server with credentials every other case would then
have to speak. What is proved here is the client half and the consensus
half; ZiguratIP's server side is ZiguratIP's suite's business.

## Layout

```
modules/          the C halves: Cicili sources for the loadable modules,
                  one directory per group, each with a build.sh that
                  compiles them to library/*.so
modules/crypto/   keccak, secp256k1, sha256, sha512, ed25519, ripemd160,
                  blake2b -- and spine, rung 5's tick loop
modules/math/     u256: 256-bit arithmetic that raises rather than wraps
library/          THE LIBRARY PATH: the built .so's and the Prolog
                  libraries beside them. A caller cannot tell which of its
                  libraries are Prolog and which are compiled C, which is
                  the point -- btc.pl composes two of each, and poh.pl is
                  the layer over spine.so
coco.yaml         the one declaration -- pillars, paths, the knowledge
                  base, the module list, the suite. Read by every script
ledger/           rung 2: the PoA federation ledger -- the federation,
                  a node, the choreography, and mallory the criminal node
contracts/        rung 3: a contract is a predicate -- the sources
                  (honest and criminal), the node, the choreography.
                  token/ is ERC-20 and ERC-721, dex/ is Uniswap v2 and
                  v3, lending/ is Aave
training/         rung 4: training as settlement -- the task, the
                  worker, mallory the criminal worker
spine/            rung 5: the PoH spine -- the producer, the parallel
                  verifiers, and mallory attacking a clock
votes/            rung 6: PoS and BFT votes -- stake read off the chain,
                  quorum certificates, finality, and mallory INSIDE the
                  validator set
hub/              rung 7: the aggregator -- three chains under three
                  regimes, each publishing its own rules as entries on
                  itself, verified by a host that consulted none of them
bench/            rung 8: the TPS harness -- the lanes, the six rules a
                  reading must pass to be printed, and mallory attacking
                  the measurement rather than the rules; languages.md
                  compares Python, Prolog and cocolog under the same
                  no-unprinted-numbers rule
docs/             diagrams worth keeping: seal-to-settlement.html traces
                  one payload through every gate, rungs 2 to 4;
                  tick-to-settlement.html does the same for rung 5,
                  and rung 6 twice over -- stake-to-settlement.html from
                  the stake's side, vote-to-settlement.html from the
                  vote's; rules-to-settlement.html for rung 7
test/             the arrangements that hold it GREEN; config.sh reads
                  coco.yaml and is sourced, not run, and builds the one
                  dial string every node reaches its store through;
                  secure.sh re-runs rungs 2, 5 and 6 over TLS
art/              the banner -- Coco, the engineer, one of the three
```

The layout grows a directory per rung as each rung is climbed; nothing is
checked in before its GREEN line.

**`spine/` IS A RUNG, NOT A MODULE**, and it is the one name in the tree
that is both — which is worth saying because the mistake is a natural one.
`library(spine)` is C, and its source has always been
`modules/crypto/spine.cicili`; `spine/` is rung 5's *choreography*, the
same shape as `ledger/`, `votes/`, `hub/` and `training/` — a README, a
node, a mallory and a `run.sh`. The module is already where modules go.

## The libraries

Every one is reached the same way — `use_module(library(Name))` — and
nothing at the call site says whether the answer came from C or from
clauses. That is the seam, not a detail of it.

**COMPILED, from `modules/`:**

| | |
|---|---|
| `library(u256)` | 256-bit add, sub, mul, div, mod, muldiv, sqrt — **none of them wrapping**. cocolog's integers are 64 bits and wrap in silence: `1000000000000000000 * 997` answers `875820019684212736`, so the first product a Uniswap swap computes at ordinary token scale is already a wrong number nobody was told about. These raise instead |
| `library(keccak)` | Ethereum's, with the `0x01` pad — not NIST SHA3 |
| `library(secp256k1)` | the curve: derive, verify, recover |
| `library(sha256)`, `library(ripemd160)` | Bitcoin's, and the two halves of hash160 |
| `library(sha512)`, `library(ed25519)` | RFC 8032, deterministic, byte for byte |
| `library(blake2b)` | Sui, Aptos, Polkadot, Cardano, Zcash |
| `library(spine)` | rung 5's tick loop, the event fold and the segment check |

**CLAUSES, in `library/`:**

| | |
|---|---|
| `library(bytes)` | hex text to byte lists and back |
| `library(base58)`, `library(bech32)` | base58check; bech32, bech32m, segwit addresses |
| `library(eth)` | keccak + secp256k1: Ethereum addresses, who signed |
| `library(btc)` | sha256 + ripemd160 + base58 + bech32: Bitcoin |
| `library(poa)` | rung 2: proof of authority, as rules |
| `library(contract)` | rung 3: the fence, scoped state, the call door |
| `library(settle)` | rung 4: the acceptance predicate over held-out data |
| `library(poh)` | rung 5: segments, parallel verification, the ledger seam |
| `library(pos)`, `library(bft)` | rung 6: stake as a query and the leader draw; votes, quorum certificates, the lock, the evidence |
| `library(hub)` | rung 7: rules as entries, the namespace, the anchor, the bridge |
| `library(tickmath)` | prices as ticks, ticks as square roots — v3's arithmetic |

`coco.yaml` is where the two lists actually live, and both `build.sh` and
the suite read them from there: adding a module is adding a line, and the
suite then proves every one of them LOADS. A `.pl` with a syntax error in
a clause nothing calls is invisible until the day something calls it.

### And cocolog's own, on the same path

`$COCOLOG_LIBRARY` is two directories — The Coco's `library/`, then
cocolog's — so everything cocolog ships as a loadable library is reachable
from a contract or a node without anything being copied here:

| | |
|---|---|
| `library(tcp)`, `library(http)`, `library(httpd)` | sockets, HTTP/1.1 as a grammar, and a server whose pages are clauses |
| `library(thread)` | threads that share nothing, channels that copy |
| `library(json)`, `library(xml)`, `library(html)` | a term as a document and a document as a term, both ways |
| `library(curl)` | an HTTP client |
| `library(bigint)`, `library(torch)` | arbitrary-precision integers; libtorch |

**It is a list, and you can add to it.** `test/config.sh` APPENDS what you
export rather than replacing it, so a directory of your own goes beside
the two that have to be there:

```sh
COCOLOG_LIBRARY=/opt/my/modules sh test/run.sh
```

Ours come first, on purpose: a suite that let somebody else's
`library(poa)` win would be green about somebody else's code.
