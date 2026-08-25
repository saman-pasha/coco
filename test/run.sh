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
# Needs a BUILT cocolog: $COCOLOG points at its checkout (default: a
# sibling directory named cocolog).

HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=$(cd "$HERE/.." && pwd)
C="${COCOLOG:-$ROOT/../cocolog}/cocolog"
HOST=${ZIGURAT_HOST:-127.0.0.1}
PORT=${ZIGURAT_PORT:-2160}

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

# ---- wire -----------------------------------------------------------
W="--host $HOST --port $PORT --timeout 15 --kb coco_hello"
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
