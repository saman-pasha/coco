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
say() { printf '%-10s %s\n' "$1" "$2"; }

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

echo
echo "red: $red"
[ "$red" -eq 0 ]
