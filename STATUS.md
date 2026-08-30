# Status

Where this stands, what is proven, and what is not. Written to be picked
up again rather than to look finished. What is proven HERE is the
assembly and **all eleven rungs**: `test/run.sh` GREEN with a server up —
local, math, crypto, ledger, contracts, coco, bond, units, training,
spine, votes, secure, hub, token, uniswap, uniswap-v3, lending, bench,
wire —
which is sixty-two crypto checks against numbers published by other
people, plus a federation ledger, contracts under a fence, **a native
token whose gas price is the engine's own inference count rather than a
table somebody maintains** and whose bonded coin is what a validator
weighs — so a vote that cannot be honest costs its author real money —
settlement that measures rather than believes, a
proof-of-history spine held to constants computed outside this project, a
stake-weighted BFT vote whose safety arithmetic names the validators who
break it, an aggregator that verifies three chains under three regimes by
reading each chain's own rules off its own blocks, and a harness that
prints transactions per second with the arrangement on every line. The
ladder is walked; what is left is depth, not rungs.

**And one arrangement that runs across rungs rather than being one of
them**: `secure` re-runs proof of authority, proof of history and proof
of stake with the node-to-store link encrypted, and requires all
seventy-eight verdicts to be byte for byte what they were in the clear.
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

The thesis picks a language, and the argument for the pick is written
down rather than assumed: `bench/languages.md` compares Python, Prolog
and cocolog — see "The comparison, and its rule" under Done here.

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
  issuer, membership is a file per subject, and the server checks those
  grants PER OPERATION against the peer TLS identified. Who may append is
  the server's decision, not a rule's. **The refusal is not a refused
  handshake**, which this repository had written down and which reading
  ZiguratIP corrected: `zigurat_tls_handler` identifies every TLS peer,
  certificate or not, and `Globals::permits` opens
  `if (!_identified) return true;` — so a plain connection is
  unidentified and reaches everything, a certificated peer reaches what
  its certificate grants, and an uncertificated TLS peer is identified
  with an empty permission set and reaches nothing. Turning TLS on is
  what turns access control on.
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
   claimed before it was built. **The gas price and the metering per
   call this rung left ahead are rung 9's**, and they arrived as a
   measurement rather than a table. Still ahead: contract-to-contract
   calls, which need a rule about whose state is entered.
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
   **Nobody was SLASHED, and now somebody is**: the evidence this rung
   produces is spent in rung 10, where the stake is bonded COCO and
   `culprits/3`'s names have money behind them. Still ahead: there is no
   round timer, so no liveness argument — the honest form of a clock
   here is rung 5's spine, not wall time.
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
9. **COCO, the native token, and gas priced in inferences**
   (`library/coco.pl`, `ledger/gas.pl`) — **DONE**. What the chain
   charges in, which no contract can be: the fence cannot price its own
   execution, and a contract able to move the billing currency would be
   one that pays itself. Accounts are Ethereum-shaped addresses, balances
   are u256, the supply is minted by one genesis block and afterwards
   only moves — there is no mint — and the fee is paid to the sealing
   authority rather than burnt, so conservation is exact and checkable
   by somebody who does not believe the code. **The fee is arithmetic
   over the ENGINE's own inference count**, which meant a pillar
   capability first: cocolog counted every proof and told no program, so
   `call_metered/4` was built there, on its own merits, with its own
   case. Thirty-two checks. Still ahead: an inference is an inference,
   so a `sha256/2` costs what a `between/3` step costs and work done
   inside a crypto module is under-priced — pricing a builtin by weight
   is a table in the engine and belongs to cocolog; there is no fee
   market, one stated price rather than a bid; and `coco_settle_chain/0`
   settles everything unsettled in ONE turn, which is atomic and right
   until the chain is long enough that this repository's own "no long
   compute inside a turn" applies to it. The mark is per block, so
   settling in ranges is a change to one predicate.
10. **The stake IS the coin** (`votes/bond.pl`, and the bond half of
    `library/coco.pl`) — **DONE**. Rung 6 asked what a validator weighs
    and rung 9 made something worth weighing: `stake_entry/2` — the table
    `library(pos)` demands and refuses to own — is now a RULE over bonded
    COCO, so `quorum/2`, `total_stake/1` and the leader draw go on
    working unchanged over money somebody actually put up. Bonding and
    unbonding are transaction actions; leaving takes
    `coco_unbonding_delay/1` BLOCKS, the chain's own clock, and the money
    is slashable the whole way. `library(bft)`'s closing sentence — "a
    name is what a slashing rule needs" — is spent: equivocation and two
    certificates at one height both take the whole bond, a tenth to
    whoever proved it and nine tenths burnt. Twenty-five checks, the
    chain half against a real server. Still ahead: nobody is REWARDED for
    validating (an emission schedule is monetary policy, and this rung
    takes no position, the way rung 4 took none on paying a trainer);
    there is no delegation, which needs a rule about who bears a
    delegator's share of a loss; and a slash is total rather than a
    percentage, because a percentage is a number somebody has to justify.
11. **A game's units as NFTs, and the caller that lets a contract own
    them** (`contracts/token/units.pl`, and `caller/1` in
    `library/contract.pl`) — **DONE**. The future-work page said units are
    NFTs by construction: production mints, capture transfers, the kill
    burns. Building it found that no contract here could own anything —
    every ownership predicate takes its owner as an ARGUMENT, which is
    safe only while the caller is the node itself, and rung 9 made a
    transaction able to reach a contract. So the fence gained `caller/1`,
    answered by `coco_apply/5` out of the signature it had already
    verified; a direct call reports `nobody`, and every guard refuses it.
    The collection is FENCED and deployed like any other contract: a
    match's referee mints into its own match and no other, capture moves
    a unit without the holder's consent (the one deliberate departure
    from ERC-721, whose whole structure is consent), the holder keeps the
    ordinary trade, a kill burns the id forever, and provenance is a
    QUERY over the blocks that keeps only what took effect. Twenty
    checks. Still ahead, and it is the honest limit of the whole idea:
    **the chain cannot check the game's rules** — a referee's signature
    is the only evidence a unit was produced legally, so a referee who
    lies mints an army. The answer is the plan's last rung, a dispute
    verifier that replays the order log; until it exists a unit NFT is
    exactly as honest as its referee. Also ahead: contract STATE is
    isolated but contract PREDICATE NAMES are not, so two contracts
    defining one name would have their clauses tried together — rung 3's
    property, mitigated here by prefixing and worth a namespace of its
    own one day.

Two capabilities on the ladder's path belong to a pillar, not to this
repository.

**An isolation level named per turn.** ZiguratIP's store runs the whole
ladder from READ_UNCOMMITTED to SERIALIZABLE, and cocolog uses it
internally — the coworker claim is SERIALIZABLE and hands back to READ
COMMITTED. What a caller cannot do is ask for one: there is no flag, no
option and no predicate. Rung 8's speculative lane needed exactly that
and so does not exist. It is cocolog's feature to build in cocolog, and
the shape is already there.

**TLS in cocolog's C client** was the other one, and it is DONE. cocolog
ships `--tls` — the binary protocol on 2160 with ZiguratIP's
`SERVER/TLS_MODE: TRUE` on the other end — with `--cacert`, `--capath`,
`--cert`, `--key` and `--key-pass` beside it. This repository uses it
now; what that changed, and what it deliberately did not, is the first
entry below.

## Done here

### The last of the shell: the chain is built, not `cat`-ed

cocolog's `library(files)` had `read_file_to_codes/2` and no counterpart,
which meant A COCOLOG SCRIPT COULD NOT WRITE A FILE -- no `open/3`, no
`tell/1`, measured rather than assumed. Every caller that wanted one
reached for a shell. `write_file_from_codes/2` and
`append_file_from_codes/2` were added there for exactly this, and this
suite had two places that wanted them. **18 shell calls to 16, `red: 0`
in 3m20s, 19 cases.**

* **`secure.pl`'s `cat s.pem s.crt > full.pem` is two reads and a
  write.** The new predicate masks its bytes exactly as
  `read_file_to_codes/2` does, so a PEM survives whole and no shell is
  trusted with three paths in one string. The case proves it end to end
  -- 17 checks GREEN, chain and all -- which is the test that counts,
  because a corrupted chain fails a TLS handshake rather than failing
  quietly.
* **`bench.pl`'s `rm -f` is `delete_file/1`** behind its guard: gone is
  the postcondition, so a file that was never there is a success.

WHAT STAYED, and it is not an oversight: three redirections capture a
SUBPROCESS's stdout -- `secure`'s terminator log and case log,
`training`'s filtered run -- and the subprocess does that writing, not
us. `mktemp`, `openssl` and the recursive `rm -rf` of a temp directory
stay as the external tools they are.

**Sixteen against CivV's fifty-eight, and the gap is the point.** The
same sweep over there went 99 -> 58, because that suite had been asking
a shell for questions cocolog could already answer -- globs, `mkdir -p`,
`rm -f`, `mv`, `sed`. This suite never had much shell in it, so the
refactor that mattered here was one line. That is the arrangement
working: the case that reads best is the case that asked its own
language first.

### The suite is cocolog

Every case in `test/` is a cocolog script now -- `main/0`, a run of
checks, a GREEN or RED verdict line, run as `cocolog -s test/<case>.pl`
with **the exit code as the verdict**: 0 exactly when `main` proved,
which `checks_done` withholds on any red check. Eighteen cases, plus the
two blocks `run.sh` used to carry inline (`local` and `wire`), against
one `test/prelude.pl`. `run.sh` only drives them, and prefers the `.pl`
where one exists, so the suite stayed green through the conversion
rather than at the end of it. This is CivV's shape, brought here for the
reason it went there: eighteen copies of a `check()` function, eighteen
`q()` helpers spawning cocolog and grepping its output, eighteen
spellings of "did that module build" -- eighteen copies of one idea
disagree eventually, and the disagreement is silent.

**What replaced what.** `check()` in every file became
`library(process)`'s `check/3`, one copy. A `q()` that spawned a whole
cocolog to get a fresh store became `iso/2` -- `run_isolated/2`, a fresh
machine and a fresh store in this process -- which is what most of the
spawning was actually buying: `bond.pl` alone funds a genesis and bonds
against it in twenty-one of its twenty-five checks, and without
isolation the second check would inherit the first's balances and a
slash would land on a bond an earlier check had already taken.
`grep -aoE` on a process's output became the goal's own bindings,
compared by `want/2`, which prints both values on a mismatch. `uname -s`
and `command -v` became `library(os)`, one answer on both systems.

**AND WHAT STILL SPAWNS, DELIBERATELY.** Half of this repository's
claims are about SEPARATE PROCESSES -- one writes the knowledge base and
a second, which consulted nothing, reads it back -- and `run_isolated/2`
is a fresh machine in the SAME process, which cannot make that claim.
So `solo/3`, `wire/4`, `wire_as/5` and `wire_consult/2` still start real
cocolog processes, and every case that proves something across processes
uses them: the three authorities gossiping in `ledger`, the settlement
in `coco`, the unbonding that matures against the CHAIN's height in
`bond`, the bare auditors everywhere. Converting those to `iso/2` would
have kept the suite green and deleted the proof. Two more stay shelled
for their own reasons: `bench`'s language pairs, because one lane is a
cocolog and the other is a CPython and there is no way to ask CPython a
question from inside cocolog; and all of `secure`, whose subject IS a
link between two processes.

**Each conversion was gated on the CHECK COUNT against its shell twin**,
not on its own verdict, and that gate is the reason to trust the result.
A `.pl` that is green tells you what it ran, not what it left out.
`crypto.pl` was green with sixty-nine checks where `crypto.sh` had
seventy-one: two bech32m vectors had simply gone missing, and a
retyped Bitcoin genesis coinbase had gained a byte. Both were invisible
to the case itself.

**One finding came out of the conversion, and it is the interesting
kind.** `secure` re-runs `ledger`, `spine` and `votes` over a TLS
terminator and requires the verdict lines to be identical. The first
such run went RED: `ledger` lost carol's seal -- head at 1 instead of 2,
five blocks instead of six, and the fork closing on the wrong branch.
It was not TLS. Every one of the eighteen `.sh` cases had written
`$ZIGURAT_DIAL --timeout 30`, and the dial `config.sh` exports names no
timeout at all, so the converted cases had been running at cocolog's
default of twenty seconds. Twenty is enough in the clear and not enough
through an encrypted hop, and **the node call that ran out did not
raise** -- it simply did not seal, which is a block that never arrives.
The prelude appends the case timeout now when the inherited dial names
none, and the same run that lost the seal at twenty keeps it at thirty.
So the case's own claim survives intact: TLS changed no verdict, and the
thing that looked like it had was ours.

`sh test/run.sh` with a server up: nineteen cases, `red: 0`, no SKIPs.

### cocolog against CPython, measured -- and yes, it is slow

`bench/languages.md` compared the two languages across every aspect and
stopped one sentence short, deliberately: *"the sentence `cocolog is
faster/slower than X' is not written here because no harness printed
it."* `bench/langs.sh` is the harness. It prints it, and the answer is
that **cocolog is between one and two orders of magnitude slower than
CPython, and the spread across tasks is the useful part.**

Five small programs, written twice each and checked against each other:
naive reverse, all-solutions 8-queens, a tight counting loop, a keyed
lookup, a generate-and-sort. In memory, nothing kept, against CPython
3.11 -- 7-11x on list building, 13-15x on backtracking search, 11-14x on
generate-and-sort, 35-62x on the counting loop, 80-83x on the keyed
lookup. Search is cocolog's best showing, which is the thing a Prolog
engine is for; the counting loop is its worst, which is the
per-inference cost of a continuation-passing interpreter with no
compilation step.

**The guess that it was start-up is dead.** Every arrangement boots in
0.01s, the same as Python. That was the first hypothesis and the
measurement refused it.

**THE KEYED LOOKUP IS A SLOPE, NOT A FACTOR**, and it is the one finding
worth acting on: the same thousand probes cost 7x at 200 facts, 49x at
2000 and **411x at 20 000**, against a Python dict that is flat at every
size. That is `languages.md`'s own "no clause indexing" sentence with
numbers under it. First-argument indexing is the change that would move
it, and it is cocolog's to make, not this repository's.

**PYTHON IS A LANGUAGE; COCOLOG IS A LANGUAGE AND A STATE MACHINE**, and
the harness is built around that rather than despite it. A dict is
memory -- not durable, not transactional, invisible to another process,
gone at exit -- so timing `--embed` against it measures the guarantees
and not the engine. The store lanes are paired with `sqlite3` instead: a
file, an index, one committed transaction. **That lane is itself 60x
slower than the dict it replaces**, which is the honest frame for every
store number here: durability is not free in Python either, it is just
usually invisible because nobody asks a dict for it.

And what the same run says about the store is the most useful line of
the exercise: **reading costs a constant, writing costs a fortune.** On
every compute task the embedded store lands within a few percent of the
in-memory arrangement -- 6.5 against 6.9, 14.7 against 14.5, 32.6
against 34.6 -- so the database does not slow the thinking down at all.
But 200 `assertz` plus a thousand probes cost **17.2 seconds** embedded,
and over the server the same work did not finish inside a 300-second cap
and the answer gate refused to print a number for it. "Long compute
never inside a turn" was a discipline this family learned in blood; it
is a measurement now.

**Two runs are on the page and the first is not deleted**, per the
bench file's own rule that a superseded reading is a different claim
rather than a wrong one. Run A is there because it is instructive about
benchmarks: it printed a lookup ratio of **1163220x** and a sort ratio
of **0.0x**, both arithmetic squeezed out of two runs that were entirely
fixed cost, and its store lanes came out FASTER than memory -- which is
impossible, and which turned out to be a stray `--embed` process from a
killed run burning a core for eighteen minutes. `pkill` had killed the
script and not its child. So the harness now caps every run, kills what
a previous run may have left (bracketed, or the pattern matches the
shell running it), and REFUSES to print a rate for any lane that
calibrated to a single rep. Three rules that exist because the first
draft got three numbers wrong.

The rest of the discipline is `harness.pl`'s, adapted: every lane must
answer the same value or nothing is printed, reps are calibrated per
lane so no reading is start-up wearing a number's clothes, the
arrangement is named on every row, and the clock is the wall. And what
no rule can catch is still which tasks were chosen -- five small
programs are not a language, and these five were picked to include the
ones cocolog was expected to lose.

`test/bench.pl` grew six checks so the comparison cannot rot quietly:
the five task pairs must keep answering the same value, and so must the
dict and sqlite implementations of the store task. Thirty-one checks.

#### And then cocolog fixed both of the findings

**THE BENCHMARK WAS THE POINT, AND THIS IS WHAT IT WAS FOR.** The two
sentences above that name a defect rather than a design -- the lookup being
a slope, and writing costing a fortune -- were both diagnosed in cocolog and
fixed THERE, on their own merits, behind that repository's own gate: 39 of
39 GREEN, `red: 0`, no SKIPs, on a fresh store. The Coco modified nothing;
it measured, and the pillar answered. That is the freeze working as designed
rather than in spite of itself.

* **The turn's writes are batched.** The batching that made a CONSULT cheap
  was switched off before the goal ran, so `assertz` in a loop paid a
  forget-and-resend of the whole predicate per clause: 200 cost 16.9s and
  400 cost 85.4s, roughly N^2.4. They cost **0.050s and 0.088s** now.
* **Clauses are indexed on their first argument.** A call used to COPY every
  clause onto the heap and unify its head, so a probe into a table of facts
  copied the table.

The keyed lookup, in the four columns -- a thousand probes over 200 facts,
per sweep:

| | cocolog --local | CPython | cocolog --embed | CPython + sqlite3 |
|---|---|---|---|---|
| what it is | in memory, no database | dict, in memory | MVCCS in-process | file, indexed, one commit |
| **before** | 0.005979s (79.7x) | 0.000075s | one rep, **17.18s wall** | 0.004530s (60.4x) |
| **after** | 0.003614s (47.6x) | 0.000076s | **0.002291s (30.1x)** | 0.004432s (58.3x) |

And the slope, on `--local`, where no store is involved:

| facts | before | after |
|---:|---:|---:|
| 200 | 7x | **3x** |
| 2 000 | 49x | **3x** |
| 20 000 | 411x | **4x** |

**A ratio that grew with N is the signature of a linear scan.** It is flat.

The four other tasks, after, the same four columns -- only `lookup` has a
durable-Python counterpart written, so the fourth is empty by construction:

| task (one rep) | cocolog --local | CPython | cocolog --embed | CPython + sqlite3 |
|---|---|---|---|---|
| nrev, 400-element list | ~0.0387s (5.9x) † | 0.006611s | 0.035925s (5.4x) | -- |
| queens, all 92 solutions | 0.025366s (14.3x) | 0.001772s | 0.024442s (13.8x) | -- |
| loop, 100 000 additions | 0.106376s (33.9x) | 0.003141s | 0.124958s (39.8x) | -- |
| lookup, 1000 probes / 200 facts | 0.003614s (47.6x) | 0.000076s | 0.002291s (30.1x) | 0.004432s (58.3x) |
| sortnums, 5000 integers | 0.012735s (9.1x) | 0.001392s | 0.012850s (9.2x) | -- |

**WHAT DID NOT CHANGE IS THE HEADLINE.** cocolog as a LANGUAGE is still
6-34x CPython on the four compute tasks, because neither fix touches the
per-inference cost of a continuation-passing interpreter with no
compilation step. Search is still its best showing and the counting loop
still its worst. Two defects moved; a design did not.

Three things this run does not get to claim, on the page because a
benchmark that reports only what flatters it is not one:

* **† The `nrev --local` row the harness printed is wrong**, and its own
  shape column said so -- `2R/R` of 3.36 where 2.0 is linear. Re-measured
  at R=64, three runs: 0.039391, 0.039185, 0.038652, so about 5.9x against
  6.9x before. The R=128 point swung 0.0387-0.0624 and poisoned the second
  measurement. Container noise, not a regression, and the table carries the
  re-measurement rather than the printed number.
* **The server lane is CONFOUNDED and is not in these tables.** It went
  from "one rep, no rate" and a REFUSAL on lookup to real rates -- but the
  server was restarted on a fresh store between the runs while the earlier
  one measured 76 MB of aged store. Some of that column is the fix and some
  is the restart. `--embed` is clean: it builds a fresh store per run
  either way.
* **`--embed` beating `--local` on lookup is not a finding.** 0.002291
  against 0.003614 with the local row's shape at 2.58 is inside the noise;
  an in-memory lane cannot really be slower than the same lane with a
  database under it.

### Units as NFTs, and the caller that lets a contract own anything

The future-work page had this one written already: *"Units are NFTs by
construction — CivV's capture clause already retracts one `unit_owner`
row and asserts another, which IS transfer; production mints, the kill
burns."* Building it turned up something the plan had not noticed, and it
is the more interesting half.

**No contract in this repository could own anything.** Look at what the
ownership predicates take: `nft_transfer_from(Collection, Caller, From,
To, Id)` names the caller *in the call*; `ft_transfer(Token, From, To,
Amount)` names the payer. That is safe exactly as long as the caller is
the node, which knows who it is. Rung 9 ended that: `call(Contract,
Goal)` is a transaction action, so the argument a contract trusts became
a field a stranger writes. The escrow had already felt the gap from the
other side and paid for it in machinery — `release/2` carries a
SIGNATURE over the escrow id, which is an entire signature scheme built
to answer a question the fence could not ask.

So the fence gained one word. `caller/1` is in the vocabulary,
`contract_call/3` takes who is calling, and `coco_apply/5` supplies it
out of the signature it verified before running anything — **the node's
answer, never the caller's claim**. A contract can read it and cannot set
it: `contract_enter/2` is not in the vocabulary and `nb_setval` was
already forbidden, which the case checks by handing the fence a contract
that tries. A direct call reports `nobody`, and every guard here refuses
`nobody`, so ownership can only be exercised through a signed
transaction.

**Then the collection is ordinary.** `contracts/token/units.pl` is a
fenced contract, deployed as a block payload like escrow and registry,
holding everything in scoped state. Opening a match makes the caller its
referee, permissionless and first come. Only that referee mints into that
match. A kill burns the id — and because state is append-only, a burnt id
is never reissued, so two units can never share one provenance.

**Capture is the one place this leaves ERC-721 on purpose.** The
standard's entire structure is consent: the owner moves their own, or
somebody they approved does. A captured unit is *taken*. So a referee
moves a unit without asking its holder — and the two fences that make
that bearable are checked: a referee is named per MATCH and reaches
nothing outside it, and a unit carries its match for life. The holder
keeps the ordinary consented move, and a non-holder calling it fails.

**Provenance is a query, not a table.** The chain already carries every
transaction, signed and hash-chained; a history table beside it would be
the copy that goes stale. `coco_unit_history/2` walks the chain fork
choice agreed on and keeps the calls about one id — **and only the ones
that took effect**, because the receipt says whether the contract
succeeded. The stranger's refused mint is in the blocks, was paid for,
and is in nobody's history. Gas is charged for work; history records
consequences; the case pins both halves of that sentence at once.

**What the chain cannot check is the game.** A referee's signature is the
only evidence a unit was produced legally — that the side had the
production, the technology, the room. A referee who lies mints an army
out of nothing and this contract will hold it, correctly, forever. No
amount of rules here fixes that; the answer is the plan's last rung, a
bare process that replays the match's order log while the signatures
decide who lied. Until it exists, a unit NFT is exactly as honest as its
referee, and this page says so rather than implying otherwise. The
smaller sibling: a unit crossing into another match must pass THAT
match's production fences, which the chain cannot enforce either —
owning a Musketeer is not permission to field one.

One property found while naming things, worth writing down: **contract
state is isolated and contract predicate NAMES are not.** Rung 3 proved
two contracts can keep separate keys called `n`, because `state_put/2`
takes no contract argument; but installed clauses go into one knowledge
base, so two contracts defining `mint/4` would have both sets tried. The
units contract prefixes everything `unit_` and that is a mitigation
rather than a fix. A real one is a namespace at install time, which is a
change to rung 3 and wants its own case.

**Twenty checks**, the chain half against a real server: the collection
deployed as a block, a unit minted, captured and killed by transactions,
and a bare process reading its whole life back out of the blocks.

### The stake is the coin, and rung 6's evidence finally bites

Rung 6 built proof of stake honestly and said what it had not done:
stake was a NUMBER read off a block — a block said alice weighs 40, so
alice weighed 40 — and *"nobody is SLASHED (the evidence is produced;
burning a bond is a policy question this rung takes no position on)"*.
The evidence was real. There was simply nothing to take. Rung 9 made
something to take, and this rung is the join: `stake_entry/2`, the table
`library(pos)` insists is not its business, is a RULE over bonded COCO —
so `stake_of/2`, `total_stake/1`, `quorum/2` and the leader draw go on
working with **nothing changed**, over numbers somebody actually put up.

`library(bft)`'s header ends with "a name is what a slashing rule needs".
It now has one, and money behind it: equivocation — two signed votes at
one height and round for different blocks — and two quorum certificates
at one height, whose voter INTERSECTION is provably more than the fault
bound. Both take the whole bond: a tenth to whoever proved it, nine
tenths burnt.

**Why not pay the reporter everything**, which is the obvious rule: a
validator would equivocate and report ITSELF, and the bond would come
straight home. A slash the culprit can collect is not a slash. Burning
the rest is what makes the loss real; the tenth is what makes carrying
evidence worth doing. The burn is why `coco_conservation/0` grew a fourth
term — a COCO is in a balance, a bond, an unbonding on its way home, or
the burn, and the four still add to the supply exactly.

**Two findings came out of building it, and both were bugs before they
were paragraphs.**

**WEIGHT IS MONEY AT RISK, NOT MONEY BONDED.** The obvious rule is that
asking for your money back drops your voting weight at once — it is what
Cosmos does. Reading `library(bft)` killed it: `valid_vote/1` opens with
`has_stake(Who)`, so a validator with no weight cannot cast a vote
anybody will look at, and `equivocation/3` validates both votes before it
names anybody. Under the obvious rule the attack is two lines long —
equivocate, unbond in the same breath, and the evidence against you stops
being *readable* while your money sits there waiting to mature. Tying the
weight to `coco_at_risk/2` closes it by construction and leaves the
simpler sentence: **you weigh what you can lose.** The weight goes to
zero at exactly the moment the money stops being takeable, which is when
it lands back in a balance. `test/bond.pl` pins the attack itself —
equivocate, unbond everything, and the slash still lands.

**RUBBISH IS A REFUSAL, NOT AN EMERGENCY**, and this was a real hole in
what rung 9 shipped. `secp256k1_verify/3` RAISES on a malformed signature
(`domain_error('a 64-byte signature', deadbeef)`) and `u256_cmp/3` throws
on an amount that is not a number. Both are right to — a program handing
them rubbish has a bug — but a transaction is not a program: it is bytes
somebody else chose, and the one thing they must not be able to choose is
whether this node finishes its turn. `coco_tx_valid/2` and
`coco_well_formed/1` are total now, the receipt says `refused(signature)`
or `refused(malformed)`, and the same rule covers evidence: a vote that
raises is dropped, a certificate that raises is not a certificate.

**And the fence made of `catch/3` leaks in one place**, which cost a
debugging round: `catch(qc_valid(QC), _, fail)` does not hold, because
`qc_valid/1` checks its votes with `forall/2`, `forall/2` is built on
`findall/3`, and cocolog's `findall/3` lets an uncaught throw end the
query with a message no `catch/3` sees — which cocolog's own MODULES.md
says outright and files as a change wanting its own case. So the catch
goes INSIDE the findall, per vote, and what reaches `qc_valid/1` cannot
raise inside anybody's `forall`. The workaround is three lines and it is
labelled; the pillar fix is cocolog's to make.

One more that is a design decision rather than a bug: **a fabricated
certificate must rob nobody.** `culprits/3` intersects two lists of
NAMES and takes no position on whether either certificate is real — it
is not its job — so a stranger could hand a node two fabrications naming
whoever they liked. Both certificates go through the sound-QC gate
before a name is read: every signature, every vote matching the
certificate it is in, and a quorum of the stake behind each.

**Twenty-five checks**, the chain half against a real server: a bond
sealed as a block, an unbonding maturing three blocks later because no
node claims it and every node moves the same rows at the same height,
and the money home with the weight gone.

### COCO: the native token, and a gas price that is a measurement

Every chain that charges for compute has to know what the compute cost,
and every chain answers that the same way: a table. Ethereum's yellow
paper assigns a number to each opcode, the client implements the table,
and the table and the implementation have to be kept in step by people —
a gas cost is a *specification*, and a specification can disagree with
what the machine actually did.

Here it does not have to be one. cocolog meters every proof: the engine
counts inferences because it must, for its own budget arithmetic, and
`cocolog step` has printed `finished after N inference(s)` since the day
it was written. **So a fee can be arithmetic over a number the engine
produced rather than an estimate of it**, and that is the whole of this
rung's claim. The price list is one clause — one inference costs 10^9 of
the smallest unit — and the quantity is not anybody's opinion.

**Which needed a pillar capability first, and it was built as one.** The
count was kept in C and on a terminal, and nothing a *program* ran could
read it: `call_limited/3` answered whether a goal fitted under a ceiling,
never what it spent. So `call_metered/4` was written in cocolog, on its
own merits, with `test/meter.sh` beside it — fourteen checks, and
cocolog's suite is **39/39 GREEN, `red: 0`, no SKIPs** with it in.

One decision in that builtin is load-bearing here: **it succeeds where
`call_limited/3` fails.** `/3` fails when the goal fails, which is right
for something that drops in where `once/1` was and wrong for a meter — a
failed search is real work, and it is precisely the work an attacker
would like to be free. `call_metered/4` answers `true`, `failed` or
`inference_limit_exceeded`, and fills in the count for all three. The
other decision is what it does *not* do: an exception is re-thrown and
its count lost, because which exceptions are failures is the caller's
policy. `library(coco)` puts its own `catch/3` inside the meter, which is
what turns a contract that throws into an outcome that pays.

**The coin.** Accounts are Ethereum-shaped addresses (`library(eth)`,
already pinned to published vectors), balances are u256, and the supply
is written by one genesis block and never again — **there is no mint** in
the file, which is a property you can check by reading rather than a
promise. The fee is *paid* to the sealing authority rather than burnt,
because burning would be monetary policy and this rung is not making
any; so `coco_conservation/0` is exact at every moment, and an auditor
who believes none of the code above it can run it.

**A transaction is two things and deliberately not three.** A
`transfer(To, Amount)` is the token's own move: bounded, constant-priced,
and done OUTSIDE the meter, because a ceiling that landed between the
debit and the credit would destroy money. A `call(Contract, Goal)` is a
fenced contract entry, metered, and safe under a ceiling because
`contract_call/2` already stages its writes and flushes them only on
success. There is no third shape, and the reason is short: a transaction
carrying a *bare goal* would be `assertz` from anybody who can afford the
fee.

**Nobody buys gas they cannot pay for**, which is why nothing is taken up
front and there is no refund to get wrong. The ceiling is the lower of
what the sender asked for and what the balance already covers, so the
bill is payable when it arrives. Two numbers from the case say it
exactly: a sender holding 3 000 inferences' worth who asks for 100 000
and runs a contract that never stops is charged **3000000000000 and left
holding 0** — its last unit and not one more; and a sender below the
intrinsic is `refused(gas)`, its balance and nonce untouched, because
nobody may be billed for a transaction the node declined to run. A
runaway with money behind it pays its ceiling exactly — 6000 inferences,
**6000000000000** — since the charge is capped at what was *bought*, and
`call_metered/4` can overshoot by the one inference that noticed the
budget was gone.

**And the chain is the only way in.** A transaction is a block payload,
so it inherits every law the ledger already had: mallory is not an
authority, her block never joins the chain, and the transaction inside it
is never seen by the gas layer at all. Two layers asking two questions —
who may seal, and who may spend — which is `contracts/node.pl`'s
arrangement doing a second job. Settlement is marked per block hash, so
settling twice moves nothing, and a bare process that consulted nothing
reads the balances, the receipts and the conservation back out of the
knowledge base.

**Thirty checks**, the chain half against a real server.

**What the meter does not see, and it is worth stating plainly**: an
inference is an inference. A `sha256/2` is one C call and counts as one,
a `between/3` step counts as one, so work done inside a crypto module is
under-priced against work done in clauses. `coco_intrinsic/1` answers
that for the *transaction's* own crypto — the signature verify the node
pays for out of its own pocket — and nothing answers it inside a contract
yet. Pricing a builtin by weight is a table in the engine, which is a
change to cocolog and belongs there with its own case; naming it here is
cheaper than pretending the number is finer than it is. Also absent by
choice: a fee market (one stated price, not a bid) and account
abstraction.

For scale, since the number should be on the page: the `adder` contract's
`sum_to(10, S)` settles at **1114 inferences** including the intrinsic —
0.000001114 COCO. It is an engine-dependent number and will move when
cocolog's engine does, which is why the suite pins the *relations* (ten
times the work costs strictly more; the same call twice costs the same to
the unit) and the two fees that are exact by construction.

### The comparison, and its rule

`bench/languages.md` compares Python, SWI-Prolog and cocolog across the
language aspects, the backend work, and the four separate senses of
"AI-friendly" — building models, representing knowledge, running
agents, being written BY a model — which a language can hold any subset
of, and the three hold different ones.

It is in `bench/` on purpose: a comparison is a benchmark of a
different kind, and it obeys the harness's rule — **no sentence claims
a number that has not been printed.** Every figure in it comes from a
table in this repository or in cocolog's, with the arrangement beside
it; what is Python's or SWI's is stated qualitatively and checkably.

And it is honest in both directions, which was the hard part to hold:
cocolog loses often and the file says where — strings, GC, clause
indexing, tabling and constraints, tooling, ecosystem — because a
document that had cocolog winning every row would be `mallory.pl` in
prose. What the thesis actually stands on is the four rows where
cocolog differs in POSITION rather than in language: a clause is a row
other processes read, a turn is a transaction, a suspended proof is
data any process can finish, and determinism and metering are the
engine's guarantee rather than the application's promise. The rest of
the comparison exists so nobody mistakes that wall for the whole house.

Pointed at from three places — the README's thesis, cocolog's own
README, and bench/README.md's file table — and written in ONE, because
a comparison that lived in two files would disagree with itself
eventually, and the drift would be silent.

**And the everyday row, which is where most language choices are
actually made** — ease, syntax weight, readability, how much code a
thought costs — got its own section rather than being scattered, with
the "less code" claim turned from an adjective into a measurement:
grep-counted code lines, printed like a rate. The whole of proof of
authority is **39** non-comment lines (of 140 — the code is outnumbered
by its own explanation nearly three to one, which is what brevity
actually buys: room for every rule to carry its why); PoS is 42, the
PoH layer 23, BFT 56 — the four consensus libraries together are 160
lines of code. The section stays honest in both directions: Python wins
ease of entry outright and that IS the explanation of the last fifteen
years; Prolog's difficulty is located in semantics, not syntax; those
39 dense lines read slower than 200 plain ones for anyone not yet
thinking in clauses; and no Python second column is printed, because
nobody wrote one — what is claimed checkably is only that the layers a
Python version must add (storage, serialisation, schema) are the layers
the position deletes.

### The three rungs over TLS, and the verdicts that did not move

cocolog grew `--tls`, so every node here can reach its chain over an
encrypted, server-authenticated link. The question that raises is not
whether it still works but whether it changes what is TRUE about the
consensus — and the answer had to be demonstrated rather than asserted.

**One dial string.** Twelve scripts wrote `--host H --port P` for
themselves, which is twelve copies of one decision and twelve places to
edit to try the hub secure. `test/config.sh` builds `$ZIGURAT_DIAL` once
from `coco.yaml`'s `arrangement:` block — `transport: tcp | tls`, plus
`cacert`, `cert` and `key` — and every script says that instead. So:

```sh
ZIGURAT_TRANSPORT=tls ZIGURAT_CACERT=/etc/ssl/ca.crt sh test/run.sh
```

It also retired `--port`, which cocolog now documents as deprecated:
`--tcp PORT` is the same field and names the transport as well as the
number, which is the point of having four of them.

**A CLIENT CERTIFICATE IS OPTIONAL, AND MANDATORY FOR PERMISSIONS.**
Read out of ZiguratIP rather than assumed: `loadzigurat.cpp` accepts
REQUIRED (the default), OPTIONAL and NONE for `SERVER/TLS_CLIENT_AUTH`,
and `require_security()` demands only the server's own credentials. What
a certificate is required for is `SECURITY/PERMISSIONS_MODE`:
`zigurat_tls_handler` identifies EVERY TLS peer, certificate or not, and
`Globals::permits` opens `if (!_identified) return true;` — so a plain
connection reaches everything, a certificated TLS peer reaches what its
certificate grants, and an uncertificated one is identified with an empty
permission set and reaches nothing. Turning TLS on is what turns access
control on.

**IT CHANGES THE LINK AND NOT ONE VERDICT.** `test/secure.pl` runs
`ledger`, `spine` and `votes` again behind a TLS terminator and requires
the verdict lines to come back byte for byte identical — 25, 16 and 37 of
them, seventy-eight in all, including the three attacks that are supposed
to succeed. That is not a formality. Every law those rungs enforce is a
law about CONTENT: a hash recomputed from the block's own fields, a
signature checked against the author's published key, a tick count
re-run, a quorum weighed against a stake table read out of rows. Not one
of them asks who handed the bytes over, so an encrypted link has nothing
to say about any of them. A run where mallory suddenly failed to grind
the leader draw would be as much of a failure as one where she got
through.

**AND THE TRAP THAT COMES WITH IT.** An encrypted transport invites a
node to treat an AUTHENTICATED peer as a TRUSTED one, which would quietly
undo rung 2. So the case makes mallory arrive over a verified TLS
connection to the very store the honest nodes use — at the transport
layer exactly as authenticated as alice — and offer a block signed with
her own real secp256k1 key. `ledger_sync/1` refuses it, and
`valid_block/6` refuses it directly, for the reason it always did: she is
not in the federation. A handshake has no opinion about that. **Never add
a "peer is authenticated, skip re-verification" path.**

Three more that a plaintext run cannot make: plaintext against the TLS
port reaches no chain (so the terminator is really TLS); a node whose
`--cacert` names an unrelated authority reads ZERO blocks rather than
some; and it is told why, by name — the refusal says `certificate`
rather than `read failed`.

**AND THE AUDIT PLANE, THROUGH THE SAME KIND OF TUNNEL.** Everything
above encrypts the binary port, which is the writers' road. The chain's
public face is Zeytun — read-only by construction — and behind a
Cloudflare-shaped tunnel an https URL is the only kind it has. So the
case stands a second TLS edge in front of Zeytun and reads alice's
ledger through it both ways a public reader exists. `library(curl)`,
from inside a query: `curl_get` with an https URL and the edge's
certificate vouched for by name lists the chain's predicates — the
reader cocolog's own `test/tunnel.sh` proves in the small, here reading
a real chain. And the `--https` ARRANGEMENT: an auditor warms alice's
whole knowledge base through the edge, loads `library(poa)` from its
OWN path — never from the chain being audited, which is what makes the
audit worth anything — and re-verifies every block: `all_verified`,
over an encrypted read-only plane, with the writers' port untouched.
Two more checks; the case's tally is now eighteen.

The terminator is a rehearsal and says so, exactly as cocolog's own
`test/zigurat-tls.sh` does: turning `TLS_MODE` on means restarting the
shared server with credentials every other case would then have to speak.
What is proved here is the client half and the consensus half; ZiguratIP's
server side is ZiguratIP's suite's business.

`sh test/run.sh`: 16 cases, red: 0, with `secure` GREEN among them.

### The TPS harness: the number, and the six ways it lies

**The number is on the page.** Re-run on a 4-core container with every
layer rebuilt by **clang** (see below), after a vacuum, every lane
reading:

| lane | rate | arrangement |
|---|---|---|
| `verify` | **537/s** | 2000 in 3.722s, local, no database |
| `validate` | **530/s** | 2000 in 3.772s, local, no database |
| `seal_batched` | 18.38/s | 30 in 1.632s, server, one kb, ONE turn |
| `seal_per_turn` | 7.96/s | 30 in 3.770s, server, one kb, per turn |
| `parallel_own_kbs` | 32.77/s | 60 in 1.831s, 4 kbs, one turn each |
| `parallel_one_kb` | 22.89/s | 60 in 2.621s, 1 kb, 4 writers |
| `seal_batched_again` | 16.18/s | the first lane over again, minutes later |

**And the sentence still is not written**, because what those lanes
measure is that arrangement on that container.

### What changing compiler was worth, and what that reading is not

The whole stack was gcc-built until this run and is clang-built now —
ZiguratIP's C++ libraries and server, cocolog's binary and its five
`.so`s, The Coco's nine modules. Against run D, which was the last gcc
run and also began with a vacuum:

| lane | gcc (run D) | clang (run E) | |
|---|---|---|---|
| `verify` | 389.18 | **537.35** | +38% |
| `validate` | 391.39 | **530.22** | +35% |
| `seal_batched` | 15.79 | 18.38 | +16% |
| `seal_per_turn` | 7.22 | 7.96 | +10% |
| `parallel_own_kbs` | 26.08 | 32.77 | +26% |
| `parallel_one_kb` | 18.40 | 22.89 | +24% |
| `seal_batched_again` | 13.19 | 16.18 | +23% |

**THE TWO LOCAL LANES ARE THE ONLY HALF OF THIS I WOULD DEFEND.**
`verify` and `validate` touch no database, no socket and no other
process: they are ECDSA and the interpreter, and across runs A-D they
sat within a couple of percent of each other. A 35-38% jump is many
times that spread, and it is where a compiler change should show — the
hot loop is secp256k1 field arithmetic compiled from Cicili's C.

**The five store lanes are one run against one run**, and this file's
own rule seven exists because those lanes drift. They agree within 6%
across four vacuumed gcc runs, so +16 to +26% is outside that band and
probably real; "probably" is the honest word until there are four clang
runs to put beside the four gcc ones. Nothing here has been re-run four
times yet, and the table says so rather than rounding the caveat away.

### One compiler for the whole stack, and what it cost to get there

Three repositories, one address space: cocolog links ZiguratIP's libCore
and libStreamIO into its own binary and `dlopen`s The Coco's modules into
its own process. A mixed toolchain there is two ABIs in one process, so
"build it with clang" is not a per-repository choice. All three now carry
an identical `tools/cc/` — `cc`, `cxx`, a `gcc`/`g++` shim pair, and an
`env.sh` — and each README says why.

Four things had to be found before any of it built:

**Cicili names `gcc` outright** in `config.lisp` and takes no environment
override; a target's `:compile` list is appended after the base, so it can
add flags but cannot rename the program. Cicili is frozen for all three of
these repositories, so the shims go on `PATH` for that one step and the
three-line patch that would retire them is written down, offered, and not
applied.

**`clang++` alone does not compile C++ on Ubuntu 24.04.** It borrows
libstdc++ from the newest gcc it can find — gcc-14's *runtime* directory,
which ships crtbegin.o and libgcc_s.so and not one header, because g++ is
13.3 and the headers are under `/usr/include/c++/13`. Every C++ file dies
at `fatal error: 'string' file not found`, naming a header that is plainly
installed. `tools/cc/cxx` walks the install dirs newest-first, takes the
first with a matching header set, and passes `--gcc-install-dir`.

**`libCryptography.so` was under-linked and had been for years.** It calls
`Zigurat::Configuration` from `x509.cpp` and named no `-lConfiguration`;
g++ let every consumer through, because ld resolves a shared library's
leftovers from whatever else is on the command line and something always
was. clang reported the truth, from MVCCS-cicili's contention test, which
links no Configuration and has no reason to. The fix is one word in
`Cryptography/Makefile` rather than one word in every consumer — and the
comment already sitting above that line describes this exact class of bug,
found the same way, on Mach-O.

**`CC ?=` and `CXX ?=` do nothing.** make gives them built-in values whose
origin is `default`, not `undefined`, so the assignment is skipped and the
final link went on being a `g++` link while every other line of the build
said clang. Only `readelf -p .comment` showed it. Both Makefiles test
`$(origin ...)` now.

And one that is Cicili's own emission meeting a stricter compiler:
`-Wparentheses-equality` and `-Wno-dangling-else` are needed on every
target compiled as C++, because the transpiler writes `while ((x == 0))`
and unbraced else-if chains, and **Cicili treats compiler chatter as
fatal** — the build stopped with an `Unhandled SIMPLE-ERROR` whose text
was a warning. gcc ignores unknown `-Wno-` options, so the flags travel.

Both suites are green on the result: cocolog 25 cases `red: 0`, The Coco
15 cases `red: 0`, no SKIPs in either.

### Every layer of this is release-built, and it was checked

Asked and answered, because a benchmark on a debug build is a benchmark
of nothing. ZiguratIP's `Makefile.global` defaults `MODE` to **Debug**;
only `Release` adds `-O3`, and only `Core` and `Cryptography` carry their
own `OPTIMIZE` line. So `StreamIO`, `Type`, `Compiler`, `SocketIO` and
`MVCCS` were the ones that could have been wrong — and every one of them
contains `.cold` sections, which GCC emits only when optimising and never
at `-O0`, with no `.debug_info` that `-g` would have left.

| | how it was checked |
|---|---|
| ZiguratIP libs + `ziguratip` | `.cold` present (28–346 functions), no debug info |
| `cocolog` | `.cold` × 89; `make` uses `-O3` and Cicili `--release` |
| `embed.o` | has no `-O` flag of its own — Cicili's `--release` **injects** `-O3`, confirmed in the emitted `g++` line |
| `torch.so`, `bigint.so` | `.cold` × 56 / 4 |
| `tcp.so`, `thread.so`, `curl.so` | rebuilt with `build.sh` → **md5 identical** |
| The Coco's nine modules | rebuilt → **md5 identical** |
| `libcocologc.a` | rebuilt → **md5 identical**; `CFLAGS` never overridden |

The pure-C modules show **no `.cold` at all**, which proves nothing —
straight-line C without exceptions is rarely partitioned. Those were
settled by rebuilding with the release script and comparing checksums.

### Rule seven: start from a known store

**The store lanes were sliding 2-3x over one afternoon and nothing in the
harness noticed.** Four consecutive runs, no code changed between them:

| lane | run 1 | run 2 | run 3 | run 4 |
|---|---|---|---|---|
| `seal_batched` | 11.46 | 9.18 | 7.13 | 6.03 |
| `parallel_own_kbs` | 21.00 | 17.63 | 15.45 | 12.53 |
| `parallel_one_kb` | 12.92 | 9.22 | 7.25 | 5.82 |
| `seal_batched_again` | 11.77 | 7.56 | 6.48 | 5.70 |

Four lanes, four runs, **monotone down every time** — and a `vacuum` put
them back to 15.73, 28.28, 20.33 and 13.25, *higher than the first run*.
Noise does not move one direction four times in four lanes. It is the
hazard cocolog's CLAUDE.md names: deleted rows are kept under MVCC and
nothing reclaims them, so every run walks past what the last one left.
`fresh` does not help, because `forget` DELETES, and under MVCC a delete
is a write.

**So the run now vacuums first**, which is what cocolog's own
`test/groups.sh` and `test/ruler.sh` already do for exactly this. **Four**
consecutive runs afterwards agree within **6%** where four had drifted
2-3x:

| lane | A | B | C | D |
|---|---|---|---|---|
| `seal_batched` | 15.13 | 15.68 | 15.37 | 15.79 |
| `parallel_own_kbs` | 26.56 | 25.01 | 25.66 | 26.08 |
| `parallel_one_kb` | 18.25 | 18.08 | 19.18 | 18.40 |
| `seal_batched_again` | 13.00 | 13.56 | 12.88 | 13.19 |

All four were gcc builds. **This band is what run E is measured against**,
and it is also why the clang table above stops short of calling the store
lanes settled: one run has no band of its own.

The vacuum is setup: it is not timed and it is not a lane.

**It does not make the lanes immune, and rule six still stands.** In the
run recorded above `seal_batched` reads 15.37 and `seal_batched_again`
12.88 — a 16% slide inside ONE run, on a fresh knowledge base, minutes
apart. The store ages while you measure it. Starting from a known point
is the difference between a reading and an anecdote; it is not the
difference between a reading and a truth.

**COCOLOG'S 300x ENGINE FIX MOVED NONE OF THIS, and it was checked
rather than assumed.** cocolog made `coco_make` dereference its
arguments, which took `between(1,20000,_), fail` from 15.5s to 51ms.
These lanes did not move at all: the same `verify` workload read
**389/s on a build WITHOUT the fix and 383-395/s with it**, back to back
on this machine. The lanes are ECDSA-bound — 3000 verifies at ~2.5ms is
7.5s, and the engine overhead the fix removed was ~200ms of that. A
benchmark that had been quoted as evidence of the speedup would have
been quoting the machine.

**Two lanes had stopped reading, and neither was the fix's doing.**
`verify` and `validate` came back REFUSED — *the run was too short to
mean anything* — because 300 verifies take 0.78s on this container where
they cleared the one-second floor on the one this was written on. The
pre-fix build takes 0.771s too. The counts are 2000 and 30 now: **the
count is part of the arrangement and moves with the machine.**
`seal_per_turn` at ten was worse than refused, it *straddled* the floor —
1.04s on one run and under on the next, printing a rate once and
REFUSED once from the same code on the same machine.

**And a refusal now says which rule.** `harness.pl` computes `why`
precisely so a person can act on it, and the shell pipeline dropped it:
the reason line is indented and the `grep -aE '^[a-z_]+ '` never matched
it. Three lanes read REFUSED for three different reasons and the page
said only REFUSED. A rule that will not name itself is a rule you have to
go and read the source for.

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

### Two tiers of library, and 23 directives that did nothing

**A `use_module` FOR A TIER-1 LIBRARY IS A DIRECTIVE THAT DOES
NOTHING**, and there were twenty-three of them here. Sixteen libraries
answer before cocolog's first goal runs — `lists`, `apply`, `builtins`,
`dcg`, `files`, `library` and `zigurat` compiled into the binary, and
SWI's `assoc`, `pairs`, `ordsets`, `yall`, `aggregate`, `ugraphs`,
`dcg_basics` and `dcg_high_order` read from `lib/swipl` beside it. They
are part of Prolog, not an optional extra: a program that must announce
`library(assoc)` before it can use an association list is doing the
interpreter's bookkeeping for it.

The lines read like dependencies and were not, which is the actual cost:
a reader of `contracts/dex/uniswap.pl` had no way to tell which of its
imports mattered. They were written out of habit from another Prolog.

**IT IS CHECKABLE RATHER THAN REMEMBERED**, and that is why the sweep
could be trusted — copy the binary somewhere with no `library/` beside
it, point `COCOLOG_LIBRARY` at nothing, and ask:

    COCOLOG_LIBRARY=/nowhere /tmp/d/cocolog query \
      "use_module(library(lists)), write(yes), nl"

Answering `yes` from a directory with no library path at all is what
compiled-in means. Every one of the sixteen answers.

**`$COCOLOG_LIBRARY` IS A LIST, AND `test/config.sh` NOW APPENDS TO IT.**
It is the one variable in that file which does not simply defer to the
environment, and the reason is that the two directories it names — The
Coco's own `library/` and cocolog's — are not a default anybody could
have meant to replace. So they go at the FRONT and whatever the caller
exported is kept behind them:

    COCOLOG_LIBRARY="$COCO_PATHS_LIBRARY:$COCO_PILLARS_COCOLOG/library${COCOLOG_LIBRARY:+:$COCOLOG_LIBRARY}"

Ours first, so a suite cannot go green about somebody else's copy of a
library it is testing; theirs kept, so `COCOLOG_LIBRARY=/opt/mine sh
test/run.sh` works. It used to be an assignment, and every run threw away
a path somebody had exported on purpose.

### Uniswap, and the arithmetic that had to come first

**A DEX ON THE LADDER'S RUNG 3**, which is where a contract is a predicate.
Nothing about it needed a new mechanism: `contracts/dex/uniswap.pl` is v2
— the constant product, the fee, the LP share, the invariant that must not
decrease — and `contracts/dex/uniswap-v3.pl` is concentrated liquidity,
where a position is an NFT minted from `contracts/token/nonfungible.pl`
because two providers in one pool own genuinely different things:
different ranges, different fee exposure. A share cannot be a balance.

**`library(u256)` HAD TO EXIST FIRST, and the reason is a number.**
cocolog's integers are 64 bits and they WRAP IN SILENCE:

    1000000000000000000 * 997  =  875820019684212736

That is the first product a v2 swap computes at ordinary token scale, and
it is already a wrong answer nobody was told about. So the arithmetic
moved into a Cicili module — 256-bit add, sub, mul, div, mod, muldiv and
sqrt, none of them wrapping, an operation that cannot represent its answer
RAISING instead. A DEX built on quietly wrapping integers is not a smaller
DEX; it is a different program that agrees with this one on small numbers.

**`library(tickmath)` is v3's other half**: prices as ticks, ticks as
square roots, and the Q64.96 fixed point Uniswap actually uses. Crossing a
tick means splitting one swap across ranges, and the liquidity that is in
range changes underneath it — so a swap is a loop, and each step is a
separate piece of arithmetic with its own rounding direction.

**FEE GROWTH IS PER RANGE, and that is the same device Aave uses.** Fees
cannot be credited to every position on every swap — that is work
proportional to the number of providers, on every trade. So the pool keeps
a global fee-growth accumulator and each tick records the growth OUTSIDE
it; the growth *inside* a range is arithmetic on three numbers, and a
position's owed fees is the difference since it last looked. Constant work
per swap, exact per position.

28 checks for v2, **61 for v3**, 32 for the token contracts under them,
all GREEN.

### Aave: a pot, a rule, and the moment a position stops being safe

**No counterparties, only a pot.** Everyone's deposits of one asset go
into one pool; borrowers take from it against collateral posted elsewhere
in the protocol; the interest borrowers pay is what suppliers earn.
`contracts/lending/aave.pl` is supply, withdraw, borrow, repay, accrual,
utilization, the two-slope rate model, health, and liquidation.

**A BALANCE IS A SCALED AMOUNT TIMES AN INDEX**, which is the whole trick
and the same one v3 uses for fee growth. Interest cannot be credited to
every account on every transaction. So the pool keeps ONE index per side,
growing with time, and stores each user's balance DIVIDED by the index at
the moment they touched it; multiply back and the interest is there.
Constant work per operation, exact per user.

**HEALTH IS A QUERY, not a stored number**, which is the ladder's thesis
showing through: a position's health factor is computed from the oracle
and the current indexes every time it is asked, so there is no cached
value to go stale between the block that made a position unsafe and the
block that notices. Liquidation is then a rule anybody can evaluate and
nobody can disagree about.

39 checks, GREEN.

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

**The asymmetry is the point, and it was measured rather than asserted** —
and RE-measured, by `bench/poh.sh`, which exists because the numbers below
it did not survive being taken again. At 32,000,000 ticks: produce in one
process **10.11 s**, verify in one process **10.08 s**, verify in four
processes **2.58 s** — **3.9× on four cores**. The work is paid once, in
order, by one party, and audited by everybody at once.

**The speedup is flat at 3.9× across both sizes** — 8M and 32M read the
same — and that is the interesting change. The earlier reading was 1.8× at
12M and 2.8× at 32M, and this file explained the slope correctly: every
verifier paid about 0.4 s of process start-up, so the ratio depended on how
much work it was amortised over, and the dilution was the harness rather
than the mechanism. **Start-up is 0.01 s now**, so there is nothing left to
amortise and the mechanism shows through undiluted at very nearly the four
cores it runs on. The old reasoning was right; what changed is that the
thing it was reasoning about went away.

The tight loop runs at **3.17M ticks/s** with start-up subtracted, against
2.57M when it was last taken.

**AND TWO NUMBERS IN THIS SECTION WERE WRONG BY TWO ORDERS OF MAGNITUDE.**
They are corrected here rather than quietly replaced, because how they came
to be wrong is the more useful part:

| | was written | measures |
|---|---|---|
| a tick through the module seam | ~600 µs | **~3.0 µs** |
| `poh_slow_run/3` against the C loop | ~4000× slower | **9–10×** |

The oracle runs at **326 000–331 000 ticks/s**, flat across 100 000,
400 000 and 1 000 000 ticks, against the module's 3.08M — measured at sizes
where BOTH lanes clear the clock, which the first attempt did not: at 2 000
and 20 000 ticks the C lane reads 0.00 s and 0.01 s, and the 5× and 9× that
came out of dividing by them were arithmetic on noise.

**The likely cause is cocolog's deref fix, and this is an inference rather
than a proof.** That change — an argument dereferenced as it is stored —
took a 3 000-deep recursion's REF chain from 8 999 links to 2, and measured
15 529 ms → 51 ms on a backtracking loop. Roughly 300×, which is the order
of the gap here; `poh_slow_run/3` is a deterministic tail recursion a
million deep, exactly the shape that bug punished. The evidence for it is
that the oracle's rate is now FLAT across three sizes — a quadratic engine
could not produce that — and the evidence against reading it as certain is
that nobody re-took the PoH numbers after that fix, so the two were never
measured on the same binary.

**The architectural conclusion survives the correction, and it is worth
saying that plainly rather than letting a smaller number pass unremarked.**
9–10× is not 4000×, and an argument that rested on 4000× would be in
trouble. It rests on the shape instead: at 32M ticks the module takes 10 s
and the clauses would take about 97 s, and a spine is a thing you make
LONG. The loop belongs in Cicili — but because a clock nobody can wind
backwards has to be cheap per tick, not because the interpreter is
hopeless. It is not; it is about ten times slower at this, which is the
same band the language benchmark reports for everything else.

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

`test/crypto.pl` holds all of it to fifteen checks: the published
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

## Future work, recorded before it is built: COCO, and a game as a chain

Nothing in this section exists yet. It is the owner's plan for the
cooperation between The Coco and CivV, written down the day it was
designed so the rungs can land against a stated shape — and so the
parts that were argued OUT of the design stay out.

**COCO, the native token.** Accounts pay COCO for the compute their
turns consume. The gas meter is cocolog's own inference counter — the
engine already counts (`step` answers "suspended at N inference(s)");
pricing a turn by it is a seam in the machine runner, not a VM. The
debit rides INSIDE the turn's transaction — CivV's `take_turn/1` is
already claim-play-hand-over in one commit, so pay-or-roll-back comes
from the existing shape. Charged per TURN, never per engine step: a
turn is atomic, so the gas check is before it, with a bounded worst
case. Genesis of a match escrows the players' stakes and dispatches
each side's gas allowance in block 1.

**Consensus: signed halves, not proof-of-work — and why.** CivV's
engine is deterministic and replayable (two processes produce
bit-identical games, pinned in its suite), which means in-game
production is WORK THAT COSTS NOTHING TO COUNTERFEIT — an attacker
simulates a million turns for free, so production can never decide
which history is true. What secures a match instead is what CivV
already has: real X.509 identities (the fog rungs' own mechanism) and
deterministic replay. A match is a TWO-PARTY STATE CHANNEL — each
committed half carries the mover's signature over its order list and
`versus_state` hash; the opponent's next half counter-signs; a
disputed block is settled by a bare process replaying the order log,
which is this family's founding claim doing consensus duty. The COCO
ledger orders and checkpoints match-blocks across matches; no match
mines.

**Production-weighted EMISSION — the owner's proof-of-work idea, in
the seat where it is sound.** Work decides who gets PAID; signatures
decide what HAPPENED. Each round (both halves) closes one match-block,
and the right to mint that block's reward goes to the cities that
produced that turn, weighted by the yield rows the game already
commits (`city_prod`, `research_progress`, `city_food`). Milestones
mint NFTs on their own committing transactions: a finished wonder, a
completed tech, a promoted veteran. Units are NFTs by construction —
CivV's capture clause already retracts one `unit_owner` row and
asserts another, which IS transfer; production mints, the kill burns.
A hash stamp on blocks, if wanted, is difficulty-1 spam control and
never the security.

**Movement priced in COCO.** Per-terrain movement cost already exists
(`unit_mp` spends by terrain); the fee is MP-consumed times the
terrain's price, debited in the same turn transaction — roads join
when CivV grows the road improvement's movement bonus. Two balance
laws, stated now: each turn's gas grant INCLUDES a movement allowance,
because naked pay-per-step biases the game toward the fortress its own
rung 27 measured; and ENDING A TURN IS ALWAYS FREE — a drained wallet
must never stall a match and hold the opponent hostage.

**Argued out, deliberately.** Gold is NOT COCO: the Warrior-at-200
price is the vendored reference's game balance, and a token peg would
turn every balance tweak into monetary policy and every exploit into
theft — stake-and-settle instead, the escrow released by
`match_over/1`'s own committing transaction. Tech NFTs are out: Civ V
removed tech trading for balance, the snapshot's counts are pinned,
and any unit crossing matches must pass the same `production_unlocked`
fences production does — a bridge that skips the game's own laws
breaks the game. Fog versus a public ledger is the real tension: posted
orders leak positions the opponent's `fog_sees/3` forbids, so the
store remains the referee and the chain is NOTARY AND SETTLEMENT —
order hashes live during play, the full log revealed at match end for
verification. Commit-reveal per half is the fallback; zk proofs are
named and deferred.

**The rungs, when this work opens**: (1) the COCO ledger — accounts,
u256 balances, the inference-priced gas schedule, debit-in-turn; (2)
the order log — signed halves appended per commit, sha over
`versus_state`; (3) genesis and settlement — escrow, gas dispatch,
release on the crown; (4) unit NFTs riding enroll, capture and kill;
(5) the dispute verifier — a bare process replays a challenged block
and the signatures decide who lied, and that case is the suite pin.
Each lands with its GREEN line or it is not on this page.

**Rung (1) has landed, HERE rather than in the game** — see "COCO: the
native token, and a gas price that is a measurement" above, and ladder
rung 9. The accounts, the u256 balances, the inference-priced schedule
and the debit riding inside the turn's own transaction all exist and are
checked; what is written above about the gas meter turned out to be true
in one respect the plan did not know, and that respect is the rung's
whole point: the engine's count was not readable from Prolog at all, so
the seam was not "in the machine runner" but a new builtin in cocolog
(`call_metered/4`), built there on its own merits. What is still ahead
for the GAME is everything that makes a match a chain — the order log,
the escrow, the unit NFTs, the dispute verifier — and the movement fee,
which now has a currency to be denominated in. CivV is untouched by this
rung, deliberately: a token nobody can spend yet is a smaller claim than
a token wired into a game that has not agreed to it.

## The disciplines

They hold across every rung, and every one was already paid for in
cocolog's stories: long compute never inside a turn; anything big
travels chunked because a row fits in a page; permission gates the door
and the signature rides in the row; dirty reads accelerate and never
finalize; and a claim is only made after `test/run.sh` — with the
server up — ends `red: 0`.

One more, added the day the link could be encrypted: **an authenticated
peer is not a trusted one.** Every validity rule here asks who SIGNED the
block and never who opened the socket, and no path may ever skip
re-verification because a peer arrived over TLS. `test/secure.pl` holds
that in both directions — mallory over a verified link is refused exactly
as she was in the clear, and every honest verdict is unchanged — so a
consensus law that started depending on the transport would show up as a
difference between two runs rather than as nothing at all.
