#!/bin/sh
# Rung 6: proof of stake and BFT votes, narrated.
#
# WHAT THIS ARRANGEMENT IS. Four validators -- alice, bob, carol and
# mallory -- each with its own knowledge base, which is its chain and its
# vote book. A validator is not a process that runs: it is a cocolog
# invocation that reads rows, casts one vote and exits. There is no round
# timer, no leader announcement and no daemon anywhere.
#
# THE TWO THINGS THIS RUNG ADDS to the ledger underneath it:
#
#   WHO MAY VOTE IS A QUERY. Rung 2's federation is a file handed to
#   every node. Here the roster answers only "whose key is this"; the
#   WEIGHT comes off the chain, sealed as ordinary blocks and read back
#   by `stake_from_chain/0'. One invocation seals, a different one reads
#   -- so the validator set is derived, not distributed.
#
#   A QUORUM MAKES A BLOCK FINAL. Rung 2's fork choice may revisit any
#   tip; a block with a precommit certificate is settled. The last act
#   here is a genuine fork in which the LONGER chain loses, because the
#   shorter one contains the finalised block and `extends_final/1' is
#   what makes that the end of the argument.
#
# What it walks through, in order:
#
#   1. STAKING: four ordinary blocks, sealed and gossiped;
#   2. READING THE STAKE BACK, on a node that sealed none of it;
#   3. THE DRAW, computed from chain state by two nodes independently;
#   4. A BLOCK IN TWO PHASES: prevote quorum, then precommit quorum,
#      then final -- with every vote re-verified by its receiver;
#   5. THE LOCK: mallory precommits one block and is refused the other;
#   6. FINALITY BEATS LENGTH: a longer fork that omits a finalised block
#      is not a candidate at all;
#   7. mallory's eight attacks, one of which works.
#
# Needs a Zigurat server: the four knowledge bases are the four
# validators, and the gossip is one process reading another's kb.
# SKIPs without one.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../test/config.sh"
C="$COCOLOG_BIN"

BASE="--host $ZIGURAT_HOST --port $ZIGURAT_PORT --timeout 60"
FED="$HERE/federation.pl"
LEDGER="$ROOT/ledger/node.pl"
NODE="$HERE/node.pl"
K="use_module(library(poa)), use_module(library(pos)), use_module(library(bft))"
WHO="alice bob carol mallory"

ALICE=1111111111111111111111111111111111111111111111111111111111111111
BOB=2222222222222222222222222222222222222222222222222222222222222222
CAROL=3333333333333333333333333333333333333333333333333333333333333333
MALLORY=4444444444444444444444444444444444444444444444444444444444444444

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi
if ! timeout 20 "$C" $BASE --kb votes_alice list >/dev/null 2>&1; then
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT"; exit 0
fi

key_of() {
  case "$1" in
    alice) echo "$ALICE" ;; bob) echo "$BOB" ;;
    carol) echo "$CAROL" ;; mallory) echo "$MALLORY" ;;
  esac
}

# A validator's turn at the machine: its own kb, its own name, its own
# key. The key travels in the ENVIRONMENT and never through a file -- a
# consulted file becomes clauses and clauses become rows, and a private
# key in the database is a private key published to every reader.
node() {
  who=$1; shift
  NODE_NAME="$who" NODE_KEY="$(key_of "$who")" \
    timeout 120 "$C" $BASE --kb "votes_$who" query "$K, $*" 2>/dev/null
}

blocks_of() { node "$1" "ledger_export" | grep -a '^block(' | sed 's/\.$//'; }
votes_of()  { node "$1" "votes_export"  | grep -a '^vote('  | sed 's/\.$//'; }

# Who a node hears from is an ARGUMENT, because a partition is exactly
# "these nodes can hear each other and that one cannot". The fork below
# is not simulated with a flag; it is what happens when the gossip list
# is short for a while.
gossip_blocks_from() {
  me=$1; shift
  for peer in "$@"; do
    [ "$peer" = "$me" ] && continue
    list=$(blocks_of "$peer" | paste -sd, -)
    [ -z "$list" ] && continue
    node "$me" "ledger_sync([$list])" >/dev/null
  done
}

gossip_blocks() { me=$1; gossip_blocks_from "$me" $WHO; }

gossip_votes() {
  me=$1
  for peer in $WHO; do
    [ "$peer" = "$me" ] && continue
    list=$(votes_of "$peer" | paste -sd, -)
    [ -z "$list" ] && continue
    node "$me" "votes_sync([$list])" >/dev/null
  done
}

echo "== a fresh federation with nothing staked"
for who in $WHO; do
  timeout 120 "$C" $BASE --kb "votes_$who" forget >/dev/null 2>&1
  for f in "$FED" "$LEDGER" "$NODE"; do
    timeout 120 "$C" $BASE --kb "votes_$who" consult "$f" >/dev/null 2>&1
  done
done
echo "   four knowledge bases, one roster of keys, no stake anywhere"

echo
echo "== staking: four ordinary blocks"
for e in "stake(alice,40)" "stake(bob,25)" "stake(carol,20)" "stake(mallory,15)"; do
  node alice "ledger_seal('$e')" >/dev/null
  echo "   alice sealed $e"
done
for who in $WHO; do gossip_blocks "$who"; done
echo "   -- gossiped. Every node now HOLDS the entries; none has read them."

echo
echo "== who may vote: a query over rows, on a node that sealed none of it"
for who in $WHO; do node "$who" "stake_from_chain" >/dev/null; done
node bob "stake_report" | grep -a '^stake'
printf '   '
node carol "votes_report" | grep -a '^validators'
echo "   -- bob and carol never saw a roster of weights. They read the chain."

echo
echo "== whose turn: the draw, from chain state alone"
for h in 1 2 3 4 5; do
  a=$(node alice   "leader_at($h,W), write(W), nl" | grep -aoE '^(alice|bob|carol|mallory)$' | head -1)
  m=$(node mallory "leader_at($h,W), write(W), nl" | grep -aoE '^(alice|bob|carol|mallory)$' | head -1)
  if [ "$a" = "$m" ]; then agree="both agree"; else agree="DISAGREE ($a vs $m)"; fi
  printf '   height %s  leader %-8s %s\n' "$h" "$a" "$agree"
done

echo
echo "== a partition: two blocks at one height, neither node aware"
H=$(node alice "ledger_head(head(X,_,_)), Y is X+1, write(Y), nl" | grep -aoE '^[0-9]+$' | head -1)
L=$(node alice "leader_at($H,W), write(W), nl" | grep -aoE '^(alice|bob|carol|mallory)$' | head -1)
FORKER=mallory
[ "$L" = "mallory" ] && FORKER=carol
HONEST=$(for w in $WHO; do [ "$w" = "$FORKER" ] || printf '%s ' "$w"; done)
echo "   height $H, the draw says $L proposes"
node "$L" "ledger_seal('the block at height $H')" >/dev/null
node "$FORKER" "ledger_seal('$FORKER forks here')" >/dev/null
echo "   $FORKER, who has not heard $L, seals her own at height $H"
for who in $HONEST; do gossip_blocks_from "$who" $HONEST; done
B=$(node alice "ledger_head(head($H,X,_)), write(X), nl" | grep -aoE '^[0-9a-f]{64}$' | head -1)

echo
echo "== a block, in two phases"
printf '   proposal %s\n' "$(echo "$B" | cut -c1-16)..."
printf '   every validator checks the PROPOSER before voting: '
node bob "( proposal_ok($H,'$B') -> write(drawn_leader) ; write('NOT_THE_LEADER') ), nl" \
  | grep -aoE '^(drawn_leader|NOT_THE_LEADER)$'

echo "   -- prevote"
for who in $HONEST; do node "$who" "prevote_block($H,0,'$B')" >/dev/null; done
for who in $HONEST; do gossip_votes "$who"; done
printf '   alice verifies the prevote quorum: '
node alice "( learn_pol($H,0,'$B') -> write(polka) ; write('SHORT') ), nl" | grep -aoE '^(polka|SHORT)$'

echo "   -- precommit (the vote and the lock, in one goal)"
for who in $HONEST; do node "$who" "do_precommit($H,0,'$B')" >/dev/null; done
for who in $HONEST; do gossip_votes "$who"; done
printf '   the certificate weighs: '
node alice "gather(precommit,$H,0,'$B',qc(_,_,_,_,Vs)), qc_stake(Vs,S), total_stake(T), quorum(T,Q), format(\"~w of ~w, quorum ~w~n\",[S,T,Q])" \
  | grep -aE '^[0-9]+ of '
printf '   finalising: '
node alice "( finalize($H,0,'$B') -> write(final) ; write('NOT_FINAL') ), nl" | grep -aoE '^(final|NOT_FINAL)$'

echo
echo "== finality beats length"
# Nothing $FORKER does here is invalid. Her blocks are signed, well
# formed, correctly parented and gossiped like anyone's. They simply do
# not contain the finalised one, and no amount of growing changes that.
for p in "and it grows" "and grows" "and grows again"; do
  node "$FORKER" "ledger_seal('$p')" >/dev/null
done
gossip_blocks alice
printf '   alice now holds both tips. Fork choice alone prefers height: '
node alice "ledger_head(head(X,_,_)), write(X), nl" | grep -aoE '^[0-9]+$'
printf '   the finalised block is at height:                          '
node alice "final_head(X,_), write(X), nl" | grep -aoE '^[0-9]+$'
printf '   does the LONGER tip contain the finalised block?  '
node alice "ledger_head(head(_,T,_)), ( extends_final(T) -> write(yes) ; write('no') ), nl" | grep -aoE '^(yes|no)$'
printf '   does the FINALISED tip?                           '
node alice "final_head(_,T), ( extends_final(T) -> write(yes) ; write('no') ), nl" | grep -aoE '^(yes|no)$'
echo "   -- a chain that omits a finalised block is not a candidate, at any"
echo "      length. That is the whole of what a quorum buys over a fork rule."

echo
echo "== the lock: $FORKER precommits one block, then wants another"
node "$FORKER" "do_precommit($H,0,'$B')" >/dev/null
FAKE=cccc000000000000000000000000000000000000000000000000000000000000
printf '   same block, later round:  '
node "$FORKER" "( do_precommit($H,1,'$B') -> write(allowed) ; write(refused) ), nl" | grep -aoE '^(allowed|refused)$'
printf '   a different block, no POL: '
node "$FORKER" "( do_precommit($H,1,'$FAKE') -> write('ALLOWED') ; write(refused) ), nl" | grep -aoE '^(ALLOWED|refused)$'
echo "   -- and she is bound by a row written in the same turn as the vote."

echo
echo "== mallory, from inside the validator set"
FILES="$FED $LEDGER $NODE $HERE/mallory.pl"
for a in attack_no_stake attack_stuff_quorum attack_forge_vote attack_replay_phase \
         attack_equivocate attack_unlock attack_double_qc attack_grind; do
  printf '   %-20s ' "$a"
  timeout 300 "$C" run $FILES "$K, $a(V), write(V), nl" 2>/dev/null \
    | grep -aoE '^(refused|ACCEPTED)$' | head -1
done
printf '   %-20s ' "and it cost her"
timeout 300 "$C" run $FILES "$K, grind_cost(N), format(\"~w payloads~n\",[N])" 2>/dev/null \
  | grep -aE '^[0-9]+ payloads$'
printf '   %-20s ' "two certificates name"
timeout 300 "$C" run $FILES "$K, double_qc_culprits(Ns,S), total_stake(T), fault_bound(T,F), format(\"~w, weighing ~w against a bound of ~w~n\",[Ns,S,F])" 2>/dev/null \
  | grep -aE '^\['
echo "   -- the grind works and is supposed to: a draw seeded by chain state"
echo "      is biasable by whoever makes the state. Inside a certificate-gated"
echo "      federation that is the price of a schedule anyone can recompute."
