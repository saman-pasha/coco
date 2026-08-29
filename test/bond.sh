#!/bin/sh
# THE STAKE IS THE COIN, and the evidence bites.
#
# Rung 6 built proof of stake and left one thing out, and said so: stake
# was a NUMBER read off a block -- a block said alice weighs 40, so alice
# weighed 40 -- and "nobody is SLASHED (the evidence is produced; burning
# a bond is a policy question)". The evidence was real; there was simply
# nothing to take. COCO is what there is to take, and this case is the
# join.
#
# WHAT IT IS CHECKING, in four parts.
#
#   A WEIGHT IS MONEY THAT CAN BE LOST. `stake_entry/2' -- the table
#   `library(pos)' asks for and refuses to own -- is now a RULE over
#   bonded coin, so `stake_of/2', `total_stake/1', `quorum/2' and the
#   leader draw all go on working with nothing changed, over numbers
#   somebody actually put up. Weight is whole COCO because the safety
#   arithmetic is integer arithmetic and money is u256; the consequence
#   is checked rather than hidden -- a bond under one coin weighs
#   nothing and is still slashable.
#
#   LEAVING IS SLOW, AND THAT IS THE POINT. An unbonding matures after
#   `coco_unbonding_delay/1' BLOCKS -- the chain's height is the only
#   clock here -- and the money is at risk the whole way. The check that
#   matters is the attack: equivocate, unbond everything in the same
#   breath, and the slash still lands.
#
#   WEIGHT FOLLOWS THE RISK, NOT THE REQUEST, and reading `library(bft)'
#   is what found it. `valid_vote/1' opens with `has_stake(Who)', so a
#   validator with no weight cannot cast a vote anybody will look at --
#   which means that if weight dropped when a validator ASKED for its
#   money back, unbonding would make the evidence against it unreadable
#   while the money was still there. Weight is `coco_at_risk/2' for
#   exactly that reason, and the case pins both halves.
#
#   AND A SLASH CANNOT BE FABRICATED. `culprits/3' intersects two lists
#   of NAMES and takes no position on whether either certificate is
#   real, so both are put through `qc_valid/1' before a name is read --
#   every signature, every vote matching its certificate, a quorum
#   behind each. Two made-up certificates rob nobody.
#
# SKIPs the chain half without a Zigurat server.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

BASE="$ZIGURAT_DIAL --timeout 30"
LED="$ROOT/ledger"
FILES="$LED/federation.pl $LED/node.pl $LED/gas.pl $ROOT/votes/bond.pl"

# The federation's own keys: a validator bonds from the key it votes
# with, which is the whole of "who does the work and who holds the bond
# are one key".
ALICE=1111111111111111111111111111111111111111111111111111111111111111
BOB=2222222222222222222222222222222222222222222222222222222222222222
CAROL=3333333333333333333333333333333333333333333333333333333333333333
ANN=5555555555555555555555555555555555555555555555555555555555555555

C400=400000000000000000000            # 400 COCO
C300=300000000000000000000
C100=100000000000000000000
C50=50000000000000000000
C5=5000000000000000000                # a tenth of fifty: the reporter's
C45=45000000000000000000              # and the nine tenths burnt
C10=10000000000000000000              # a tenth of a hundred
C90=90000000000000000000
SUPPLY=1000000000000000000000         # 1000 COCO
FEE=1200000000000                     # (1000 + 200) * 10^9, one native move

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-54s %s\n' "$1" "$(echo "$2" | cut -c1-20)"
  else
    printf 'FAIL %-54s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi

K="use_module(library(poa)), use_module(library(coco)),
   use_module(library(pos)), use_module(library(bft))"
loc() { timeout 120 "$C" run $FILES "$K, $1" 2>/dev/null \
        | grep -aoE '^answer\(.*\)$' | head -1 | sed 's/^answer(//; s/)$//'; }

# The three validators, their accounts, and a reporter who is not one of
# them -- all derived, none pasted.
WHO="coco_authority_account(alice, A), coco_authority_account(bob, B),
     coco_authority_account(carol, CA),
     secp256k1_pubkey('$ANN', NP), eth_address(NP, N)"
FUND="coco_genesis([A-'$C400', B-'$C300', CA-'$C300'])"
BONDS="coco_bond(A, '$C100'), coco_bond(B, '$C50'), coco_bond(CA, '$C50')"

# ---- part one: a weight is money that can be lost ---------------------
echo "-- the stake table, as a query over bonded coin"
check "bonding moves the money out of the balance and into the bond" \
  "$(loc "$WHO, $FUND, coco_bond(A, '$C100'), coco_bond_of(A, Bd),
          coco_balance(A, Bal), u256_sub('$C400', Bal, Gone),
          write(answer(Bd-Gone)), nl")" "$C100-$C100"
check "and the weight is what it bonded, in whole COCO" \
  "$(loc "$WHO, $FUND, coco_bond(A, '$C100'), stake_of(alice, W),
          write(answer(W)), nl")" "100"
check "three validators: the table, the total and the quorum" \
  "$(loc "$WHO, $FUND, $BONDS, stake_table(P), total_stake(T), quorum(T, Q),
          write(answer(P-T-Q)), nl")" \
  "[alice-100,bob-50,carol-50]-200-134"
# The rounding, stated rather than hidden: the safety arithmetic is
# integer arithmetic and money is u256, so weight is whole coins.
check "a bond under one whole COCO weighs nothing, and is still at risk" \
  "$(loc "$WHO, $FUND, coco_bond(A, '500000000000000000'),
          ( stake_of(alice, W) -> R = W ; R = no_weight ),
          coco_at_risk(A, Risk), write(answer(R-Risk)), nl")" \
  "no_weight-500000000000000000"
check "conservation holds across every bond" \
  "$(loc "$WHO, $FUND, $BONDS, ( coco_conservation -> W = conserved ; W = 'BROKEN' ),
          coco_supply(S), write(answer(W-S)), nl")" "conserved-$SUPPLY"

echo
echo "-- bonding is a transaction, and it is refused like any other"
BTX="Tx = tx(AP, 0, bond('$C100'), 5000), coco_tx_seal('$ALICE', Tx, Sig)"
check "a bond arrives as a signed transaction and pays its fee" \
  "$(loc "$WHO, secp256k1_pubkey('$ALICE', AP), $FUND, $BTX,
          coco_apply(Tx, Sig, N, 0, receipt(_, O, _, F)),
          coco_bond_of(A, Bd), write(answer(O-Bd-F)), nl")" \
  "ok-$C100-$FEE"
check "you cannot bond what you do not have" \
  "$(loc "$WHO, secp256k1_pubkey('$ALICE', AP), $FUND,
          Tx = tx(AP, 0, bond('900000000000000000000'), 5000),
          coco_tx_seal('$ALICE', Tx, Sig),
          coco_apply(Tx, Sig, N, 0, receipt(_, O, _, _)),
          coco_balance(A, Bal), write(answer(O-Bal)), nl")" \
  "refused(funds)-$C400"
check "and you cannot unbond more than you bonded" \
  "$(loc "$WHO, secp256k1_pubkey('$ALICE', AP), $FUND, coco_bond(A, '$C50'),
          Tx = tx(AP, 0, unbond('$C100'), 5000), coco_tx_seal('$ALICE', Tx, Sig),
          coco_apply(Tx, Sig, N, 0, receipt(_, O, _, _)),
          coco_bond_of(A, Bd), write(answer(O-Bd)), nl")" \
  "refused(funds)-$C50"

# ---- part two: leaving is slow ---------------------------------------
echo
echo "-- leaving is slow, and the money is at risk the whole way"
check "unbonding empties the bond without paying anybody yet" \
  "$(loc "$WHO, $FUND, coco_bond(A, '$C100'), coco_unbond(A, '$C100', 7),
          coco_bond_of(A, Bd), coco_unbonding_of(A, U), coco_balance(A, Bal),
          u256_sub('$C400', Bal, Gone), write(answer(Bd-U-Gone)), nl")" \
  "0-$C100-$C100"
# THE ESCAPE HATCH THAT IS NOT ONE: weight follows the risk, so a
# validator on its way out still votes -- and is still slashable.
check "and the weight stays, because the money is still takeable" \
  "$(loc "$WHO, $FUND, coco_bond(A, '$C100'), coco_unbond(A, '$C100', 7),
          stake_of(alice, W), write(answer(W)), nl")" "100"
check "the money does not come home one block early" \
  "$(loc "$WHO, $FUND, coco_bond(A, '$C100'), coco_unbond(A, '$C100', 7),
          coco_mature(9), coco_balance(A, Bal), coco_unbonding_of(A, U),
          u256_sub('$C400', Bal, Gone), write(answer(Gone-U)), nl")" \
  "$C100-$C100"
check "and it does at the height the unbonding named" \
  "$(loc "$WHO, $FUND, coco_bond(A, '$C100'), coco_unbond(A, '$C100', 7),
          coco_mature(10), coco_balance(A, Bal), coco_unbonding_of(A, U),
          ( stake_of(alice, W) -> R = W ; R = no_weight ),
          write(answer(Bal-U-R)), nl")" "$C400-0-no_weight"

# ---- part three: the evidence bites ----------------------------------
echo
echo "-- two signed votes that cannot both be honest"
# The votes are REAL: `cast/6' signs with bob's own key and
# `equivocation/3' verifies both signatures before it names anybody.
EQ="cast('$BOB', prevote, 1, 0, aaaa, S1), cast('$BOB', prevote, 1, 0, bbbb, S2),
    Votes = [vote(prevote,1,0,aaaa,bob,S1), vote(prevote,1,0,bbbb,bob,S2)]"
check "bob equivocates: the bond is taken, a tenth paid, nine burnt" \
  "$(loc "$WHO, $FUND, $BONDS, $EQ,
          slash_for_equivocation(Votes, N, slashed(Who, Taken, Reward)),
          coco_balance(N, Paid), coco_burnt_total(Burnt),
          write(answer(Who-Taken-Reward-Paid-Burnt)), nl")" \
  "bob-$C50-$C5-$C5-$C45"
check "conservation is exact through a slash, burn and all" \
  "$(loc "$WHO, $FUND, $BONDS, $EQ, slash_for_equivocation(Votes, N, _),
          ( coco_conservation -> W = conserved ; W = 'BROKEN' ),
          coco_supply(S), write(answer(W-S)), nl")" "conserved-$SUPPLY"
check "the culprit drops out of the table, and the quorum falls with it" \
  "$(loc "$WHO, $FUND, $BONDS, $EQ, slash_for_equivocation(Votes, N, _),
          stake_table(P), total_stake(T), quorum(T, Q),
          write(answer(P-T-Q)), nl")" \
  "[alice-100,carol-50]-150-101"
# THE ATTACK THE DELAY EXISTS FOR: equivocate, ask for everything back in
# the same breath, and the evidence still lands on money that has not
# gone home yet.
check "unbonding first does not save the culprit" \
  "$(loc "$WHO, $FUND, $BONDS, coco_unbond(B, '$C50', 1), $EQ,
          slash_for_equivocation(Votes, N, slashed(_, Taken, _)),
          coco_at_risk(B, Risk), coco_burnt_total(Burnt),
          write(answer(Taken-Risk-Burnt)), nl")" "$C50-0-$C45"
check "the same evidence cannot be reported twice" \
  "$(loc "$WHO, $FUND, $BONDS, $EQ, slash_for_equivocation(Votes, N, _),
          coco_bond(B, '$C50'),
          ( slash_for_equivocation(Votes, N, _) -> W = 'PAID AGAIN' ; W = refused ),
          coco_bond_of(B, Bd), write(answer(W-Bd)), nl")" "refused-$C50"
# RUBBISH IS NOT EVIDENCE, AND NOT AN EMERGENCY EITHER. A signature that
# is not a signature makes `secp256k1_verify/3' RAISE, so a list with one
# piece of garbage in it would have ended the turn of whichever node was
# asked to look at it. Each vote is verified under a catch first.
check "a garbage vote beside a real one is dropped, not fatal" \
  "$(loc "$WHO, $FUND, $BONDS,
          cast('$BOB', prevote, 1, 0, aaaa, S1),
          Votes = [vote(prevote,1,0,aaaa,bob,S1), vote(prevote,1,0,bbbb,bob,junk)],
          ( slash_for_equivocation(Votes, N, _) -> W = 'SLASHED' ; W = no_evidence ),
          coco_bond_of(B, Bd), write(answer(W-Bd)), nl")" "no_evidence-$C50"
check "two votes for the SAME block are not evidence of anything" \
  "$(loc "$WHO, $FUND, $BONDS,
          cast('$BOB', prevote, 1, 0, aaaa, S1),
          Votes = [vote(prevote,1,0,aaaa,bob,S1)],
          ( slash_for_equivocation(Votes, N, _) -> W = 'SLASHED' ; W = no_evidence ),
          coco_bond_of(B, Bd), write(answer(W-Bd)), nl")" "no_evidence-$C50"

echo
echo "-- two certificates at one height, and two that were made up"
# alice signs both sides at height 1. Each certificate carries a quorum
# (150 of 200, and the quorum is 134), so both are real -- and the
# INTERSECTION is what names her.
QC="cast('$ALICE', precommit, 1, 0, aaaa, A1), cast('$BOB', precommit, 1, 0, aaaa, B1),
    cast('$ALICE', precommit, 1, 0, bbbb, A2), cast('$CAROL', precommit, 1, 0, bbbb, C2),
    Q1 = qc(precommit, 1, 0, aaaa, [vote(precommit,1,0,aaaa,alice,A1),
                                    vote(precommit,1,0,aaaa,bob,B1)]),
    Q2 = qc(precommit, 1, 0, bbbb, [vote(precommit,1,0,bbbb,alice,A2),
                                    vote(precommit,1,0,bbbb,carol,C2)])"
check "the validator in both certificates is named and slashed" \
  "$(loc "$WHO, $FUND, $BONDS, $QC,
          slash_for_certificates(Q1, Q2, N, report(Names, Taken, Reward)),
          coco_burnt_total(Burnt), write(answer(Names-Taken-Reward-Burnt)), nl")" \
  "[alice]-$C100-$C10-$C90"
# `culprits/3' would have named her on two fabrications just as happily.
check "two made-up certificates rob nobody" \
  "$(loc "$WHO, $FUND, $BONDS,
          Q1 = qc(precommit, 1, 0, aaaa, [vote(precommit,1,0,aaaa,alice,deadbeef)]),
          Q2 = qc(precommit, 1, 0, bbbb, [vote(precommit,1,0,bbbb,alice,deadbeef)]),
          ( slash_for_certificates(Q1, Q2, N, _) -> W = 'ROBBED' ; W = refused ),
          coco_bond_of(A, Bd), write(answer(W-Bd)), nl")" "refused-$C100"

# ---- the chain half --------------------------------------------------
if ! timeout 20 "$C" $BASE --kb coco_bond_test list >/dev/null 2>&1; then
  echo
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT (the chain half)"
  echo
  if [ "$failures" -eq 0 ]; then echo "GREEN: 0 failure(s)"; exit 0
  else echo "RED: $failures failure(s)"; exit 1; fi
fi

KB="$BASE --kb coco_bond_test"
node() { NODE_NAME=$1 NODE_KEY=$(key_of "$1") timeout 120 "$C" $KB query "$K, $2" 2>/dev/null; }
key_of() { case "$1" in alice) echo "$ALICE";; esac; }
srv() { node "$1" "$2" | grep -aoE '^answer\(.*\)$' | head -1 | sed 's/^answer(//; s/)$//'; }

timeout 120 "$C" $KB forget >/dev/null 2>&1
for f in $FILES; do timeout 120 "$C" $KB consult "$f" >/dev/null 2>&1; done

echo
echo "-- the bond arrives as a block, and matures against the chain's height"
node alice "$WHO, coco_seal_genesis([A-'$C400', B-'$C300', CA-'$C300'])" >/dev/null
node alice "$WHO, secp256k1_pubkey('$ALICE', AP), Tx = tx(AP, 0, bond('$C100'), 5000),
            coco_tx_seal('$ALICE', Tx, Sig), coco_submit(Tx, Sig)" >/dev/null
node alice "coco_settle_chain" >/dev/null
check "a bonded validator, from rows a second process read" \
  "$(srv alice "stake_table(P), total_stake(T), write(answer(P-T)), nl")" \
  "[alice-100]-100"
# The unbonding is sealed at height 2, so it is ready at 5: three more
# blocks have to exist before the money is home. Nothing claims it -- any
# node settling those heights moves it.
node alice "$WHO, secp256k1_pubkey('$ALICE', AP), Tx = tx(AP, 1, unbond('$C100'), 5000),
            coco_tx_seal('$ALICE', Tx, Sig), coco_submit(Tx, Sig)" >/dev/null
node alice "coco_settle_chain" >/dev/null
check "unbonding leaves the weight standing while the money is at risk" \
  "$(srv alice "$WHO, stake_of(alice, W), coco_unbonding_of(A, U),
                write(answer(W-U)), nl")" "100-$C100"
for _ in 1 2 3; do node alice "ledger_seal(tick)" >/dev/null; done
node alice "coco_settle_chain" >/dev/null
check "three blocks later it is home, and the weight is gone" \
  "$(srv alice "$WHO, coco_balance(A, Bal), coco_unbonding_of(A, U),
                ( stake_of(alice, W) -> R = W ; R = no_weight ),
                write(answer(Bal-U-R)), nl")" "$C400-0-no_weight"
check "and a bare process finds the supply still whole" \
  "$(timeout 120 "$C" $KB query "$K, coco_supply(S),
       ( coco_conservation -> W = ok ; W = 'BROKEN' ), write(answer(S-W)), nl" \
     2>/dev/null | grep -aoE '^answer\(.*\)$' | head -1 | sed 's/^answer(//; s/)$//')" \
  "$SUPPLY-ok"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
