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

Everything in this repository is one of three things:

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
* **Choreography** — `run.sh` arrangements in the mold of cocolog's
  coworker tasks: processes, knowledge bases, and the order between them.

What does NOT live here: C, C++, Cicili, or any change to the three
pillars. When a rung genuinely needs a new engine capability (TLS in
cocolog's C client, say), that capability is built in ITS repository on
its own merits, and The Coco uses it once it exists.

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
who may append at the TLS handshake, and the isolation ladder from
READ_UNCOMMITTED to SERIALIZABLE, chosen per turn.

## The ladder

Each rung is an arrangement that ends in a GREEN line, and no claim is
made before its `run.sh` prints one.

1. **Crypto as Coco's own Parsi objects** — `sha256`, HMAC, sign and
   verify as stored procedures over Zigurat's `Cryptography/`.
2. **The PoA federation ledger** — a federation CA, per-node certificates
   carrying append grants, signed hash-chained entries, blocks committed
   with their head mark in one turn, gossip, fork choice as rules, a
   Zeytun page for public audit.
3. **Contracts** — predicates deployed as signed entries, run under a
   whitelisted goal vocabulary and `max_steps`; long-lived contracts
   suspend as machines and thaw when their condition arrives.
4. **Training as settlement** — a contract names data, architecture and
   seed; workers train in `--local`; settlement is the acceptance
   predicate over held-out data. Train freely, verify deterministically,
   commit rows.
5. **A PoH spine** — an iterated hash chain as a clock, produced
   sequentially, verified in parallel across coworkers.
6. **PoS and BFT votes** where the trust model wants them — stake as a
   query, quorum certificates as counting rules.
7. **The aggregator** — many chains on one node, foreign chains verified
   by consulting the rules they publish about themselves, bridges as
   suspended-machine escrows, an anchor chain of checkpoints,
   unification as the translation layer.
8. **The TPS harness** — a speculative lane at READ_UNCOMMITTED
   pipelining ahead of a settlement lane at commit isolation; the
   harness prints transactions per second, and no sentence here says
   "competes with" until that number is printed.

## Running

The Coco needs its three pillars built and beside it:

```sh
git clone https://github.com/saman-pasha/cicili
git clone https://github.com/saman-pasha/ziguratip ZiguratIP
git clone https://github.com/saman-pasha/cocolog
git clone https://github.com/saman-pasha/coco Coco
```

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

## Layout

```
modules/    the Prolog: what The Coco is made of
test/       the arrangements that hold it GREEN
art/        the banner -- Coco, the engineer, one of the three
```

The layout grows a directory per rung as each rung is climbed; nothing is
checked in before its GREEN line.
