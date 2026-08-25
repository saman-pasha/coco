#!/bin/sh
# Rung 5: the PoH spine -- a clock nobody can wind backwards.
#
# THE ASYMMETRY IS THE WHOLE POINT, and this arrangement measures it.
#
#   h(n+1) = sha256(h(n)). To know h(n) you must have computed the n-1
#   hashes before it: there is no shortcut through a hash chain, and no
#   way to parallelise PRODUCTION. One producer, one core, in order.
#
#   Checking it is embarrassingly parallel -- provided the producer
#   published checkpoints. K verifiers each take one segment, re-run it,
#   and never need to hear about each other.
#
#   So the work is paid once, sequentially, by one party, and audited by
#   everybody at once. That is what a spine is for.
#
# What this walks through:
#
#   1. PRODUCE a spine of N ticks and publish K checkpoints -- timed;
#   2. VERIFY it in one process, one segment after another -- timed;
#   3. VERIFY it again in K processes at once -- timed, and the same
#      answer;
#   4. ANCHOR two blocks into the sequence, and read their order back off
#      the spine alone;
#   5. mallory attacks the clock, and one of her attacks works.
#
# Needs a Zigurat server: the segments are rows, and the verifiers are
# separate processes reading them. SKIPs without one.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../test/config.sh"
C="$COCOLOG_BIN"

BASE="--host $ZIGURAT_HOST --port $ZIGURAT_PORT --timeout 120"
KB="$BASE --kb spine_demo"
F="$ROOT/spine/node.pl $ROOT/spine/mallory.pl"
K="use_module(library(poh))"

TICKS=${SPINE_TICKS:-32000000}
PARTS=${SPINE_PARTS:-4}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi
if ! timeout 20 "$C" $KB list >/dev/null 2>&1; then
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT"; exit 0
fi

secs() { python3 -c "import sys;print(f'{float(sys.argv[2])-float(sys.argv[1]):.2f}')" "$1" "$2"; }
now()  { date +%s.%N; }

timeout 120 "$C" $KB forget >/dev/null 2>&1
for f in $F; do timeout 120 "$C" $KB consult "$f" >/dev/null 2>&1; done

echo "== producing: $TICKS ticks, $PARTS checkpoints"
echo "   one process, in order, no way to hurry it"
t0=$(now)
timeout 300 "$C" $KB query "$K, spine_produce($TICKS, $PARTS)" >/dev/null 2>&1
t1=$(now)
PROD=$(secs "$t0" "$t1")
python3 -c "print(f'   {\"$PROD\"}s  ->  {$TICKS/float(\"$PROD\")/1e6:.2f}M ticks/s including the turn')"

echo
echo "== verifying, one process, all $PARTS segments in a row"
t0=$(now)
timeout 300 "$C" $KB query "$K, forall(between(0,$((PARTS-1)),I), (spine_seg(I,A,T,B), poh_verify(A,T,B))), write(all_ok), nl" 2>/dev/null | grep -aoE '^all_ok$' | sed 's/^/   /'
t1=$(now)
SEQ=$(secs "$t0" "$t1")
echo "   $SEQ s"

echo
echo "== verifying again, $PARTS processes at once"
t0=$(now)
i=0
while [ "$i" -lt "$PARTS" ]; do
  ( timeout 300 "$C" $KB query "$K, spine_seg($i,A,T,B), (poh_verify(A,T,B) -> write(ok($i)) ; write(broken($i))), nl" 2>/dev/null \
      | grep -aoE '^(ok|broken)\([0-9]+\)$' ) &
  i=$((i + 1))
done
wait
t1=$(now)
PAR=$(secs "$t0" "$t1")
echo "   $PAR s"
python3 -c "
import os
s=float('$SEQ'); p=float('$PAR'); n=os.cpu_count()
print(f'   -- {s/p:.1f}x, on {n} cores. Production cannot be split; checking can.')
print(f'      Short of {n}x because every verifier pays ~0.4s of process')
print(f'      start-up: at 12M ticks this reads 1.8x, at 32M it reads {s/p:.1f}x.')
print(f'      The dilution is the harness, not the mechanism.')"

echo
echo "== anchoring two blocks, and reading their order off the spine"
timeout 120 "$C" $KB query "$K, use_module(library(sha256)), sha256('block one', B1), anchor_block(B1)" >/dev/null 2>&1
timeout 120 "$C" $KB query "$K, use_module(library(sha256)), sha256('block two', B2), anchor_block(B2)" >/dev/null 2>&1
timeout 120 "$C" $KB query "$K, anchor_order(P), forall(member(T-B,P), (sub_atom(B,0,8,_,S), format(\"   tick ~w  block ~w~n\",[T,S])))" 2>/dev/null | grep -a '^   tick'
echo "   -- nobody was asked when they saw what; the sequence says."

echo
echo "== mallory attacks the clock"
for a in attack_skip attack_shorten attack_backdate attack_splice attack_fork; do
  printf '   %-16s ' "$a"
  timeout 300 "$C" run $F "$K, $a(V), write(V), nl" 2>/dev/null \
    | grep -aoE '^(refused|ACCEPTED)$' | head -1
done
echo "   -- the fork works, and is supposed to: a spine orders what is ON it."
echo "      Which spine is the chain's is the LEDGER's question, not the clock's."
