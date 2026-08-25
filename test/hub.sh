#!/bin/sh
# Rung 7: the aggregator -- many chains, one node, none of them known in
# advance.
#
# WHAT IT IS CHECKING.
#
#   A CHAIN CARRIES ITS OWN LIGHT CLIENT. Every rule the host uses to
#   judge a foreign chain is read off that chain as a block payload. The
#   checks below install two chains under regimes that flatly disagree --
#   one prefers the longest head, the other the heaviest -- and get
#   opposite answers from the same host with the same code, because the
#   difference between the two chains is DATA.
#
#   FOREIGN RULES ARE UNTRUSTED CODE, and rung 3 already solved that.
#   `rules_admit/3' is `contract_admit/3' with one rule added, and the
#   fence's vocabulary fits a validity rule without alteration -- which
#   is not luck: a validity rule and a contract are the same kind of
#   thing, a function of the chain.
#
#   THE ONE ADDED RULE IS A NAMESPACE. A contract is alone in its own
#   state; a chain is not. Without it two chains would both define
#   `valid/1' and the second would answer for the first.
#
#   AND ONE ATTACK SUCCEEDS. If mallory owns every validator on her own
#   chain, the host verifies her block correctly, under her chain's
#   correct rules, and accepts it -- because the question it was asked
#   was "is this final on psi", not "is psi honest". An aggregator cannot
#   be stronger than the chains it aggregates.
#
# No server: every rule here is a function of its arguments. The
# cross-process half -- rules sealed on one chain and read back on
# another node, and a bridge as a suspended machine -- is hub/run.sh.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"
F="$ROOT/hub/chains.pl $ROOT/ledger/node.pl $ROOT/hub/node.pl $ROOT/hub/mallory.pl"
K="use_module(library(hub)), use_module(library(contract))"

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
ALICE=1111111111111111111111111111111111111111111111111111111111111111

# ---- rules are entries -----------------------------------------------
echo "-- a chain publishes its own rules, and they survive a round trip"
# The clauses come back as a VARIANT -- same structure, fresh variables --
# because a clause's variables are local to the clause and a payload is
# text. So the check that matters is not `=='"'"' on the term: it is that the
# round-tripped rules still DO their job. These are installed from the
# payload and then asked about a real signed block.
check "the chain name survives the round trip" \
  "$(q "chain_source(zeta,Cs), rules_payload(zeta,Cs,P), rules_of_payload(P,Ch,_), write(Ch), nl" '^[a-z]+$')" \
  "zeta"
check "so does every clause" \
  "$(q "chain_source(zeta,Cs), rules_payload(zeta,Cs,P), rules_of_payload(P,_,Cs2), length(Cs,A), length(Cs2,B), (A == B -> write(A) ; write('LOST')), nl" '^([0-9]+|LOST)$')" \
  "6"
check "and the rules still work when installed FROM the payload" \
  "$(q "chain_source(zeta,Cs), rules_payload(zeta,Cs,P), rules_of_payload(P,_,Cs2), rules_admit(zeta,Cs2,admitted), contract_install(zeta,Cs2), block_hash(1,'p0',alice,'a payload',H), secp256k1_sign('$ALICE',H,S), ( verify_foreign(zeta, block(1,'p0',alice,'a payload',S,H)) -> write(valid) ; write('REFUSED')), nl" '^(valid|REFUSED)$')" \
  "valid"
check "a payload that is not rules is not mistaken for some" \
  "$(q "( rules_of_payload('just a payload', _, _) -> write('PARSED') ; write(skipped) ), nl" '^(PARSED|skipped)$')" \
  "skipped"

# ---- the fence, unchanged --------------------------------------------
echo
echo "-- the same fence contracts run under"
for ch in zeta omega psi; do
  check "$ch's published rules pass the fence" \
    "$(q "chain_source($ch,Cs), rules_admit($ch,Cs,V), write(V), nl" '^(admitted|refused)$')" \
    "admitted"
done
check "the vocabulary a validity rule needs is already in it" \
  "$(q "( allowed(block_hash/5), allowed(secp256k1_verify/3), allowed(sha256/2) -> write(fits) ; write('SHORT')), nl" '^(fits|SHORT)$')" \
  "fits"
check "and what it must not have is already out" \
  "$(q "( allowed(getenv/2) ; allowed(assertz/1) ; allowed(call/1) ) -> write('LEAKS') ; write(sealed), nl" '^(LEAKS|sealed)$')" \
  "sealed"

# ---- the namespace ---------------------------------------------------
echo
echo "-- one rule the contract fence never needed"
check "a chain may name its own predicates" \
  "$(q "( rules_scoped(zeta, zeta_valid(_)) -> write(scoped) ; write('REFUSED')), nl" '^(scoped|REFUSED)$')" \
  "scoped"
check "and may not name somebody else's" \
  "$(q "( rules_scoped(zeta, omega_valid(_)) -> write('SQUATTED') ; write(refused)), nl" '^(SQUATTED|refused)$')" \
  "refused"
check "a bare name is not in any chain's namespace" \
  "$(q "( rules_scoped(zeta, valid(_)) -> write('BARE') ; write(refused)), nl" '^(BARE|refused)$')" \
  "refused"

# ---- verifying under somebody else's rules ---------------------------
echo
echo "-- the host judges a foreign block by the foreign chain's rule"
SEAL="chain_source(zeta,Cs), rules_admit(zeta,Cs,admitted), contract_install(zeta,Cs),
      block_hash(1,'p0',alice,'a payload',H), secp256k1_sign('$ALICE',H,S)"
check "a block alice really signed is valid on zeta" \
  "$(q "$SEAL, ( verify_foreign(zeta, block(1,'p0',alice,'a payload',S,H)) -> write(valid) ; write('REFUSED')), nl" '^(valid|REFUSED)$')" \
  "valid"
check "the same block with the payload changed is not" \
  "$(q "$SEAL, ( verify_foreign(zeta, block(1,'p0',alice,'another payload',S,H)) -> write('VALID') ; write(refused)), nl" '^(VALID|refused)$')" \
  "refused"
check "and a block from someone not on zeta's roster is not" \
  "$(q "$SEAL, block_hash(1,'p0',dave,'a payload',H2), secp256k1_sign('$ALICE',H2,S2), ( verify_foreign(zeta, block(1,'p0',dave,'a payload',S2,H2)) -> write('VALID') ; write(refused)), nl" '^(VALID|refused)$')" \
  "refused"

# ---- two regimes, one host -------------------------------------------
echo
echo "-- two chains that disagree about what a better head is"
BOTH="chain_source(zeta,CZ), rules_admit(zeta,CZ,admitted), contract_install(zeta,CZ),
      chain_source(omega,CO), rules_admit(omega,CO,admitted), contract_install(omega,CO),
      Heads = [head(9,aaa,10), head(4,bbb,90)]"
check "zeta takes the longest head" \
  "$(q "$BOTH, best_foreign(zeta, Heads, head(H,_,_)), write(H), nl" '^[0-9]+$')" "9"
check "omega takes the heaviest, from the same list" \
  "$(q "$BOTH, best_foreign(omega, Heads, head(H,_,_)), write(H), nl" '^[0-9]+$')" "4"
check "both rule sets are installed in the one process" \
  "$(q "$BOTH, ( clause(zeta_better(_,_),_), clause(omega_better(_,_),_) -> write(both) ; write('ONE')), nl" '^(both|ONE)$')" \
  "both"

# ---- the rules are pinned to a height --------------------------------
echo
echo "-- new rules do not reach back over old blocks"
PIN="rules_payload(zeta,[zeta_a(1)],P1), rules_payload(zeta,[zeta_b(2)],P9),
     assertz(block(1,p0,alice,P1,s,h1)), assertz(block(9,p8,alice,P9,s,h9))"
check "a block at height 4 is judged by the height-1 rules" \
  "$(q "$PIN, rules_at(zeta,4,Cs), write(Cs), nl" '^\[.*\]$')" "[zeta_a(1)]"
check "a block at height 9 is judged by the height-9 rules" \
  "$(q "$PIN, rules_at(zeta,9,Cs), write(Cs), nl" '^\[.*\]$')" "[zeta_b(2)]"
check "and the latest is what a new block gets" \
  "$(q "$PIN, latest_rules(zeta,Cs), write(Cs), nl" '^\[.*\]$')" "[zeta_b(2)]"

# ---- the anchor chain ------------------------------------------------
echo
echo "-- one hash for the whole federation, with proofs"
LEAVES="checkpoint_leaf(zeta,4,aaaa,L1), checkpoint_leaf(omega,7,bbbb,L2),
        checkpoint_leaf(psi,2,cccc,L3), checkpoint_leaf(tau,5,dddd,L4),
        Ls = [L1,L2,L3,L4], merkle_root(Ls,Root)"
check "one member is a root of itself" \
  "$(q "checkpoint_leaf(zeta,4,aaaa,L), merkle_root([L],R), (R == L -> write(itself) ; write('MOVED')), nl" '^(itself|MOVED)$')" \
  "itself"
check "an inclusion proof verifies for every member" \
  "$(q "$LEAVES, ( forall(between(0,3,I), (nth0(I,Ls,Lf), merkle_path(Ls,I,Pa), merkle_verify(Lf,I,Pa,Root))) -> write(all_prove) ; write('BROKEN')), nl" '^(all_prove|BROKEN)$')" \
  "all_prove"
check "an odd federation proves too" \
  "$(q "checkpoint_leaf(zeta,4,aaaa,A), checkpoint_leaf(omega,7,bbbb,B), checkpoint_leaf(psi,2,cccc,Cc), Ls=[A,B,Cc], merkle_root(Ls,R), ( forall(between(0,2,I), (nth0(I,Ls,Lf), merkle_path(Ls,I,Pa), merkle_verify(Lf,I,Pa,R))) -> write(all_prove) ; write('BROKEN')), nl" '^(all_prove|BROKEN)$')" \
  "all_prove"
check "moving any member changes the root" \
  "$(q "$LEAVES, checkpoint_leaf(zeta,40,aaaa,M), merkle_root([M,L2,L3,L4],R2), (R2 == Root -> write('SAME') ; write(changed)), nl" '^(SAME|changed)$')" \
  "changed"
check "a checkpoint names its chain, so it cannot be moved sideways" \
  "$(q "checkpoint_leaf(zeta,4,aaaa,A), checkpoint_leaf(omega,4,aaaa,B), (A == B -> write('COLLIDE') ; write(distinct)), nl" '^(COLLIDE|distinct)$')" \
  "distinct"

# ---- the bridge ------------------------------------------------------
echo
echo "-- a bridge thaws on a proof, and only the right one"
check "the right chain, height and block thaw it" \
  "$(q "( bridge_ready(bridge(b1,zeta,12,aaaa), proof(zeta,12,aaaa,cert), verify_always) -> write(thawed) ; write('SHUT')), nl" '^(thawed|SHUT)$')" \
  "thawed"
check "the wrong chain does not" \
  "$(q "( bridge_ready(bridge(b1,omega,12,aaaa), proof(zeta,12,aaaa,cert), verify_always) -> write('THAWED') ; write(shut)), nl" '^(THAWED|shut)$')" \
  "shut"
check "the wrong height does not" \
  "$(q "( bridge_ready(bridge(b1,zeta,13,aaaa), proof(zeta,12,aaaa,cert), verify_always) -> write('THAWED') ; write(shut)), nl" '^(THAWED|shut)$')" \
  "shut"
check "and a verifier that says no does not" \
  "$(q "( bridge_ready(bridge(b1,zeta,12,aaaa), proof(zeta,12,aaaa,cert), verify_never) -> write('THAWED') ; write(shut)), nl" '^(THAWED|shut)$')" \
  "shut"

# ---- the join --------------------------------------------------------
echo
echo "-- cross-chain provenance is one query"
IMP="import(zeta, trained(d1,alice,0.99)), import(omega, paid(d1,carol,100)),
     import(psi, unrelated(d2,mallory,7))"
check "a digest on two chains joins on itself" \
  "$(q "$IMP, provenance_across(d1,Rows), length(Rows,N), write(N), nl" '^[0-9]+$')" "2"
check "and it names which chain each row came from" \
  "$(q "$IMP, provenance_across(d1,Rows), msort(Rows,S), findall(C,member(C-_,S),Cs), write(Cs), nl" '^\[.*\]$')" \
  "[omega,zeta]"
check "something on one chain only joins to one row" \
  "$(q "$IMP, provenance_across(d2,Rows), length(Rows,N), write(N), nl" '^[0-9]+$')" "1"

# ---- mallory ---------------------------------------------------------
echo
echo "-- mallory against a host that runs code it did not write"
V='^(refused|ACCEPTED)$'
check "rules that read the host's signing key" \
  "$(q "attack_rules_read_key(V), write(V), nl" "$V")" "refused"
check "rules that write onto the host" \
  "$(q "attack_rules_assert(V), write(V), nl" "$V")" "refused"
check "rules that build a goal at run time" \
  "$(q "attack_rules_call(V), write(V), nl" "$V")" "refused"
check "publishing rules for somebody else's chain" \
  "$(q "attack_namespace_squat(V), write(V), nl" "$V")" "refused"
check "new rules applied to old blocks" \
  "$(q "attack_rules_swap(V), write(V), nl" "$V")" "refused"
check "a real finality proof at the wrong bridge" \
  "$(q "attack_wrong_chain(V), write(V), nl" "$V")" "refused"
check "moving a head after the checkpoint" \
  "$(q "attack_anchor_swap(V), write(V), nl" "$V")" "refused"
check "owning the chain -- SUCCEEDS, and must" \
  "$(q "attack_captured_chain(V), write(V), nl" "$V")" "ACCEPTED"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
