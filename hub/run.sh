#!/bin/sh
# Rung 7: the aggregator, narrated.
#
# THREE CHAINS UNDER THREE REGIMES, AND A HOST THAT WAS NOT TOLD ABOUT
# ANY OF THEM. Each member chain seals its own rules onto itself as an
# ordinary block. The aggregator consults `ledger/node.pl' and
# `hub/node.pl' and NOTHING ELSE -- in particular it never consults
# hub/chains.pl, so everything it knows about zeta, omega and psi it read
# off their blocks.
#
# What this walks through:
#
#   1. three chains PUBLISH their rules, which is three ordinary seals;
#   2. the aggregator FETCHES their blocks and learns to verify them --
#      fenced first, installed second;
#   3. it JUDGES a foreign block by that chain's own rule;
#   4. two chains DISAGREE about which head is better, from one list,
#      on one host, with one code path;
#   5. a CHECKPOINT: one hash for the whole federation, with an
#      inclusion proof for one member;
#   6. a BRIDGE waits as a suspended machine and thaws on a proof;
#   7. mallory attacks a host that runs code it did not write.
#
# Needs a Zigurat server: the chains are knowledge bases and the gossip
# is one process reading another's. SKIPs without one.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../test/config.sh"
C="$COCOLOG_BIN"

BASE="$ZIGURAT_DIAL --timeout 60"
LEDGER="$ROOT/ledger/node.pl"
NODE="$HERE/node.pl"
CHAINS="$HERE/chains.pl"
FED="$ROOT/votes/federation.pl"
K="use_module(library(poa)), use_module(library(hub)), use_module(library(contract))"
MEMBERS="zeta omega psi"

ALICE=1111111111111111111111111111111111111111111111111111111111111111
CAROL=3333333333333333333333333333333333333333333333333333333333333333
MALLORY=4444444444444444444444444444444444444444444444444444444444444444

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi
if ! timeout 20 "$C" $BASE --kb hub_anchor list >/dev/null 2>&1; then
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT"; exit 0
fi

key_of() {
  case "$1" in zeta) echo "$ALICE" ;; omega) echo "$CAROL" ;; psi) echo "$MALLORY" ;; esac
}
who_of() {
  case "$1" in zeta) echo alice ;; omega) echo carol ;; psi) echo mallory ;; esac
}

member() {
  ch=$1; shift
  NODE_NAME="$(who_of "$ch")" NODE_KEY="$(key_of "$ch")" \
    timeout 120 "$C" $BASE --kb "hub_$ch" query "$K, $*" 2>/dev/null
}
anchor() {
  NODE_NAME=alice NODE_KEY=$ALICE \
    timeout 120 "$C" $BASE --kb hub_anchor query "$K, $*" 2>/dev/null
}

echo "== three chains, each publishing its own rules"
for ch in $MEMBERS; do
  timeout 120 "$C" $BASE --kb "hub_$ch" forget >/dev/null 2>&1
  for f in "$FED" "$LEDGER" "$NODE" "$CHAINS"; do
    timeout 120 "$C" $BASE --kb "hub_$ch" consult "$f" >/dev/null 2>&1
  done
  member "$ch" "publish_rules($ch)" >/dev/null
  echo "   $ch sealed its own rules onto itself"
done

echo
echo "== the aggregator, which consulted none of them"
timeout 120 "$C" $BASE --kb hub_anchor forget >/dev/null 2>&1
for f in "$FED" "$LEDGER" "$NODE"; do
  timeout 120 "$C" $BASE --kb hub_anchor consult "$f" >/dev/null 2>&1
done
echo "   consulted: the federation's keys, a ledger node, an aggregator node."
echo "   NOT consulted: hub/chains.pl. It has never seen a rule for any chain."
for ch in $MEMBERS; do
  list=$(member "$ch" "ledger_export" | grep -a '^block(' | sed 's/\.$//' | paste -sd, -)
  [ -n "$list" ] && anchor "ledger_sync([$list])" >/dev/null
done
for ch in $MEMBERS; do anchor "learn_rules($ch)" >/dev/null; done
printf '   '
anchor "hub_report" | grep -a '^chains'
echo "   -- fenced first, installed second. A chain whose rules do not pass"
echo "      is simply one this node cannot verify, which is the right answer."

echo
echo "== judging a foreign block by the foreign chain's own rule"
member zeta "ledger_seal('a payload on zeta')" >/dev/null
list=$(member zeta "ledger_export" | grep -a '^block(' | sed 's/\.$//' | paste -sd, -)
anchor "ledger_sync([$list])" >/dev/null
printf '   the block zeta sealed: '
anchor "block(1,P,A,Pay,S,H), ( verify_foreign(zeta, block(1,P,A,Pay,S,H)) -> write(valid_on_zeta) ; write('REFUSED') ), nl" \
  | grep -aoE '^(valid_on_zeta|REFUSED)$'
printf '   the same block, one byte of payload changed: '
anchor "block(1,P,A,_,S,H), ( verify_foreign(zeta, block(1,P,A,'tampered',S,H)) -> write('VALID') ; write(refused) ), nl" \
  | grep -aoE '^(VALID|refused)$'

echo
echo "== two regimes, one host, opposite answers"
printf '   zeta prefers head  '
anchor "best_foreign(zeta,[head(9,aaa,10),head(4,bbb,90)],head(H,_,_)), format(\"~w (the longest)~n\",[H])" | grep -aE '^[0-9]+ \('
printf '   omega prefers head '
anchor "best_foreign(omega,[head(9,aaa,10),head(4,bbb,90)],head(H,_,_)), format(\"~w (the heaviest)~n\",[H])" | grep -aE '^[0-9]+ \('
echo "   -- same list, same host, same code. The difference is DATA."

echo
echo "== a checkpoint: one hash for the whole federation"
for ch in $MEMBERS; do
  h=$(member "$ch" "ledger_head(head(N,X,_)), format(\"~w ~w~n\",[N,X])" | grep -aE '^[0-9]+ [0-9a-f]{64}$' | head -1)
  n=$(echo "$h" | cut -d' ' -f1); x=$(echo "$h" | cut -d' ' -f2)
  anchor "assertz(member_head($ch,$n,'$x'))" >/dev/null
done
anchor "heads_report" | grep -a '^head' | sed 's/^/   /'
printf '   root: '
anchor "take_checkpoint(R), sub_atom(R,0,24,_,S), write(S), nl" | grep -aoE '^[0-9a-f]{24}$'
anchor "take_checkpoint(R), atom_concat('checkpoint:', R, P), ledger_seal(P)" >/dev/null
printf '   an inclusion proof for zeta alone: '
anchor "checkpoint_proof(zeta,I,L,Pa,R), ( merkle_verify(L,I,Pa,R) -> length(Pa,N), format(\"verifies with ~w sibling(s)~n\",[N]) ; write('BROKEN') )" \
  | grep -aE '^verifies|^BROKEN'
echo "   -- nobody had to be handed the whole federation to check one member."

echo
echo "== a bridge, waiting as a suspended machine"
anchor "assertz(bridge_open(never))" >/dev/null
timeout 120 "$C" $BASE --kb hub_anchor --steps 300 start bridge1 "bridge_wait(b1)" 2>&1 | tail -1 | sed 's/^/   /'
timeout 120 "$C" $BASE --kb hub_anchor --steps 300 step bridge1 2>&1 | tail -1 | sed 's/^/   /'
echo "   -- still frozen. It is three hundred bytes in a table, not a process."
printf '   a finality proof arrives from omega: '
anchor "( bridge_release(bridge(b1,omega,4,ok), proof(omega,4,ok,cert(70,100))) -> write(released) ; write('REFUSED') ), nl" \
  | grep -aoE '^(released|REFUSED)$'
timeout 120 "$C" $BASE --kb hub_anchor --steps 300 step bridge1 2>&1 | tail -1 | sed 's/^/   /'
timeout 120 "$C" $BASE --kb hub_anchor drop bridge1 2>&1 | tail -1 | sed 's/^/   /'
printf '   the same proof at a bridge naming zeta: '
anchor "( bridge_release(bridge(b2,zeta,4,ok), proof(omega,4,ok,cert(70,100))) -> write('RELEASED') ; write(refused) ), nl" \
  | grep -aoE '^(RELEASED|refused)$'

echo
echo "== cross-chain provenance is one query"
anchor "import(zeta, trained(d1,alice,0.99)), import(omega, paid(d1,carol,100))" >/dev/null
anchor "provenance_across(d1,Rows), forall(member(Ch-F,Rows), format(\"   ~w  ~w~n\",[Ch,F]))" | grep -a '^   '
echo "   -- no schema mapping and no adapter. Two facts that mention the same"
echo "      digest already agree about it; unification does the rest."

echo
echo "== mallory, against a host that runs code it did not write"
FILES="$FED $CHAINS $LEDGER $NODE $HERE/mallory.pl"
for a in attack_rules_read_key attack_rules_assert attack_rules_call attack_namespace_squat \
         attack_rules_swap attack_wrong_chain attack_anchor_swap attack_captured_chain; do
  printf '   %-24s ' "$a"
  timeout 300 "$C" run $FILES "$K, $a(V), write(V), nl" 2>/dev/null \
    | grep -aoE '^(refused|ACCEPTED)$' | head -1
done
echo "   -- the last one works, and it is the most important line in this rung."
echo "      psi's rules are impeccable: fenced, namespaced, real signature checks,"
echo "      the same two-thirds threshold rung 6 uses. And every psi validator is"
echo "      mallory. The host verified correctly, under the correct rules, and"
echo "      answered the question it was asked -- which was 'is this final ON PSI',"
echo "      not 'is psi honest'. An aggregator cannot be stronger than the chains"
echo "      it aggregates, and that is the door every drained bridge went through."
