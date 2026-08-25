#!/bin/sh
# Rung 2: the PoA federation ledger, and mallory attacking it.
#
# WHAT IT IS CHECKING, in three parts.
#
#   THE CHAIN WORKS. Three authorities on three knowledge bases seal in
#   turn, gossip, and every one of them ends on the same head with a
#   clean audit -- where an audit means every hash recomputed, every
#   signature re-checked and every parent link walked back to genesis,
#   by a process that was told nothing.
#
#   THE FORK CLOSES BY RULE. Two authorities seal at the same height
#   while neither has heard the other, which is what a partition looks
#   like from inside. Both chains are valid and the same length. Every
#   node must land on the same one, and must land on it because the rule
#   prefers the in-turn block -- not because of arrival order, which is
#   exactly what differs between them.
#
#   MALLORY GETS NOTHING. Seven attacks on the five laws the chain has,
#   each refused, plus one that SUCCEEDS and is supposed to. A test
#   suite that reported every attack refused would be lying, and the one
#   that gets through is the one worth understanding: ECDSA signatures
#   are malleable by anyone, so she can produce a different signature for
#   alice's block -- and it buys her nothing, because the block's hash
#   does not cover the signature. Bitcoin's did, and that was
#   transaction malleability.
#
#   AND ONE ATTACK COMES FROM INSIDE. A member of the federation can seal
#   a valid block that rewrites history, and nothing refuses it -- it is
#   properly signed by a real authority. It is not REFUSED, it is
#   OUTWEIGHED, and the distinction is the whole difference between
#   validity and consensus.
#
# SKIPs without a Zigurat server: the three nodes are three knowledge
# bases and the gossip is one process reading another's.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

BASE="--host $ZIGURAT_HOST --port $ZIGURAT_PORT --timeout 30"
LED="$ROOT/ledger"
FED="$LED/federation.pl"
NODE="$LED/node.pl"
MAL="$LED/mallory.pl"

ALICE=1111111111111111111111111111111111111111111111111111111111111111
BOB=2222222222222222222222222222222222222222222222222222222222222222
CAROL=3333333333333333333333333333333333333333333333333333333333333333

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-50s %s\n' "$1" "$(echo "$2" | cut -c1-20)"
  else
    printf 'FAIL %-50s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi
if ! timeout 20 "$C" $BASE --kb ledger_alice list >/dev/null 2>&1; then
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT"
  exit 0
fi

key_of() {
  case "$1" in alice) echo "$ALICE" ;; bob) echo "$BOB" ;; carol) echo "$CAROL" ;; esac
}

# EVERY PATTERN HERE IS ANCHORED. cocolog echoes the goal it ran, and a
# goal containing `write(yes) ; write(no)' would match an unanchored
# search for either word -- which is a way to make a test agree with
# whatever you hoped. `^...$' cannot match the echo line, because the
# echo line is the whole goal.
q() { timeout 90 "$C" "$@" 2>/dev/null | grep -aoE "$PAT" | head -1; }

node() {
  who=$1; shift
  NODE_NAME="$who" NODE_KEY="$(key_of "$who")" \
    timeout 90 "$C" $BASE --kb "ledger_$who" \
      query "use_module(library(poa)), $*" 2>/dev/null
}

# ---- part one: mallory, in one local process -------------------------
# No server needed for these: they are about the RULES, and the rules are
# clauses. An attack that a node would refuse is an attack `valid_block/6'
# refuses, and running them locally makes that plain.
echo "-- mallory attacks the laws"
attack() {
  got=$( timeout 90 "$C" run "$FED" "$NODE" "$MAL" "$1(V), write(V), nl" 2>/dev/null \
           | grep -aoE '^(refused|ACCEPTED)$' | head -1 )
  check "$2" "$got" "$3"
}
attack attack_not_a_member     "not a member of the federation"       refused
attack attack_impersonate      "alice's name, mallory's key"          refused
attack attack_tamper           "a sealed block's payload changed"     refused
attack attack_forged_hash      "a hash the block does not have"       refused
attack attack_replay_signature "a real signature on another block"    refused
attack attack_wrong_parent     "a real block re-pointed at a parent"  refused
attack attack_orphan           "a block whose parent is missing"      refused

# The one that works, and the reason it does not matter.
attack attack_malleate         "the malleated twin verifies"          ACCEPTED
PAT='^(same_block_identity|DIFFERENT)$'
check "and is the same block, so it gains nothing" \
  "$(q run "$FED" "$NODE" "$MAL" \
       "honest_block(block(H,Pv,A,P,Sg,Hs)), malleate(Sg,_), block_hash(H,Pv,A,P,H2), (H2 == Hs -> write(same_block_identity) ; write('DIFFERENT')), nl")" \
  "same_block_identity"

# ---- part two: the chain runs ----------------------------------------
echo
echo "-- three authorities, sealing in turn"
for who in alice bob carol; do
  timeout 90 "$C" $BASE --kb "ledger_$who" forget >/dev/null 2>&1
  timeout 90 "$C" $BASE --kb "ledger_$who" consult "$FED" >/dev/null 2>&1
  timeout 90 "$C" $BASE --kb "ledger_$who" consult "$NODE" >/dev/null 2>&1
done

blocks_of() { node "$1" "ledger_export" | grep -a '^block(' | sed 's/\.$//'; }
gossip() {
  me=$1
  for peer in alice bob carol; do
    [ "$peer" = "$me" ] && continue
    list=$(blocks_of "$peer" | paste -sd, -)
    [ -z "$list" ] && continue
    node "$me" "ledger_sync([$list])" >/dev/null
  done
}
head_of() { node "$1" "ledger_head(head(H,Hs,_)), format(\"~w ~w~n\",[H,Hs])" \
              | grep -aoE '^[0-9-]+ [0-9a-f]{64}$' | head -1; }
audit_of() { node "$1" "ledger_audit(S), write(S), nl" | grep -aoE '^(ok|broken)$' | head -1; }

node alice "ledger_seal('the genesis of the federation')" >/dev/null
for w in alice bob carol; do gossip "$w"; done
node bob   "ledger_seal('the second')" >/dev/null
for w in alice bob carol; do gossip "$w"; done
node carol "ledger_seal('the third')" >/dev/null
for w in alice bob carol; do gossip "$w"; done

A=$(head_of alice); B=$(head_of bob); D=$(head_of carol)
check "alice, bob and carol agree on the head" \
  "$( [ "$A" = "$B" ] && [ "$B" = "$D" ] && echo agree || echo "differ [$A][$B][$D]" )" "agree"
check "and the head is at height 2" "$(echo "$A" | cut -d' ' -f1)" "2"
for w in alice bob carol; do check "$w audits its whole chain" "$(audit_of "$w")" "ok"; done

# ---- part three: the fork --------------------------------------------
echo
echo "-- a fork, and the rule that closes it"
# alice is in turn at height 3; carol is not. Neither has heard the other,
# which is what a partition is.
node alice "ledger_seal('alice, in turn')" >/dev/null
node carol "ledger_seal('carol, out of turn')" >/dev/null
FA=$(head_of alice); FC=$(head_of carol)
check "before gossip the two nodes disagree" \
  "$( [ "$FA" != "$FC" ] && echo disagree || echo same )" "disagree"

for w in alice bob carol; do gossip "$w"; done
GA=$(head_of alice); GB=$(head_of bob); GC=$(head_of carol)
check "after gossip all three agree again" \
  "$( [ "$GA" = "$GB" ] && [ "$GB" = "$GC" ] && echo agree || echo "differ [$GA][$GB][$GC]" )" "agree"
check "and they agreed on the IN-TURN block, not the first seen" "$GA" "$FA"
for w in alice bob carol; do check "$w still audits clean after the reorg" "$(audit_of "$w")" "ok"; done

# ---- part four: the attack from inside --------------------------------
echo
echo "-- a member of the federation rewrites history"
# carol is a real authority with a real key. She seals a valid block at a
# height already settled. Nothing REFUSES it -- it is properly signed by
# somebody entitled to sign. It simply weighs less, and fork choice is
# where that is spent.
BEFORE=$(head_of alice)
node carol "genesis_prev(G), seal('$CAROL', 0, G, carol, 'a history I prefer', S, H), assertz(block(0,G,carol,'a history I prefer',S,H)), assertz(head_mark(0,H))" >/dev/null
for w in alice bob carol; do gossip "$w"; done
AFTER=$(head_of alice)
check "the rewritten block is VALID (a member signed it)" \
  "$( timeout 90 "$C" run "$FED" "$NODE" "$MAL" \
        "genesis_prev(G), seal('$CAROL',0,G,carol,'a history I prefer',S,H), (valid_block(0,G,carol,'a history I prefer',S,H) -> write(valid) ; write(refused)), nl" 2>/dev/null \
        | grep -aoE '^(valid|refused)$' | head -1 )" "valid"
check "and it is outweighed, not refused: the head does not move" "$AFTER" "$BEFORE"
check "the chain still audits after the attempt" "$(audit_of alice)" "ok"

# ---- part five: across processes -------------------------------------
echo
echo "-- and an auditor that consulted nothing"
# A process that never saw federation.pl or node.pl, reading the chain
# out of the knowledge base and checking it under rules it loads itself.
# This is the Zeytun reader's position: no write path, no prior state,
# and still able to say whether the chain is sound.
# The count is NOT asserted: alice holds the three settled blocks, both
# candidates from the fork, and carol's rewrite -- six, and that number
# moves whenever the choreography above changes. What must hold is that
# EVERY block she kept verifies, including the ones fork choice rejected.
# A node stores losing blocks; it must never store invalid ones.
PAT='^(all_verified|SOME_INVALID)$'
check "a fresh process re-verifies every block it finds" \
  "$(q $BASE --kb ledger_alice query \
      "use_module(library(poa)), ( forall(block(H,Pv,A,P,S,Hs), valid_block(H,Pv,A,P,S,Hs)) -> write(all_verified) ; write('SOME_INVALID') ), nl")" \
  "all_verified"
PAT='^[0-9]+ blocks$'
check "and it found the losing fork branches too, not just the head" \
  "$(q $BASE --kb ledger_alice query \
      "use_module(library(poa)), findall(1, block(_,_,_,_,_,_), L), length(L,N), ( N > 3 -> format(\"~w blocks~n\",[N]) ; true )")" \
  "6 blocks"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
