#!/bin/sh
# COCO: the native token, and gas priced in INFERENCES.
#
# The chain has had money in it since rung 3 -- `contracts/token' is
# ERC-20's shape and ERC-721's -- but a token deployed ON a chain cannot
# be what the chain CHARGES IN: the fence has no way to price its own
# execution, and a contract able to move the currency the node bills in
# would be a contract that pays itself. So COCO is `library(coco)', the
# node's own, and this case is what it promises.
#
# WHAT IT IS CHECKING, in five parts.
#
#   THE COIN CONSERVES. There is no mint: `coco_genesis/1' writes the
#   supply once and refuses a second time, no other rule raises it, and
#   the fee is PAID to the sealing authority rather than burnt -- so the
#   balances sum to the supply at every moment and `coco_conservation/0'
#   says so after every part of this file.
#
#   GAS IS THE ENGINE'S COUNT. cocolog's `call_metered/4' answers what a
#   goal actually spent, so a fee is arithmetic over a number the engine
#   produced rather than an estimate of it. The checks are the ones that
#   distinguish a meter from a constant: a contract asked for ten times
#   the work costs strictly more COCO, and the same call twice costs the
#   same to the unit -- which is what lets two nodes that never met agree
#   on a bill.
#
#   WORK THAT FAILED IS STILL WORK. A contract call that does not prove
#   pays; a contract that never stops pays exactly the gas it was sold.
#   Searching for a proof that is not there is precisely the work an
#   attacker would like for free.
#
#   YOU CANNOT BUY GAS YOU CANNOT PAY FOR. The ceiling is the lower of
#   what the sender asked for and what the balance already covers, so
#   nothing is taken up front and no bill arrives that cannot be met. The
#   poor sender's runaway below spends its LAST unit and not one more,
#   which is that rule stated as a number.
#
#   AND THE CHAIN IS THE ONLY WAY IN. A transaction is a block payload,
#   so it inherits the ledger's own laws: mallory is not an authority,
#   her block never joins the chain, and the account she signed for is
#   never debited -- refused one layer down, where the gas layer never
#   sees it. Two layers asking two questions: who may seal, and who may
#   spend.
#
# SKIPs the chain half without a Zigurat server.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

BASE="$ZIGURAT_DIAL --timeout 30"
LED="$ROOT/ledger"
CON="$ROOT/contracts"
FILES="$LED/federation.pl $LED/node.pl $LED/gas.pl $CON/sources.pl $CON/node.pl"

# The keys are the obvious ones, as everywhere in this repository: every
# public key and every address below can be rederived with
# `secp256k1_pubkey' and `eth_address' by anyone reading.
ALICE=1111111111111111111111111111111111111111111111111111111111111111
ANN=5555555555555555555555555555555555555555555555555555555555555555
BEA=6666666666666666666666666666666666666666666666666666666666666666
POOR=7777777777777777777777777777777777777777777777777777777777777777
MALLORY=4444444444444444444444444444444444444444444444444444444444444444

# The schedule, restated here so a check that disagrees with the library
# says so rather than quietly following it: one inference costs 10^9, a
# transaction pays 1000 inferences flat, and a native move costs 200.
ONE=1000000000000000000            # one COCO, 18 decimals
HALF=500000000000000000
FEE_XFER=1200000000000             # (1000 + 200) * 10^9

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

K="use_module(library(poa)), use_module(library(contract)), use_module(library(coco))"
# Anchored on both ends: cocolog echoes the goal it ran, and an
# unanchored search would happily match the goal's own text.
loc() { timeout 120 "$C" run $FILES "$K, $1" 2>/dev/null \
        | grep -aoE '^answer\(.*\)$' | head -1 | sed 's/^answer(//; s/)$//'; }

# Two accounts and an authority's, derived rather than pasted.
WHO="secp256k1_pubkey('$ANN', AP), eth_address(AP, A),
     secp256k1_pubkey('$BEA', BP), eth_address(BP, B),
     coco_authority_account(alice, AU)"
FUND="coco_genesis([A-'$ONE'])"

# ---- part one: the coin ----------------------------------------------
echo "-- the coin: a supply that is minted once and afterwards only moves"
check "genesis mints exactly what it allocated" \
  "$(loc "$WHO, $FUND, coco_supply(T), coco_balance(A, X),
          ( T == X -> W = T ; W = T-X ), write(answer(W)), nl")" "$ONE"
check "a second genesis is refused: there is no mint" \
  "$(loc "$WHO, $FUND, ( coco_genesis([B-'$ONE']) -> W = 'MINTED AGAIN' ; W = refused ),
          coco_supply(T), write(answer(W-T)), nl")" "refused-$ONE"
# `assertz' is not undone by backtracking in any Prolog, so an allocation
# that failed half way would leave real balances behind with no supply to
# account for them -- and conservation would be broken by the one
# predicate whose job is to establish it. The whole list is checked
# before a row is written.
check "a genesis it cannot honour writes nothing at all" \
  "$(loc "$WHO, ( coco_genesis([A-'$ONE', A-'$ONE']) -> W = 'ALLOCATED' ; W = refused ),
          coco_balance(A, X), ( coco_supply(_) -> S = supply ; S = none ),
          write(answer(W-X-S)), nl")" "refused-0-none"
check "an address nobody funded holds zero, not nothing" \
  "$(loc "$WHO, $FUND, coco_balance(B, X), write(answer(X)), nl")" "0"
check "a transfer moves exactly what it says, both sides" \
  "$(loc "$WHO, $FUND, coco_transfer(A, B, '$HALF'),
          coco_balance(A, X), coco_balance(B, Y), write(answer(X-Y)), nl")" \
  "$HALF-$HALF"
check "more than you have is refused" \
  "$(loc "$WHO, $FUND, ( coco_transfer(A, B, '2000000000000000000')
          -> W = 'OVERDRAWN' ; W = refused ), coco_balance(A, X),
          write(answer(W-X)), nl")" "refused-$ONE"
# The classic doubling bug: subtracting and adding against two separately
# read copies of ONE balance. It must still be well formed, though --
# paying yourself what you do not have is how a balance check gets
# skipped.
check "paying yourself changes nothing, and must still be affordable" \
  "$(loc "$WHO, $FUND, coco_transfer(A, A, '$HALF'), coco_balance(A, X),
          ( coco_transfer(A, A, '2000000000000000000') -> W = 'DOUBLED' ; W = refused ),
          write(answer(X-W)), nl")" "$ONE-refused"

# ---- part two: the schedule ------------------------------------------
echo
echo "-- the schedule, which is two clauses anyone can point at"
check "a fee is the price of one inference times the count" \
  "$(loc "coco_fee(1200, F), write(answer(F)), nl")" "$FEE_XFER"
check "a balance buys the inferences it can pay for, floored" \
  "$(loc "$WHO, coco_genesis([A-'3500000000000']), coco_affordable(A, S),
          write(answer(S)), nl")" "3500"
# However rich the sender: a block one account can occupy for as long as
# it can pay is a block everybody else is priced out of.
check "and never more than the block limit, however rich" \
  "$(loc "$WHO, $FUND, coco_affordable(A, S), coco_block_limit(M),
          ( S =:= M -> W = capped ; W = S ), write(answer(W)), nl")" "capped"

# ---- part three: a transaction ---------------------------------------
echo
echo "-- a transaction: signed, nonced, and paid for"
TX="Tx = tx(AP, 0, transfer(B, '$HALF'), 5000), coco_tx_seal('$ANN', Tx, Sig)"
check "a native transfer moves the money and pays the sealer" \
  "$(loc "$WHO, $FUND, $TX, coco_apply(Tx, Sig, AU, 0, receipt(_, O, U, _)),
          coco_balance(A, X), coco_balance(B, Y), coco_balance(AU, Z),
          write(answer(O-U-X-Y-Z)), nl")" \
  "ok-1200-499998800000000000-$HALF-$FEE_XFER"
check "and the supply is untouched by all of it" \
  "$(loc "$WHO, $FUND, $TX, coco_apply(Tx, Sig, AU, 0, _),
          ( coco_conservation -> W = conserved ; W = 'BROKEN' ),
          coco_supply(T), write(answer(W-T)), nl")" "conserved-$ONE"
# THE NONCE IS WHAT MAKES A SIGNATURE USABLE ONCE. It is inside the
# signed text, so a replay carries the number it was signed with.
check "the same transaction twice: the second is refused, and free" \
  "$(loc "$WHO, $FUND, $TX, coco_apply(Tx, Sig, AU, 0, _),
          coco_apply(Tx, Sig, AU, 0, receipt(_, O2, U2, F2)),
          coco_balance(A, X), write(answer(O2-U2-F2-X)), nl")" \
  "refused(nonce)-0-0-499998800000000000"
# Every field a node acts on is in the signed text, so moving one breaks
# the signature -- here the ceiling, which is the field a cheat would
# most like to raise after the fact.
check "a raised gas limit does not survive the signature" \
  "$(loc "$WHO, $FUND, $TX, Tx2 = tx(AP, 0, transfer(B, '$HALF'), 900000),
          coco_apply(Tx2, Sig, AU, 0, receipt(_, O, _, _)),
          coco_balance(A, X), write(answer(O-X)), nl")" \
  "refused(signature)-$ONE"
check "and neither does a raised amount" \
  "$(loc "$WHO, $FUND, $TX, Tx2 = tx(AP, 0, transfer(B, '$ONE'), 5000),
          coco_apply(Tx2, Sig, AU, 0, receipt(_, O, _, _)), write(answer(O)), nl")" \
  "refused(signature)"
# RUBBISH IS A REFUSAL, NOT AN EMERGENCY. Both the curve and the money
# RAISE on malformed input rather than failing -- `secp256k1_verify/3'
# answers domain_error('a 64-byte signature', deadbeef) and `u256_cmp/3'
# throws on an amount that is not a number -- and both are right to,
# because a program handing them rubbish has a bug. A transaction is not
# a program: it is bytes somebody else chose, and the one thing they must
# not be able to choose is whether this node finishes its turn. So the
# two gates are total, and these are the checks that say so.
check "a garbage signature is refused, and the node answers afterwards" \
  "$(loc "$WHO, $FUND, Tx = tx(AP, 0, transfer(B, '$HALF'), 5000),
          coco_apply(Tx, deadbeef, AU, 0, receipt(_, O, _, _)),
          coco_balance(A, X), write(answer(O-X)), nl")" \
  "refused(signature)-$ONE"
check "and an amount that is not a number is refused, not fatal" \
  "$(loc "$WHO, $FUND, Tx = tx(AP, 0, transfer(B, lots), 5000),
          coco_tx_seal('$ANN', Tx, S2), coco_apply(Tx, S2, AU, 0, receipt(_, O, _, _)),
          coco_balance(A, X), write(answer(O-X)), nl")" \
  "refused(malformed)-$ONE"
check "a transfer of nothing is not a transaction" \
  "$(loc "$WHO, $FUND, Tx = tx(AP, 0, transfer(B, '0'), 5000),
          coco_tx_seal('$ANN', Tx, S2), coco_apply(Tx, S2, AU, 0, receipt(_, O, _, _)),
          write(answer(O)), nl")" "refused(malformed)"

# ---- part four: GAS FOR STEPS ----------------------------------------
echo
echo "-- gas for steps: the engine counts, and the count is the price"
CALL="coco_tx_seal('$ANN', Tx, Sig), coco_apply(Tx, Sig, AU, 0, receipt(_, O, U, F))"
INST="contract_source(adder, Cs), contract_install(adder, Cs)"
check "a fenced call runs, and is billed for what it spent" \
  "$(loc "$WHO, $FUND, $INST, Tx = tx(AP, 0, call(adder, sum_to(10, _)), 100000),
          $CALL, coco_fee(U, F2),
          ( F == F2, U > 1000 -> W = billed ; W = U-F ), write(answer(O-W)), nl")" \
  "ok-billed"
# THE CHECK THAT SEPARATES A METER FROM A CONSTANT. Ten times the work
# costs strictly more, and the intrinsic is in both, so the difference is
# the inferences themselves.
check "ten times the work costs strictly more COCO" \
  "$(loc "$WHO, $FUND, $INST,
          Tx = tx(AP, 0, call(adder, sum_to(10, _)), 100000), $CALL,
          Tx2 = tx(AP, 1, call(adder, sum_to(100, _)), 100000),
          coco_tx_seal('$ANN', Tx2, S2), coco_apply(Tx2, S2, AU, 0, receipt(_, _, U2, F2)),
          ( u256_cmp(F2, F, '>'), U2 > U -> W = dearer ; W = U-U2 ),
          write(answer(W)), nl")" "dearer"
# ...and the same call twice costs the same to the unit, which is what
# lets a party who did not run it check the bill.
check "the same call twice is the same bill, to the unit" \
  "$(loc "$WHO, $FUND, $INST,
          Tx = tx(AP, 0, call(adder, sum_to(50, _)), 100000), $CALL,
          Tx2 = tx(AP, 1, call(adder, sum_to(50, _)), 100000),
          coco_tx_seal('$ANN', Tx2, S2), coco_apply(Tx2, S2, AU, 0, receipt(_, _, U2, F2)),
          ( U =:= U2, F == F2 -> W = identical ; W = U-U2 ), write(answer(W)), nl")" \
  "identical"
check "a call that fails still pays: a search is work" \
  "$(loc "$WHO, $FUND, $INST, Tx = tx(AP, 0, call(adder, sum_to(-5, _)), 100000),
          $CALL, ( u256_cmp(F, '0', '>') -> W = paid ; W = free ),
          write(answer(O-W)), nl")" "failed-paid"
# A CONTRACT THAT NEVER STOPS is admitted -- no static check can know it
# does not halt -- and gas is the whole answer. The fee is EXACT here:
# the intrinsic plus the ceiling, and not the inference the engine spent
# noticing the budget was gone. Nobody is billed for gas they were not
# sold.
RUN="attack_source(runaway, RCs, _), contract_install(runaway, RCs)"   # RCs, not Cs: $INST binds Cs and the two compose in one goal
check "a runaway is stopped, and charged its ceiling exactly" \
  "$(loc "$WHO, $FUND, $RUN, Tx = tx(AP, 0, call(runaway, spin(0)), 5000),
          $CALL, write(answer(O-U-F)), nl")" \
  "out_of_gas-6000-6000000000000"
check "and the node is unharmed and still answers afterwards" \
  "$(loc "$WHO, $FUND, $RUN, Tx = tx(AP, 0, call(runaway, spin(0)), 5000), $CALL,
          $INST, Tx2 = tx(AP, 1, call(adder, sum_to(10, S)), 100000),
          coco_tx_seal('$ANN', Tx2, S2), coco_apply(Tx2, S2, AU, 0, receipt(_, O2, _, _)),
          write(answer(O2-S)), nl")" "ok-55"

echo
echo "-- you cannot buy gas you cannot pay for"
POORW="secp256k1_pubkey('$POOR', PP), eth_address(PP, P)"
# The ceiling is the LOWER of what the sender asked for and what the
# balance covers. This sender asked for 100 000 inferences holding 3000
# inferences' worth; the runaway spends its last unit and not one more.
check "a poor sender's runaway costs exactly everything, and no more" \
  "$(loc "$POORW, coco_authority_account(alice, AU), coco_genesis([P-'3000000000000']),
          $RUN, Tx = tx(PP, 0, call(runaway, spin(0)), 100000),
          coco_tx_seal('$POOR', Tx, Sig), coco_apply(Tx, Sig, AU, 0, receipt(_, O, U, F)),
          coco_balance(P, X), write(answer(O-U-F-X)), nl")" \
  "out_of_gas-3000-3000000000000-0"
# ...and below the intrinsic there is no transaction at all: nobody may
# be billed for one the node declined to run.
check "below the intrinsic it is refused, and nothing is taken" \
  "$(loc "$POORW, coco_authority_account(alice, AU), coco_genesis([P-'500000000000']),
          $RUN, Tx = tx(PP, 0, call(runaway, spin(0)), 100000),
          coco_tx_seal('$POOR', Tx, Sig), coco_apply(Tx, Sig, AU, 0, receipt(_, O, _, F)),
          coco_balance(P, X), coco_nonce(P, N), write(answer(O-F-X-N)), nl")" \
  "refused(gas)-0-500000000000-0"
check "conservation survives every one of those" \
  "$(loc "$POORW, coco_authority_account(alice, AU), coco_genesis([P-'3000000000000']),
          $RUN, Tx = tx(PP, 0, call(runaway, spin(0)), 100000),
          coco_tx_seal('$POOR', Tx, Sig), coco_apply(Tx, Sig, AU, 0, _),
          ( coco_conservation -> W = conserved ; W = 'BROKEN' ), write(answer(W)), nl")" \
  "conserved"

# ---- the chain half --------------------------------------------------
if ! timeout 20 "$C" $BASE --kb coco_gas_test list >/dev/null 2>&1; then
  echo
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT (the chain half)"
  echo
  if [ "$failures" -eq 0 ]; then echo "GREEN: 0 failure(s)"; exit 0
  else echo "RED: $failures failure(s)"; exit 1; fi
fi

KB="$BASE --kb coco_gas_test"
node() { NODE_NAME=$1 NODE_KEY=$(key_of "$1") timeout 120 "$C" $KB query "$K, $2" 2>/dev/null; }
key_of() { case "$1" in alice) echo "$ALICE";; esac; }
srv() { node "$1" "$2" | grep -aoE '^answer\(.*\)$' | head -1 | sed 's/^answer(//; s/)$//'; }

timeout 120 "$C" $KB forget >/dev/null 2>&1
for f in $FILES; do timeout 120 "$C" $KB consult "$f" >/dev/null 2>&1; done

echo
echo "-- the chain is the only way in"
# Genesis is a block, and so is every transaction after it. Nothing new
# was needed for either: the payload happens to be money.
node alice "$WHO, coco_seal_genesis([A-'$ONE'])" >/dev/null
node alice "$WHO, $TX, coco_submit(Tx, Sig)" >/dev/null
node alice "coco_settle_chain" >/dev/null
check "genesis and a transfer, settled off the chain this node agreed on" \
  "$(srv alice "$WHO, coco_balance(A, X), coco_balance(B, Y), coco_balance(AU, Z),
                write(answer(X-Y-Z)), nl")" \
  "499998800000000000-$HALF-$FEE_XFER"
# A SECOND PASS IS NOT A SECOND DEBIT. A block settles once, marked by
# its hash, whatever order the blocks arrived in.
check "settling again moves nothing" \
  "$(srv alice "$WHO, coco_settle_chain, coco_balance(A, X), write(answer(X)), nl")" \
  "499998800000000000"
# THE OTHER LAYER. Mallory is not an authority, so her block is refused
# as a BLOCK -- the gas layer never sees the transaction inside it, and
# ann is never debited by a transaction ann never signed either.
check "mallory's sealed transaction never reaches the gas layer" \
  "$(srv alice "$WHO, Tx3 = tx(AP, 1, transfer(B, '$HALF'), 5000),
       coco_tx_seal('$ANN', Tx3, S3), term_to_atom(coco_send(Tx3, S3), P3),
       ledger_head(head(H0, PH, _)), H is H0 + 1,
       seal('$MALLORY', H, PH, mallory, P3, MS, MH),
       ledger_sync([block(H, PH, mallory, P3, MS, MH)]),
       coco_settle_chain, coco_balance(A, X), write(answer(X)), nl")" \
  "499998800000000000"
# And the claim this whole family is built on: a process that consulted
# NOTHING reads the money back out of the knowledge base.
echo
echo "-- a bare process, which consulted nothing, reads the money back"
check "supply, holders and conservation, from rows alone" \
  "$(timeout 120 "$C" $KB query "$K, coco_supply(T), coco_holders(Hs), length(Hs, N),
       ( coco_conservation -> W = ok ; W = 'BROKEN' ), write(answer(T-N-W)), nl" \
     2>/dev/null | grep -aoE '^answer\(.*\)$' | head -1 | sed 's/^answer(//; s/)$//')" \
  "$ONE-3-ok"
check "and the receipt for what happened is on the record too" \
  "$(timeout 120 "$C" $KB query "$K, findall(O, coco_receipt(_, receipt(_, O, _, _)), Os),
       msort(Os, S), write(answer(S)), nl" 2>/dev/null \
     | grep -aoE '^answer\(.*\)$' | head -1 | sed 's/^answer(//; s/)$//')" \
  "[ok,ok]"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
