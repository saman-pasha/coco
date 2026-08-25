#!/bin/sh
# The Coco's suite. Two cases so far -- the assembly proof:
#
#   local   the one cocolog binary consults modules/hello.pl and answers,
#           no server anywhere: the pillars build and The Coco runs.
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

# ---- crypto: keccak256, the first rung of the aggregator's crypto ----
# A loadable Cicili module, built and held to the published Keccak
# vectors -- the same digest every EVM chain computes. Two independent
# official vectors (empty, "abc") pin the permutation and padding; a
# multi-block input (200 bytes) crosses the 136-byte rate boundary; and
# keccak256_hex proves the hex-input path a chain needs for RLP bytes.
# SKIPs when the module cannot be built (no sbcl or CICILI checkout).
KLIB="$ROOT/library/keccak.so"
if [ ! -f "$KLIB" ]; then
  ( cd "$ROOT" && CICILI="${CICILI:-$HOME/cicili}" COCOLOG="${COCOLOG:-$ROOT/../cocolog}" \
      sh modules/crypto/build.sh ) > "$HERE/crypto-build.log" 2>&1 || true
fi
if [ -f "$KLIB" ]; then
  kk() { COCOLOG_LIBRARY="$ROOT/library" timeout 60 "$C" query \
           "use_module(library(keccak)), $1, write(H), nl" 2>/dev/null \
           | grep -aoE '[0-9a-f]{64}' | head -1; }
  cfail=0
  ckeck() { [ "$2" = "$3" ] || { echo "   keccak $1: got $2 want $3"; cfail=1; }; }
  ckeck empty    "$(kk "keccak256_hex('0x', H)")" \
                 "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470"
  ckeck abc      "$(kk "keccak256(abc, H)")" \
                 "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"
  ckeck hex-abc  "$(kk "keccak256_hex('616263', H)")" \
                 "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45"
  ckeck multi    "$(kk "findall(0'a, between(1,200,_), L), keccak256(L, H)")" \
                 "96ea54061def936c4be90b518992fdc6f12f535068a256229aca54267b4d084d"
  if [ "$cfail" -eq 0 ]; then say crypto GREEN; else say crypto RED; red=$((red + 1)); fi
else
  say crypto "SKIP (keccak.so not built -- no sbcl or CICILI checkout)"
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
