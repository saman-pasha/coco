#!/bin/sh
# The Coco's suite.
#
#   local   the one cocolog binary consults modules/hello.pl and answers,
#           no server anywhere: the pillars build and The Coco runs.
#   crypto  the chains' primitives -- keccak256 and secp256k1 as loadable
#           Cicili modules, held to published vectors; test/crypto.sh.
#   wire    one process WRITES the module's clauses into a knowledge
#           base, a second -- which consulted nothing -- reads them
#           back: the family's cross-process claim, made from this
#           repository. SKIPs without a server, because "no server
#           here" and "the hub is wrong" are different findings.
#
# Everything this needs to know -- where the pillars are, which knowledge
# base the wire cases speak to, which cases exist -- is in coco.yaml, read
# by config.sh. The environment still wins over the file.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

red=0
ran=""
say() { ran="$ran $1"; printf '%-10s %s\n' "$1" "$2"; }

# A CASE IS A COCOLOG SCRIPT WHERE test/<c>.pl EXISTS: `-s' loads it and
# proves main, and THE EXIT CODE IS THE VERDICT -- 0 exactly when main
# proved, which `checks_done' withholds on any red check. The .sh
# spelling drives whatever has not been converted yet, so the suite is
# green throughout the conversion rather than at the end of it. This is
# CivV's line, and it is here for the reason it was there: eighteen
# copies of one `if sh ... grep SKIP ... else RED' block were eighteen
# places to get the SKIP handling subtly different.
case_run() {
  _c=$1
  if [ -f "$HERE/$_c.pl" ]; then
    ( cd "$ROOT" && timeout 3600 "$C" -s "test/$_c.pl" ) > "$HERE/$_c.out" 2>&1
  else
    sh "$HERE/$_c.sh" > "$HERE/$_c.out" 2>&1
  fi
  if [ $? -eq 0 ]; then
    if grep -aq '^SKIP' "$HERE/$_c.out"; then
      say "$_c" "$(grep -a '^SKIP' "$HERE/$_c.out" | head -1)"
    else
      say "$_c" GREEN
    fi
  else
    say "$_c" RED; sed 's/^/   /' "$HERE/$_c.out"; red=$((red + 1))
  fi
}

if [ ! -x "$C" ]; then
  echo "no cocolog binary at $C -- build cocolog first (or set COCOLOG)"; exit 1
fi

# ---- local ----------------------------------------------------------
# The suite's smallest case: the pillars built, the binary runs, a .pl
# file in this repository loads and proves a goal -- with no store, no
# key and no chain in the way. Everything after it assumes all four.
case_run local

# ---- math: the width an exchange needs --------------------------------
# library(u256): 256-bit integers that REFUSE rather than wrap. The case
# opens by pinning the wrong answer cocolog's own 64-bit is/2 gives for
# the first product a swap computes, because that is why the module
# exists.
case_run math

# ---- crypto: the chains' primitives -----------------------------------
# keccak256 and secp256k1 as loadable Cicili modules, and library(eth)
# composing them into the question an EVM chain asks: who signed this.
# test/crypto.sh has the vectors and says why each is there.
case_run crypto

# ---- ledger: rung 2 ---------------------------------------------------
# Three authorities on three knowledge bases seal in turn, gossip, fork,
# and close the fork by rule -- and mallory attacks every law the chain
# has. test/ledger.sh says what each check is for and why one attack is
# supposed to succeed.
case_run ledger

# ---- contracts: rung 3 ------------------------------------------------
# A contract is a predicate, deployment is a block, the fence is a static
# check and gas is the engine's own --steps. mallory writes contracts
# too: seven refused, one admitted because only gas can answer it.
case_run contracts

# ---- coco: the native token, and gas priced in inferences -------------
# What the chain CHARGES IN, which a contract cannot be: the fence has no
# way to price its own execution. The fee is arithmetic over the ENGINE's
# own inference count (cocolog's `call_metered/4'), so the checks are the
# ones that tell a meter from a constant -- ten times the work costs
# strictly more, the same call twice costs the same to the unit -- plus
# the two laws gas exists for: work that failed still pays, and nobody
# buys gas they cannot pay for.
case_run coco

# ---- bond: the stake IS the coin --------------------------------------
# Rung 6 read stake off the chain as a NUMBER and said outright that
# nobody is slashed, because nothing had been put up. Here `stake_entry/2'
# is a RULE over bonded COCO -- so `quorum/2' and the leader draw weigh
# money somebody can lose -- and `library(bft)''s evidence finally takes
# it. Weighted on the two attacks: unbonding first does not save a
# culprit (the money is at risk until it lands), and two fabricated
# certificates rob nobody.
case_run bond

# ---- units: a game's units as NFTs ------------------------------------
# The collection is FENCED and deployed, so it is reached by transaction
# -- which is why it needed `caller/1' first: every ownership predicate
# here took its owner as an ARGUMENT, safe only while the caller was the
# node itself. Weighted on the three powers and their fences: only a
# match's referee mints into it, capture moves a unit without the
# holder's consent (and reaches no other match), and a kill burns the id
# forever. Provenance is a query over the blocks, and keeps only what
# took effect.
case_run units

# ---- training: rung 4 -------------------------------------------------
# Proof of USEFUL work. Every worker claims 0.99; settlement measures and
# reaches different verdicts. test/training.sh says what each check is
# for and which attack it answers.
case_run training

# ---- spine: rung 5 ----------------------------------------------------
# The PoH spine. Production is sequential and cannot be split; checking
# is parallel. The suite checks the checkable half and pins the spine to
# constants computed outside this project; the measured speedup lives in
# spine/run.sh, because a timing is not a pass or a fail.
case_run spine

# ---- votes: rung 6 ----------------------------------------------------
# Stake is a query over the chain, a quorum is a counting rule, and a
# block a quorum precommitted is final. mallory is an INSIDER here --
# admitted, staked, entitled to vote -- and one of her eight attacks
# succeeds, because a hash-seeded draw is grindable.
case_run votes

# ---- secure: the three consensus rungs, over TLS ----------------------
# cocolog grew `--tls', so every node here can reach its chain over an
# encrypted link. This runs ledger, spine and votes AGAIN behind a TLS
# terminator and requires the verdicts to be identical -- because every
# law those rungs enforce is about content (a hash recomputed, a
# signature checked, a tick count re-run) and none of them asks who
# handed the bytes over. It also proves the converse, which is the one an
# encrypted transport invites you to forget: mallory over a VERIFIED TLS
# link is refused exactly as she was in the clear.
case_run secure

# ---- hub: rung 7 ------------------------------------------------------
# The aggregator. Each chain publishes its own validity and fork-choice
# rules as entries on itself, and the host verifies foreign chains by
# reading those rules and running them under the fence contracts run
# under. One of mallory's eight attacks succeeds, because an aggregator
# cannot be stronger than the chains it aggregates.
case_run hub

# ---- token: the two standards -----------------------------------------
# contracts/token/{fungible,nonfungible}.pl -- what every protocol here
# is built out of. The invariants are conservation (balances sum to
# supply) and exactly-one-owner, each checked by a predicate nothing in
# the contract needs to be true for its own code to work. Two real
# thefts are attempted and must fail: ERC-20's approve race, and taking
# an NFT back with an approval that should have died with the sale.
case_run token

# ---- uniswap: a pool as rules -----------------------------------------
# contracts/dex/uniswap.pl -- a contract, reached by path. A
# constant-product exchange over library(u256), the type money is
# Uniswap's own (996006981039903216 for one token into a 1000/1000 pool,
# a number from the world), the invariant is CHECKED on the reserves
# that landed rather than trusted to the formula, and mallory tries to
# drain it.
case_run uniswap

# ---- uniswap-v3: concentrated liquidity -------------------------------
# contracts/dex/uniswap-v3.pl -- ranges instead of the whole curve, and
# a position that is an NFT because two providers in one pool no longer
# own the same thing. The tick constants are Uniswap's own and the
# suite pins them against the three values TickMath.sol publishes. A
# swap CROSSES: it is split at each initialised tick, the depth changes
# there, and the fees earned on each leg land only on the positions
# that were in range for it -- checked against an independent SwapMath
# reference, and summing to exactly the 0.3% charged.
case_run uniswap-v3

# ---- lending: a pot lent against collateral ---------------------------
# contracts/lending/aave.pl -- the other half of a chain's economy, and
# the one that needs a PRICE. A pool pays out only what the curve and
# the collateral allow, and the moment an oracle moves the same
# position stops being safe: nothing changed but a number somebody
# asserted, and the suite shows that rather than hiding it. Interest
# is a moving index against scaled balances, so a year passes and
# every balance moves without a single account being written.
case_run lending

# ---- bench: rung 8 ----------------------------------------------------
# The TPS harness's RULES, not its timings. A timing is not a pass or a
# fail, so the numbers live in bench/tps.sh with their arrangement
# printed beside each of them; what is checkable here is whether the
# harness would have refused a dishonest reading. mallory attacks the
# MEASUREMENT, and her eighth attempt -- choosing the workload --
# succeeds, because it is upstream of every rule a harness can have.
case_run bench

# ---- wire -----------------------------------------------------------
# The family's cross-process claim in the smallest possible way: one
# process consults modules/hello.pl into a knowledge base, a second --
# which consulted nothing -- opens the same base and proves a goal over
# clauses it never loaded. Every case that says "a bare process reads it
# back" is this sentence with a chain in it. SKIPs without a server.
case_run wire

# EVERY DECLARED CASE MUST HAVE RUN. coco.yaml calls itself the one
# declaration, but this file kept its own copy of the case list -- so a
# case added to the file was declared, listed, documented, and never
# run. It happened: `math' sat in coco.yaml through a green run that
# never executed it. The lists are still two, because each case here
# carries its own narration and a generic loop would lose that; what is
# no longer possible is the SILENT half of the drift.
missing=""
for c in $COCO_SUITE_CASES; do
  case " $ran " in *" $c "*) ;; *) missing="$missing $c" ;; esac
done
if [ -n "$missing" ]; then
  echo
  echo "DECLARED IN coco.yaml BUT NEVER RUN:$missing"
  red=$((red + 1))
fi

echo
echo "red: $red"
[ "$red" -eq 0 ]
