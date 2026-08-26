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
HOST=$ZIGURAT_HOST
PORT=$ZIGURAT_PORT

red=0
ran=""
say() { ran="$ran $1"; printf '%-10s %s\n' "$1" "$2"; }

if [ ! -x "$C" ]; then
  echo "no cocolog binary at $C -- build cocolog first (or set COCOLOG)"; exit 1
fi

# ---- local ----------------------------------------------------------
got=$(timeout 60 "$C" run "$ROOT/modules/hello.pl" hello 2>&1)
want="cicili, the philosopher, writes it
zigurat, the warrior, keeps it
coco, the engineer, makes it think"
if [ "$got" = "$want" ]; then
  say local GREEN
else
  say local "RED: got [$got]"; red=$((red + 1))
fi

# ---- math: the width an exchange needs --------------------------------
# library(u256): 256-bit integers that REFUSE rather than wrap. The case
# opens by pinning the wrong answer cocolog's own 64-bit is/2 gives for
# the first product a swap computes, because that is why the module
# exists.
if sh "$HERE/math.sh" > "$HERE/math.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/math.out"; then
    say math "$(head -1 "$HERE/math.out")"
  else
    say math GREEN
  fi
else
  say math RED; sed 's/^/   /' "$HERE/math.out"; red=$((red + 1))
fi

# ---- crypto: the chains' primitives -----------------------------------
# keccak256 and secp256k1 as loadable Cicili modules, and library(eth)
# composing them into the question an EVM chain asks: who signed this.
# test/crypto.sh has the vectors and says why each is there.
if sh "$HERE/crypto.sh" > "$HERE/crypto.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/crypto.out"; then
    say crypto "$(head -1 "$HERE/crypto.out")"
  else
    say crypto GREEN
  fi
else
  say crypto RED; sed 's/^/   /' "$HERE/crypto.out"; red=$((red + 1))
fi

# ---- ledger: rung 2 ---------------------------------------------------
# Three authorities on three knowledge bases seal in turn, gossip, fork,
# and close the fork by rule -- and mallory attacks every law the chain
# has. test/ledger.sh says what each check is for and why one attack is
# supposed to succeed.
if sh "$HERE/ledger.sh" > "$HERE/ledger.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/ledger.out"; then
    say ledger "$(head -1 "$HERE/ledger.out")"
  else
    say ledger GREEN
  fi
else
  say ledger RED; sed 's/^/   /' "$HERE/ledger.out"; red=$((red + 1))
fi

# ---- contracts: rung 3 ------------------------------------------------
# A contract is a predicate, deployment is a block, the fence is a static
# check and gas is the engine's own --steps. mallory writes contracts
# too: seven refused, one admitted because only gas can answer it.
if sh "$HERE/contracts.sh" > "$HERE/contracts.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/contracts.out"; then
    say contracts "$(head -1 "$HERE/contracts.out")"
  else
    say contracts GREEN
  fi
else
  say contracts RED; sed 's/^/   /' "$HERE/contracts.out"; red=$((red + 1))
fi

# ---- training: rung 4 -------------------------------------------------
# Proof of USEFUL work. Every worker claims 0.99; settlement measures and
# reaches different verdicts. test/training.sh says what each check is
# for and which attack it answers.
if sh "$HERE/training.sh" > "$HERE/training.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/training.out"; then
    say training "$(head -1 "$HERE/training.out")"
  else
    say training GREEN
  fi
else
  say training RED; sed 's/^/   /' "$HERE/training.out"; red=$((red + 1))
fi

# ---- spine: rung 5 ----------------------------------------------------
# The PoH spine. Production is sequential and cannot be split; checking
# is parallel. The suite checks the checkable half and pins the spine to
# constants computed outside this project; the measured speedup lives in
# spine/run.sh, because a timing is not a pass or a fail.
if sh "$HERE/spine.sh" > "$HERE/spine.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/spine.out"; then
    say spine "$(head -1 "$HERE/spine.out")"
  else
    say spine GREEN
  fi
else
  say spine RED; sed 's/^/   /' "$HERE/spine.out"; red=$((red + 1))
fi

# ---- votes: rung 6 ----------------------------------------------------
# Stake is a query over the chain, a quorum is a counting rule, and a
# block a quorum precommitted is final. mallory is an INSIDER here --
# admitted, staked, entitled to vote -- and one of her eight attacks
# succeeds, because a hash-seeded draw is grindable.
if sh "$HERE/votes.sh" > "$HERE/votes.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/votes.out"; then
    say votes "$(head -1 "$HERE/votes.out")"
  else
    say votes GREEN
  fi
else
  say votes RED; sed 's/^/   /' "$HERE/votes.out"; red=$((red + 1))
fi

# ---- hub: rung 7 ------------------------------------------------------
# The aggregator. Each chain publishes its own validity and fork-choice
# rules as entries on itself, and the host verifies foreign chains by
# reading those rules and running them under the fence contracts run
# under. One of mallory's eight attacks succeeds, because an aggregator
# cannot be stronger than the chains it aggregates.
if sh "$HERE/hub.sh" > "$HERE/hub.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/hub.out"; then
    say hub "$(head -1 "$HERE/hub.out")"
  else
    say hub GREEN
  fi
else
  say hub RED; sed 's/^/   /' "$HERE/hub.out"; red=$((red + 1))
fi

# ---- token: the two standards -----------------------------------------
# contracts/token/{fungible,nonfungible}.pl -- what every protocol here
# is built out of. The invariants are conservation (balances sum to
# supply) and exactly-one-owner, each checked by a predicate nothing in
# the contract needs to be true for its own code to work. Two real
# thefts are attempted and must fail: ERC-20's approve race, and taking
# an NFT back with an approval that should have died with the sale.
if sh "$HERE/token.sh" > "$HERE/token.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/token.out"; then
    say token "$(head -1 "$HERE/token.out")"
  else
    say token GREEN
  fi
else
  say token RED; sed 's/^/   /' "$HERE/token.out"; red=$((red + 1))
fi

# ---- uniswap: a pool as rules -----------------------------------------
# contracts/dex/uniswap.pl -- a contract, reached by path. A
# constant-product exchange over library(u256), the type money is
# Uniswap's own (996006981039903216 for one token into a 1000/1000 pool,
# a number from the world), the invariant is CHECKED on the reserves
# that landed rather than trusted to the formula, and mallory tries to
# drain it.
if sh "$HERE/uniswap.sh" > "$HERE/uniswap.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/uniswap.out"; then
    say uniswap "$(head -1 "$HERE/uniswap.out")"
  else
    say uniswap GREEN
  fi
else
  say uniswap RED; sed 's/^/   /' "$HERE/uniswap.out"; red=$((red + 1))
fi

# ---- bench: rung 8 ----------------------------------------------------
# The TPS harness's RULES, not its timings. A timing is not a pass or a
# fail, so the numbers live in bench/tps.sh with their arrangement
# printed beside each of them; what is checkable here is whether the
# harness would have refused a dishonest reading. mallory attacks the
# MEASUREMENT, and her eighth attempt -- choosing the workload --
# succeeds, because it is upstream of every rule a harness can have.
if sh "$HERE/bench.sh" > "$HERE/bench.out" 2>&1; then
  if grep -q '^SKIP' "$HERE/bench.out"; then
    say bench "$(head -1 "$HERE/bench.out")"
  else
    say bench GREEN
  fi
else
  say bench RED; sed 's/^/   /' "$HERE/bench.out"; red=$((red + 1))
fi

# ---- wire -----------------------------------------------------------
W="--host $HOST --port $PORT --timeout $ZIGURAT_TIMEOUT --kb $ZIGURAT_KB"
if timeout 20 "$C" $W list >/dev/null 2>&1; then
  timeout 60 "$C" $W forget >/dev/null 2>&1
  timeout 60 "$C" $W consult "$ROOT/modules/hello.pl" >/dev/null 2>&1
  got=$(timeout 60 "$C" $W query "pillar(coco, Role, Deed), format(\"~w ~w~n\", [Role, Deed])" 2>/dev/null | grep -a '^engineer')
  if [ "$got" = "engineer makes it think" ]; then
    say wire GREEN
  else
    say wire "RED: got [$got]"; red=$((red + 1))
  fi
  timeout 60 "$C" $W forget >/dev/null 2>&1
else
  say wire "SKIP no Zigurat server at $HOST:$PORT"
fi

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
