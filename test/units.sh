#!/bin/sh
# UNITS AS NFTs -- and `caller/1', without which a contract owns nothing.
#
# The Coco's future-work page says it in a line: "Units are NFTs by
# construction -- CivV's capture clause already retracts one `unit_owner'
# row and asserts another, which IS transfer; production mints, the kill
# burns." This case is that sentence as a deployed contract, and the
# capability it turned out to need.
#
# WHAT IT IS CHECKING, in four parts.
#
#   A CONTRACT CAN ASK WHO IS CALLING, and until this rung none could.
#   Every ownership predicate in this repository takes its owner as an
#   ARGUMENT -- `nft_transfer_from(Collection, Caller, From, To, Id)'
#   names the caller in the call -- which is safe only while the caller
#   is the node itself. Rung 9 made a transaction able to reach a
#   contract, so that argument became a field a stranger writes. The
#   caller now comes from `coco_apply/5', which knows the sender because
#   it verified the signature over the whole transaction; a direct call
#   reports `nobody', which every guard here refuses.
#
#   PRODUCTION IS THE REFEREE'S AND NOBODY ELSE'S. Opening a match makes
#   the caller its referee; only that address may mint into that match.
#   A stranger's mint FAILS -- and pays for the attempt, because gas is
#   charged for work and not for outcomes.
#
#   CAPTURE IS A TRANSFER NOBODY AGREED TO, which is where this parts
#   company with ERC-721 on purpose: the standard's whole structure is
#   consent, and a captured unit is taken. So the referee moves it
#   without asking -- fenced by being per MATCH -- while the holder keeps
#   the ordinary consented move, and a kill burns the id forever.
#
#   AND PROVENANCE IS A QUERY, not a table. The chain already carries
#   every transaction; `coco_unit_history/2' walks it and keeps the ones
#   that TOOK EFFECT, so a refused mint is in the blocks, was paid for,
#   and is not in the unit's life.
#
# SKIPs the chain half without a Zigurat server.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

BASE="$ZIGURAT_DIAL --timeout 30"
LED="$ROOT/ledger"
CON="$ROOT/contracts"
FILES="$LED/federation.pl $LED/node.pl $LED/gas.pl $CON/sources.pl
       $CON/token/units.pl $CON/node.pl"

ALICE=1111111111111111111111111111111111111111111111111111111111111111
REF=5555555555555555555555555555555555555555555555555555555555555555
STR=6666666666666666666666666666666666666666666666666666666666666666
ONE=1000000000000000000

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
loc() { timeout 120 "$C" run $FILES "$K, $1" 2>/dev/null \
        | grep -aoE '^answer\(.*\)$' | head -1 | sed 's/^answer(//; s/)$//'; }

# The referee, a stranger, and the two players who hold what is minted.
WHO="secp256k1_pubkey('$REF', RP), eth_address(RP, R),
     secp256k1_pubkey('$STR', SP), eth_address(SP, ST),
     coco_authority_account(alice, AU), coco_authority_account(bob, PB)"
FUND="coco_genesis([R-'$ONE', ST-'$ONE'])"
INST="contract_source(units, Cs), contract_install(units, Cs)"

# One signed transaction, from the referee or from the stranger. Nonce
# and height are the same index, which keeps the scenes readable: the
# nth thing this sender did, in the nth block.
ref_tx() { echo "T$1 = tx(RP, $1, $2, 200000), coco_tx_seal('$REF', T$1, S$1),
                 coco_apply(T$1, S$1, AU, $1, receipt(_, O$1, _, _))"; }
str_tx() { echo "X$1 = tx(SP, $1, $2, 200000), coco_tx_seal('$STR', X$1, XS$1),
                 coco_apply(X$1, XS$1, AU, $1, receipt(_, XO$1, _, XF$1))"; }

OPEN=$(ref_tx 0 "call(units, unit_open_match(m1))")
MINT=$(ref_tx 1 "call(units, unit_mint(u1, 'Warrior', m1, PB))")

# ---- part one: who is calling ----------------------------------------
echo "-- the caller, without which a contract owns nothing"
check "a direct call is nobody, and an owning action refuses it" \
  "$(loc "$WHO, $FUND, $INST,
          ( contract_call(units, unit_open_match(m1)) -> W = 'OPENED' ; W = refused ),
          write(answer(W)), nl")" "refused"
check "through a transaction the caller IS the sender" \
  "$(loc "$WHO, $FUND, $INST, $OPEN, contract_enter(units),
          ( unit_referee(m1, Rf) -> true ; Rf = none ),
          ( Rf == R -> W = the_sender ; W = Rf ), write(answer(O0-W)), nl")" \
  "ok-the_sender"
# The caller is READ by a contract and cannot be SET by one: the fence
# has `caller/1' in its vocabulary and nothing that writes it, and
# `nb_setval' was already forbidden outright.
check "a contract that tries to set its own caller is refused" \
  "$(loc "contract_admit(sneak, [(go :- contract_enter(units, me))], V),
          write(answer(V)), nl")" "refused"
check "a match has one referee: the second to ask is refused" \
  "$(loc "$WHO, $FUND, $INST, $OPEN,
          $(str_tx 0 "call(units, unit_open_match(m1))"),
          contract_enter(units), unit_referee(m1, Rf),
          ( Rf == R -> W = first_come ; W = Rf ), write(answer(XO0-W)), nl")" \
  "failed-first_come"

# ---- part two: production --------------------------------------------
echo
echo "-- production is the referee's, and an attempt still pays"
check "the referee mints, and the unit is what it was minted as" \
  "$(loc "$WHO, $FUND, $INST, $OPEN, $MINT, contract_enter(units),
          unit_holder(u1, H), unit_kind(u1, Kd), unit_home(u1, Hm),
          ( H == PB -> W = held ; W = H ), write(answer(O1-W-Kd-Hm)), nl")" \
  "ok-held-Warrior-m1"
check "a stranger's mint fails -- and is charged for the attempt" \
  "$(loc "$WHO, $FUND, $INST, $OPEN,
          $(str_tx 0 "call(units, unit_mint(u9, 'Warrior', m1, ST))"),
          contract_enter(units), ( unit_alive(u9) -> W = 'MINTED' ; W = refused ),
          ( u256_cmp(XF0, '0', '>') -> P = paid ; P = free ),
          write(answer(XO0-W-P)), nl")" "failed-refused-paid"
check "one id, once: the second mint of u1 changes nothing" \
  "$(loc "$WHO, $FUND, $INST, $OPEN, $MINT,
          $(ref_tx 2 "call(units, unit_mint(u1, 'Settler', m1, R))"),
          contract_enter(units), unit_holder(u1, H), unit_kind(u1, Kd),
          ( H == PB -> W = unchanged ; W = H ), write(answer(O2-W-Kd)), nl")" \
  "failed-unchanged-Warrior"

# ---- part three: capture, trade, death -------------------------------
echo
echo "-- capture is taken, a gift is given, and a kill is forever"
check "the referee captures it: the holder did not agree and it moved" \
  "$(loc "$WHO, $FUND, $INST, $OPEN, $MINT,
          $(ref_tx 2 "call(units, unit_capture(u1, R))"),
          contract_enter(units), unit_holder(u1, H),
          ( H == R -> W = taken ; W = H ), write(answer(O2-W)), nl")" "ok-taken"
check "a stranger cannot capture it" \
  "$(loc "$WHO, $FUND, $INST, $OPEN, $MINT,
          $(str_tx 0 "call(units, unit_capture(u1, ST))"),
          contract_enter(units), unit_holder(u1, H),
          ( H == PB -> W = held ; W = H ), write(answer(XO0-W)), nl")" \
  "failed-held"
# A referee reaches its OWN match and no further, which is what makes the
# no-consent power bearable.
check "and neither can the referee of another match" \
  "$(loc "$WHO, $FUND, $INST, $OPEN, $MINT,
          $(str_tx 0 "call(units, unit_open_match(m2))"),
          $(str_tx 1 "call(units, unit_capture(u1, ST))"),
          contract_enter(units), unit_holder(u1, H),
          ( H == PB -> W = held ; W = H ), write(answer(XO1-W)), nl")" \
  "failed-held"
check "the holder may give it away; a non-holder may not" \
  "$(loc "$WHO, $FUND, $INST, $OPEN,
          $(ref_tx 1 "call(units, unit_mint(u1, 'Warrior', m1, ST))"),
          $(str_tx 0 "call(units, unit_give(u1, R))"),
          $(str_tx 1 "call(units, unit_give(u1, ST))"),
          contract_enter(units), unit_holder(u1, H),
          ( H == R -> W = given ; W = H ), write(answer(XO0-XO1-W)), nl")" \
  "ok-failed-given"
check "a kill burns it: not alive, and dead is a fact" \
  "$(loc "$WHO, $FUND, $INST, $OPEN, $MINT,
          $(ref_tx 2 "call(units, unit_kill(u1))"),
          contract_enter(units),
          ( unit_alive(u1) -> A = 'ALIVE' ; A = gone ),
          ( unit_dead(u1) -> D = dead ; D = 'NOT DEAD' ),
          write(answer(O2-A-D)), nl")" "ok-gone-dead"
check "the dead do not move, and cannot die twice" \
  "$(loc "$WHO, $FUND, $INST, $OPEN, $MINT,
          $(ref_tx 2 "call(units, unit_kill(u1))"),
          $(ref_tx 3 "call(units, unit_capture(u1, R))"),
          $(ref_tx 4 "call(units, unit_kill(u1))"),
          write(answer(O3-O4)), nl")" "failed-failed"
# State here is append-only, so an id that has EVER existed is spent --
# not merely one alive now. Two units with one provenance would make
# provenance the only thing a chain offers a game and worthless.
check "and a burnt id is never reissued" \
  "$(loc "$WHO, $FUND, $INST, $OPEN, $MINT,
          $(ref_tx 2 "call(units, unit_kill(u1))"),
          $(ref_tx 3 "call(units, unit_mint(u1, 'Archer', m1, R))"),
          contract_enter(units), unit_kind(u1, Kd),
          ( unit_alive(u1) -> A = 'REISSUED' ; A = still_gone ),
          write(answer(O3-A-Kd)), nl")" "failed-still_gone-Warrior"

# ---- the chain half --------------------------------------------------
if ! timeout 20 "$C" $BASE --kb coco_units_test list >/dev/null 2>&1; then
  echo
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT (the chain half)"
  echo
  if [ "$failures" -eq 0 ]; then echo "GREEN: 0 failure(s)"; exit 0
  else echo "RED: $failures failure(s)"; exit 1; fi
fi

KB="$BASE --kb coco_units_test"
node() { NODE_NAME=$1 NODE_KEY=$(key_of "$1") timeout 120 "$C" $KB query "$K, $2" 2>/dev/null; }
key_of() { case "$1" in alice) echo "$ALICE";; esac; }
srv() { node "$1" "$2" | grep -aoE '^answer\(.*\)$' | head -1 | sed 's/^answer(//; s/)$//'; }
bare() { timeout 120 "$C" $KB query "$K, $1" 2>/dev/null \
         | grep -aoE '^answer\(.*\)$' | head -1 | sed 's/^answer(//; s/)$//'; }

timeout 120 "$C" $KB forget >/dev/null 2>&1
for f in $FILES; do timeout 120 "$C" $KB consult "$f" >/dev/null 2>&1; done

echo
echo "-- the collection arrives as a block, and a unit lives on the chain"
# Deployment is an ordinary seal whose payload happens to be a contract,
# and the fence is what admits it -- rung 3's arrangement, unchanged.
node alice "$WHO, coco_seal_genesis([R-'$ONE', ST-'$ONE'])" >/dev/null
node alice "deploy(units)" >/dev/null
node alice "install_from_chain, coco_settle_chain" >/dev/null
check "the units contract is installed off the chain that carried it" \
  "$(srv alice "( contract_clause(units, _) -> W = installed ; W = 'ABSENT' ),
                write(answer(W)), nl")" "installed"

sub() { node alice "$WHO, T = tx($1, $2, $3, 200000), coco_tx_seal('$4', T, S),
                    coco_submit(T, S)" >/dev/null; }
sub RP 0 "call(units, unit_open_match(m1))" "$REF"
sub RP 1 "call(units, unit_mint(u1, 'Warrior', m1, PB))" "$REF"
sub SP 0 "call(units, unit_mint(u2, 'Archer', m1, ST))" "$STR"   # refused: not the referee
sub RP 2 "call(units, unit_capture(u1, R))" "$REF"
sub RP 3 "call(units, unit_kill(u1))" "$REF"
node alice "coco_settle_chain" >/dev/null

check "a bare process finds the unit lived and died" \
  "$(bare "contract_enter(units), unit_kind(u1, Kd), unit_home(u1, Hm),
           ( unit_dead(u1) -> D = dead ; D = 'ALIVE' ),
           write(answer(Kd-Hm-D)), nl")" "Warrior-m1-dead"
# THE PROVENANCE, off the blocks themselves: minted, captured, killed --
# and the stranger's refused mint is in the chain, was paid for, and is
# not part of any unit's life.
check "and reads its whole life out of the chain, in order" \
  "$(bare "coco_unit_history(u1, Es),
           findall(G, member(event(_, _, G), Es), Gs),
           write(answer(Gs)), nl")" \
  "[unit_mint(u1,Warrior,m1,$(srv alice "$WHO, write(answer(PB)), nl")),unit_capture(u1,$(srv alice "$WHO, write(answer(R)), nl")),unit_kill(u1)]"
check "the refused mint is in the blocks and not in a history" \
  "$(bare "coco_unit_history(u2, Es), length(Es, N),
           findall(1, ( block(_, _, _, P, _, _), coco_payload(P, T),
                        T = coco_send(tx(_,_,call(units,unit_mint(u2,_,_,_)),_), _) ), Bs),
           length(Bs, B), write(answer(N-B)), nl")" "0-1"
check "every transaction is on the record, refusals included" \
  "$(bare "findall(O, coco_receipt(_, receipt(_, O, _, _)), Os), msort(Os, S),
           write(answer(S)), nl")" "[failed,ok,ok,ok,ok,ok]"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
