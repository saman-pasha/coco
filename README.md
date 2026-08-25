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

STATUS.md carries the missions in full — what stands under each and the
disciplines that hold across all of them. The short of it, each rung an
arrangement that ends in a GREEN line before it is claimed: crypto as
The Coco's own Parsi objects; the PoA federation ledger; contracts as
predicates under `max_steps`; training as settlement; a PoH spine; PoS
and BFT votes where the trust model wants them; the aggregator, where a
chain carries its own light client; and the TPS harness, whose number
is printed before any sentence uses it.

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
