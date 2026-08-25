#!/bin/sh
# Rung 6: proof of stake and BFT votes.
#
# WHAT IT IS CHECKING.
#
#   STAKE IS A QUERY, NOT A ROSTER. Rung 2's federation is a file handed
#   to every node; a validator's weight here is read off blocks the node
#   already holds. The first checks seal nothing and trust nothing --
#   they put payloads on a chain and ask the stake rule what it makes of
#   them, including a payload that is not a stake entry at all.
#
#   A QUORUM IS COUNTED BY WEIGHT. Two validators out of four can be
#   short and three can be enough; a head count would get both wrong.
#   And one validator's vote repeated four times is the cheapest attack
#   in the rung, so the rule requires as many distinct voters as votes.
#
#   THE ARITHMETIC IS THE SAFETY ARGUMENT. With quorum = 2T/3 + 1, two
#   certificates at one height must share more than T/3 of the stake.
#   `culprits/3' is that intersection, and the suite checks it is
#   heavier than the fault bound rather than merely non-empty.
#
#   MALLORY IS AN INSIDER. Every earlier rung's criminal was a stranger.
#   She holds real stake and votes on every block, which is what a
#   Byzantine fault IS -- and one of her eight attacks succeeds, because
#   a hash-seeded draw is grindable and saying otherwise would be a lie.
#
# No server: every rule here is a function of its arguments, so the whole
# file runs in `run'. The cross-process half -- stake sealed by one
# invocation and read back by another, and finality beating length across
# two knowledge bases -- is votes/run.sh.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"
F="$ROOT/votes/federation.pl $ROOT/ledger/node.pl $ROOT/votes/node.pl $ROOT/votes/mallory.pl"
K="use_module(library(pos)), use_module(library(bft))"

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-52s %s\n' "$1" "$(echo "$2" | cut -c1-20)"
  else
    printf 'FAIL %-52s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi

q() { timeout 300 "$C" run $F "$K, $1" 2>/dev/null | grep -aoE "$2" | head -1; }

# A chain with the stake entries on it, and one payload that is not one.
# The signatures are not checked by `stake_from_chain/0' and must not be:
# a block only reaches a node's store through `ledger_seal/1' or
# `ledger_sync/1', and both have verified it already. Re-verifying here
# would be a second answer to a question already answered.
CHAIN="assertz(block(0,p,alice,'stake(alice,40)',s,h0)),
       assertz(block(1,h0,alice,'stake(bob,25)',s,h1)),
       assertz(block(2,h1,alice,'stake(carol,20)',s,h2)),
       assertz(block(3,h2,alice,'stake(mallory,15)',s,h3)),
       assertz(block(4,h3,alice,'a payload that is not a stake entry',s,h4)),
       stake_from_chain"

# ---- stake is a query over the chain ---------------------------------
echo "-- the validator set, derived from blocks"
check "four validators come off the chain" \
  "$(q "$CHAIN, validators(V), length(V,N), write(N), nl" '^[0-9]+$')" "4"
check "and they are the ones that staked" \
  "$(q "$CHAIN, validators(V), write(V), nl" '^\[[a-z,]+\]$')" "[alice,bob,carol,mallory]"
check "the weights are the ones on the chain" \
  "$(q "$CHAIN, stake_table(T), write(T), nl" '^\[.*\]$')" \
  "[alice-40,bob-25,carol-20,mallory-15]"
check "a payload that is not a stake entry is skipped" \
  "$(q "$CHAIN, total_stake(T), write(T), nl" '^[0-9]+$')" "100"
check "dave is in the federation and is not a validator" \
  "$(q "$CHAIN, (has_stake(dave) -> write('VOTES') ; write(no_stake)), nl" '^(VOTES|no_stake)$')" \
  "no_stake"

# ---- the thresholds ---------------------------------------------------
echo
echo "-- counted by weight, never by head"
check "quorum of 100 is 67" \
  "$(q "quorum(100,Q), write(Q), nl" '^[0-9]+$')" "67"
check "fault bound of 100 is 33" \
  "$(q "fault_bound(100,F), write(F), nl" '^[0-9]+$')" "33"
check "two of four validators can be short (alice+mallory = 55)" \
  "$(q "$CHAIN, block_a(B), alice_key(KA), mallory_key(KM), cast(KA,precommit,1,0,B,SA), cast(KM,precommit,1,0,B,SM), (qc_valid(qc(precommit,1,0,B,[vote(precommit,1,0,B,alice,SA),vote(precommit,1,0,B,mallory,SM)])) -> write('QUORUM') ; write(short)), nl" '^(QUORUM|short)$')" \
  "short"
check "three of four are enough (alice+bob+carol = 85)" \
  "$(q "$CHAIN, block_a(B), alice_key(KA), bob_key(KB), carol_key(KC), cast(KA,precommit,1,0,B,SA), cast(KB,precommit,1,0,B,SB), cast(KC,precommit,1,0,B,SC), (qc_valid(qc(precommit,1,0,B,[vote(precommit,1,0,B,alice,SA),vote(precommit,1,0,B,bob,SB),vote(precommit,1,0,B,carol,SC)])) -> write(quorum) ; write('SHORT')), nl" '^(quorum|SHORT)$')" \
  "quorum"
check "dave's signature is good; his vote still is not" \
  "$(q "$CHAIN, dave_key(K), block_a(B), cast(K,prevote,1,0,B,S), vote_hash(prevote,1,0,B,H), authority(dave,P), (secp256k1_verify(H,S,P) -> (valid_vote(vote(prevote,1,0,B,dave,S)) -> write('COUNTED') ; write(signed_but_unstaked)) ; write('SIG_BAD')), nl" '^(COUNTED|signed_but_unstaked|SIG_BAD)$')" \
  "signed_but_unstaked"

# ---- the draw ---------------------------------------------------------
echo
echo "-- the leader draw: a function of chain state"
check "the same seed and height give the same leader" \
  "$(q "$CHAIN, leader(deadbeef,7,A), leader(deadbeef,7,B), (A == B -> write(deterministic) ; write('WANDERS')), nl" '^(deterministic|WANDERS)$')" \
  "deterministic"
check "every height draws somebody" \
  "$(q "$CHAIN, findall(W,(between(1,50,I), leader(deadbeef,I,W)),L), length(L,N), write(N), nl" '^[0-9]+$')" "50"
# 400 heights against 40/25/20/15: the ORDER is the claim, not the counts.
# Exact counts are a property of sha256 and would make this a test of the
# hash rather than of the draw.
check "the draw tracks stake: alice drawn most, mallory least" \
  "$(q "$CHAIN, findall(C-W, (member(W,[alice,bob,carol,mallory]), findall(1,(between(1,400,I), leader('0000000000000000000000000000000000000000000000000000000000000000',I,W)),L), length(L,C)), Ps), keysort(Ps,S), last(S,_-Top), S=[_-Bottom|_], format(\"~w ~w~n\",[Top,Bottom])" '^[a-z]+ [a-z]+$')" \
  "alice mallory"

# ---- the proposer ------------------------------------------------------
echo
echo "-- a voter checks who proposed, from the block's own parent"
# The leader is worked out from the block's PARENT hash, so the answer is
# the same on every node and stays the same forever. Both directions are
# checked against whoever the draw actually names, rather than against a
# name written down here -- a test that hardcodes the winner is a test of
# sha256.
check "a block from the drawn leader is prevotable" \
  "$(q "$CHAIN, leader(h4,5,W), assertz(block(5,h4,W,'a proposal',s,h5)), (proposal_ok(5,h5) -> write(ok) ; write('REFUSED')), nl" '^(ok|REFUSED)$')" \
  "ok"
check "a block from anyone else is not" \
  "$(q "$CHAIN, leader(h4,5,W), member(X,[alice,bob,carol,mallory]), X \\== W, assertz(block(5,h4,X,'a proposal',s,h5x)), (proposal_ok(5,h5x) -> write('ACCEPTED') ; write(refused)), nl" '^(ACCEPTED|refused)$')" \
  "refused"

# ---- finality ----------------------------------------------------------
echo
echo "-- finality beats length"
# Two chains from one parent: a finalised block at height 2, and a fork
# from the same parent that grows to height 4. Nothing about the longer
# chain is malformed -- it is simply not a candidate.
Z=0000000000000000000000000000000000000000000000000000000000000000
FORK="assertz(block(0,'$Z',alice,'stake(alice,40)',s,h0)),
      assertz(block(1,h0,alice,'stake(bob,25)',s,h1)),
      assertz(block(2,h1,alice,honest,s,hA)),
      assertz(block(2,h1,mallory,fork,s,hM)),
      assertz(block(3,hM,mallory,longer,s,hM3)),
      assertz(block(4,hM3,mallory,'longer still',s,hM4)),
      assertz(final(2,hA))"
check "the finalised tip is a candidate" \
  "$(q "$FORK, (extends_final(hA) -> write(candidate) ; write('REFUSED')), nl" '^(candidate|REFUSED)$')" \
  "candidate"
check "the longer tip that omits it is not" \
  "$(q "$FORK, (extends_final(hM4) -> write('CANDIDATE') ; write(refused)), nl" '^(CANDIDATE|refused)$')" \
  "refused"
check "and fork choice alone would have preferred the longer one" \
  "$(q "$FORK, chain_from(hM4,L1), length(L1,N1), chain_from(hA,L2), length(L2,N2), (N1 > N2 -> write(longer) ; write('NOT_LONGER')), nl" '^(longer|NOT_LONGER)$')" \
  "longer"

# ---- reading the stake twice -------------------------------------------
echo
echo "-- a block is counted once"
check "reading the chain twice does not double the stake" \
  "$(q "$CHAIN, stake_from_chain, stake_from_chain, total_stake(T), write(T), nl" '^[0-9]+$')" \
  "100"

# ---- the lock ---------------------------------------------------------
echo
echo "-- the lock, and the only thing that releases it"
check "an unlocked validator may precommit anything" \
  "$(q "block_a(A), (locked_ok(none,1,0,A,[]) -> write(free) ; write('BOUND')), nl" '^(free|BOUND)$')" "free"
check "a locked validator may repeat its own block" \
  "$(q "block_a(A), (locked_ok(lock(1,0,A),1,1,A,[]) -> write(same_block) ; write('REFUSED')), nl" '^(same_block|REFUSED)$')" \
  "same_block"
check "and may not move to another with no proof" \
  "$(q "block_a(A), block_b(B), (locked_ok(lock(1,0,A),1,1,B,[]) -> write('MOVED') ; write(bound)), nl" '^(MOVED|bound)$')" \
  "bound"
check "a later prevote quorum releases it" \
  "$(q "block_a(A), block_b(B), (locked_ok(lock(1,0,A),1,2,B,[pol(1,1,B)]) -> write(released) ; write('STUCK')), nl" '^(released|STUCK)$')" \
  "released"
check "an EARLIER quorum does not" \
  "$(q "block_a(A), block_b(B), (locked_ok(lock(1,5,A),1,6,B,[pol(1,2,B)]) -> write('MOVED') ; write(bound)), nl" '^(MOVED|bound)$')" \
  "bound"
check "a lock at one height does not bind the next" \
  "$(q "block_a(A), block_b(B), (locked_ok(lock(1,0,A),2,0,B,[]) -> write(free) ; write('BOUND')), nl" '^(free|BOUND)$')" \
  "free"

# ---- evidence ---------------------------------------------------------
echo
echo "-- the fault that proves itself"
check "equivocation names the validator and both documents" \
  "$(q "$CHAIN, block_a(A), block_b(B), mallory_key(K), cast(K,precommit,1,0,A,S1), cast(K,precommit,1,0,B,S2), (equivocation([vote(precommit,1,0,A,mallory,S1),vote(precommit,1,0,B,mallory,S2)],W,evidence(_,_)) -> write(W) ; write('UNSEEN')), nl" '^(alice|bob|carol|mallory|UNSEEN)$')" \
  "mallory"
check "an honest validator voting once is not equivocation" \
  "$(q "$CHAIN, block_a(A), alice_key(K), cast(K,precommit,1,0,A,S), (equivocation([vote(precommit,1,0,A,alice,S)],_,_) -> write('ACCUSED') ; write(clean)), nl" '^(ACCUSED|clean)$')" \
  "clean"
check "two certificates at one height name their culprits" \
  "$(q "double_qc_culprits(N,_), write(N), nl" '^\[[a-z,]+\]$')" "[alice,carol]"
check "and the culprits are heavier than the fault bound" \
  "$(q "$CHAIN, double_qc_culprits(_,H), total_stake(T), fault_bound(T,F), (H > F -> write(accountable) ; write('BELOW_BOUND')), nl" '^(accountable|BELOW_BOUND)$')" \
  "accountable"

# ---- mallory ----------------------------------------------------------
echo
echo "-- mallory, from inside the validator set"
V='^(refused|ACCEPTED)$'
check "voting with a key that never staked" \
  "$(q "attack_no_stake(V), write(V), nl" "$V")" "refused"
check "one vote repeated until it is a quorum" \
  "$(q "attack_stuff_quorum(V), write(V), nl" "$V")" "refused"
check "relabelling a signature as a vote for another block" \
  "$(q "attack_forge_vote(V), write(V), nl" "$V")" "refused"
check "presenting a prevote as a precommit" \
  "$(q "attack_replay_phase(V), write(V), nl" "$V")" "refused"
check "signing two blocks at one height" \
  "$(q "attack_equivocate(V), write(V), nl" "$V")" "refused"
check "voting away from a lock with no proof" \
  "$(q "attack_unlock(V), write(V), nl" "$V")" "refused"
check "two certificates, bought with a third of the stake" \
  "$(q "attack_double_qc(V), write(V), nl" "$V")" "refused"
check "grinding the leader draw -- SUCCEEDS, and must" \
  "$(q "attack_grind(V), write(V), nl" "$V")" "ACCEPTED"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
