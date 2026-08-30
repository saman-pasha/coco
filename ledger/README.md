# The PoA federation ledger

Rung 2. Three authorities, three knowledge bases, no centre and no
daemon — and a criminal node that attacks every law the chain has.

```sh
sh ledger/run.sh          # the choreography, narrated
cocolog -s test/ledger.pl         # the same thing, checked: 25 checks
```

## What a node is

A node is not a process that runs. It is a `cocolog` invocation that
seals or syncs and exits; everything it knows is rows. A node that dies
has lost nothing, and a node that starts has missed nothing — which is
the family's oldest claim arriving somewhere new.

| file | what |
|---|---|
| `../library/poa.pl` | the consensus, as rules: hashing, validity, whose turn, fork choice |
| `federation.pl` | who may seal — public keys only |
| `node.pl` | seal, sync, head, audit |
| `mallory.pl` | the criminal node |
| `run.sh` | the choreography |

The private key never appears in any of them. It arrives in the
environment (`NODE_KEY`), because a consulted file becomes clauses and
clauses become rows: a signing key in the database is a signing key
published to every reader of the chain.

## The five laws

Everything here rests on five sentences, three in `valid_block/6` and
two in `extends_known/2`:

1. the hash is the hash **of this block** — recomputed, never taken on
   the sender's word;
2. the author is a member of the federation;
3. the signature is that author's, over that hash;
4. the parent is a block this node already holds;
5. the height is the parent's plus one.

Validity and position are deliberately separate. A block can be
perfectly well-formed and signed and still not belong on this chain yet
— an orphan whose parent has not arrived. Conflating the two is what
makes a gossip loop drop blocks it should have kept.

## Whose turn, and what a fork costs

`in_turn/2` is round robin over the sorted authority names, so the
schedule is a **function of height**: at every height exactly one
authority is in turn, every node computes which, and nobody is told.

An out-of-turn block is still valid. That is what keeps the chain alive
when the scheduled authority is down, and it is the difference between
proof of authority and a queue. It is merely worth less, and fork choice
is where that is spent:

1. **length** — more blocks is more authority-work;
2. **in-turn count** — at equal length, prefer the chain that followed
   the schedule;
3. **the hash itself**, lower first — not a quality, a coin toss every
   node makes the same way. Without it two equally good chains would both
   be kept and the fork would never close.

A head mark is a **candidate**, not an answer. Every accepted block gets
one, marks are appended and never removed, and `ledger_head/1` asks the
rule over the whole set every time. That is why a reorg needs no
retraction: nothing is undone, the same rule reads the same set on every
node, and two nodes holding the same blocks agree regardless of the order
those blocks arrived in.

## Mallory

Every ledger needs one. A federation that has only ever been offered
honest blocks has not been tested, it has been rehearsed — so mallory is
part of the arrangement rather than an afterthought in a test file. She
holds a real secp256k1 key, speaks the real protocol, and starts with
everything a real attacker starts with: every signature anyone ever
published, because a chain is public.

| attack | what it tries | outcome |
|---|---|---|
| `attack_not_a_member` | seal as herself, correctly | refused — not in the federation |
| `attack_impersonate` | alice's name, her own key | refused — signature checked against alice's key |
| `attack_tamper` | change a sealed block's payload | refused — recomputed hash differs |
| `attack_forged_hash` | claim a hash the block does not have | refused — the hash is recomputed, not compared |
| `attack_replay_signature` | a real signature onto another block | refused — a signature is bound to one block |
| `attack_wrong_parent` | re-point a real block at another parent | refused — the parent is inside the hash |
| `attack_orphan` | a valid block whose parent is missing | refused — a chain with holes cannot be audited |
| `attack_malleate` | flip `s` to its twin | **succeeds, and gains nothing** |

**The one that succeeds is the one worth understanding.** For every ECDSA
signature `(r, s)` the pair `(r, n−s)` is equally valid and anyone can
compute it without the key. So mallory can produce a different signature
for alice's block and it *will* verify — that is not a flaw in the
verifier, it is what ECDSA is, and a verifier that refused it would be
refusing valid signatures.

What she gains is nothing, because the block's hash covers height,
parent, author and payload and **not the signature**. A malleated
signature is the same block: same hash, same identity, same place in the
chain. Bitcoin's transaction ids did cover the signature, and that was
transaction malleability — an unconfirmed transaction could be made to
"disappear" by anyone who saw it. `block_signable/5` is where that lesson
lives.

(`library(secp256k1)` signs low-s regardless, per BIP-62, so the
malleated twin is never the one this chain produces.)

## And the attack that comes from inside

A member of the federation can seal a valid block that rewrites settled
history. Nothing refuses it — it is properly signed by somebody entitled
to sign, and every check passes.

It is not **refused**. It is **outweighed**. The rewrite is a shorter
chain, fork choice prefers the longer one, and the head does not move.
That distinction — between what is valid and what is agreed — is the
whole of what a consensus rule is for, and it is why the last part of
`test/ledger.pl` asserts that the block *is* valid before asserting that
the head *did not move*.

## What is not here yet

**The certificate gate.** ZiguratIP can key what a connection may reach
on the certificate it presented (`PERMISSIONS_MODE`, `--permission=…`),
so "who may append" could be the server's decision rather than a rule's
— refused at the TLS handshake, before a byte of protocol. That needs a
TLS-capable client, and cocolog's C client does not speak TLS yet. It is
a pillar's feature to build in the pillar; The Coco uses it once it
exists. Until then the federation is enforced by the rule in
`valid_block/6`, which is honest but is not the same thing: it means an
unauthorized node can still *connect* and be ignored, rather than not
connect at all.

**A Zeytun audit page.** The read path exists — `test/ledger.pl` ends by
having a process that consulted nothing re-verify every block it finds,
which is exactly the auditor's position. Presenting it as a page over
HTTP is choreography that has not been written.
