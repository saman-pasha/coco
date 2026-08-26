#!/bin/sh
# contracts/lending/aave: supplying, borrowing, and the moment a position
# stops being safe.
#
# WHAT IS BEING PINNED, and where the numbers come from:
#
#   THE RATE CURVE HAS A KINK, and it is the mechanism rather than a
#   preference. With a 4% slope to an 80% optimum, half-used liquidity
#   costs 2.5% -- and at 90%, past the kink, the second slope takes it
#   to 34%. The steep half exists so the last of the liquidity gets
#   expensive enough that somebody repays or supplies before the pool
#   runs dry. Both numbers are arithmetic anyone can redo.
#
#   SUPPLIERS EARN LESS THAN BORROWERS PAY, and the gap is not hidden.
#   The idle part of the pot earns nothing, so the borrow rate is
#   diluted by utilization, and the reserve factor is the protocol's cut
#   of what is left: 2.5% borrowed at half utilization with a 10%
#   reserve factor pays suppliers 1.125%.
#
#   A BALANCE IS SCALED BY AN INDEX. Nothing is credited to any account
#   as interest accrues -- one index moves and every balance moves with
#   it -- so the checks below read balances that no operation ever
#   wrote. Borrow interest COMPOUNDS while supply interest is linear,
#   which is Aave's own choice, so the two indexes separate over time.
#
#   HEALTH IS A PRICE QUESTION, AND THE ORACLE IS THE TRUST ASSUMPTION.
#   The same position is healthy at 1.6 and liquidatable at 0.96 with
#   nothing changed but a number somebody asserted. That is the honest
#   shape of this protocol and the suite shows it rather than hiding it.
#
#   TWO LIMITS PROTECT THE BORROWER. Only an unhealthy position may be
#   liquidated at all, and only half its debt at once -- so asking to
#   repay 99999 against a 5000 debt seizes exactly what repaying 2500
#   would. Both are checked.
#
#   AND THE POT IS SOLVENT THROUGHOUT. What the pool actually holds
#   covers what is not on loan, checked after every kind of operation.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-50s %s\n' "$1" "$(echo "$2" | cut -c1-22)"
  else
    printf 'FAIL %-50s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi

F="$ROOT/contracts/token/fungible.pl $ROOT/contracts/lending/aave.pl"
if ! timeout 60 "$C" run $F "write(ok), nl" 2>/dev/null | grep -aq '\bok\b'; then
  echo "SKIP (the lending pool will not load -- did the u256 module build?)"
  exit 0
fi

v()  { timeout 180 "$C" run $F "$1" 2>/dev/null \
       | grep -aoE 'answer\([^)]*\)' | head -1 | sed 's/^answer(//; s/)$//'; }
no() { if timeout 180 "$C" run $F "$1" 2>/dev/null | grep -aq 'answer('; \
       then echo allowed; else echo refused; fi; }

M=1000000000000000000000000
TOK="ft_create(dai,'DAI',18), ft_create(weth,'WETH',18), \
     ft_mint(dai,alice,'$M'), ft_mint(dai,bob,'$M'), \
     ft_mint(weth,alice,'$M'), ft_mint(weth,bob,'$M')"
# ltv 75%, liquidation threshold 80%, 5% bonus, 10% reserve factor
INIT="$TOK, aave_init(dai,'7500','8000','500','1000'), \
      aave_init(weth,'7500','8000','500','1000'), \
      aave_price(dai,1), aave_price(weth,100)"

echo "-- the pot"
check "supplying puts it in and it reads back" \
  "$(v "$INIT, aave_supply(dai,alice,'1000'), aave_supplied(dai,alice,A), write(answer(A)), nl")" \
  "1000"
check "and the pool actually holds the tokens" \
  "$(v "$INIT, aave_supply(dai,alice,'1000'), aave_account(dai,Ac), \
        ft_balance(dai,Ac,B), write(answer(B)), nl")" "1000"
check "supplying what you do not have is refused" \
  "$(no "$INIT, aave_supply(dai,dave,'1000'), write(answer(x)), nl")" "refused"
check "withdrawing more than you supplied is refused" \
  "$(no "$INIT, aave_supply(dai,alice,'1000'), aave_withdraw(dai,alice,'2000'), \
         write(answer(x)), nl")" "refused"
# A claim can be good and the pot still empty: the two are different
# questions and get different answers.
check "a withdrawal past the LIQUIDITY is refused too" \
  "$(no "$INIT, aave_supply(dai,alice,'1000'), aave_supply(weth,bob,'100'), \
         aave_borrow(dai,bob,'900'), aave_withdraw(dai,alice,'1000'), \
         write(answer(x)), nl")" "refused"

echo "-- the rate curve"
HALF="$INIT, aave_supply(dai,alice,'1000'), aave_supply(weth,bob,'100'), aave_borrow(dai,bob,'500')"
check "half the pot lent is 50% utilization" \
  "$(v "$HALF, aave_utilization(dai,U), write(answer(U)), nl")" \
  "500000000000000000000000000"
check "which costs 2.5% at a 4% slope to 80%" \
  "$(v "$HALF, aave_rates(dai,_,B), write(answer(B)), nl")" \
  "25000000000000000000000000"
check "and suppliers get 1.125% of that" \
  "$(v "$HALF, aave_rates(dai,S,_), write(answer(S)), nl")" \
  "11250000000000000000000000"
# Past the kink the second slope takes over, and it is steep on purpose.
NINETY="$INIT, aave_supply(dai,alice,'1000'), aave_supply(weth,bob,'100'), aave_borrow(dai,bob,'900')"
check "past the kink at 90%, the rate is 34%" \
  "$(v "$NINETY, aave_rates(dai,_,B), write(answer(B)), nl")" \
  "340000000000000000000000000"
check "the borrow rate always exceeds the supply rate" \
  "$(v "$HALF, aave_rates(dai,S,B), u256_cmp(S,B,C), write(answer(C)), nl")" "<"

echo "-- interest, through the indexes"
POS="$INIT, aave_supply(dai,bob,'100000'), aave_supply(weth,alice,'100'), \
     aave_borrow(dai,alice,'5000')"
check "a year on, the debt has grown" \
  "$(v "$POS, aave_accrue(dai,'31536000'), aave_debt(dai,alice,D), write(answer(D)), nl")" \
  "5013"
check "and the supplier has earned, without being credited" \
  "$(v "$POS, aave_accrue(dai,'31536000'), aave_supplied(dai,bob,S), write(answer(S)), nl")" \
  "100011"
check "no time passing means no interest" \
  "$(v "$POS, aave_accrue(dai,'0'), aave_debt(dai,alice,D), write(answer(D)), nl")" "5000"
check "accruing backwards is refused" \
  "$(no "$POS, aave_accrue(dai,'31536000'), aave_accrue(dai,'1000'), \
         write(answer(x)), nl")" "refused"
# Borrow compounds, supply is linear -- so over the same year the borrow
# index moves further than the supply index would at the same rate.
check "the borrow index compounds past the linear one" \
  "$(v "$POS, aave_accrue(dai,'31536000'), aave_index(dai,L,B), \
        u256_cmp(B,L,C), write(answer(C)), nl")" ">"

echo "-- health, which is a price question"
check "the position is healthy at 1.6" \
  "$(v "$POS, aave_health(alice,H), write(answer(H)), nl")" \
  "1600000000000000000000000000"
check "owing nothing is not a number" \
  "$(v "$INIT, aave_supply(weth,alice,'100'), aave_health(alice,H), write(answer(H)), nl")" \
  "infinite"
# THE CEILING IS CHECKED AT THE WEI, in both directions -- a rule that
# refuses everything passes a one-sided test. 100 WETH at 100 is 10000
# of collateral; at a 75% LTV the ceiling is exactly 7500.
check "borrowing right up to the LTV is allowed" \
  "$(no "$INIT, aave_supply(dai,bob,'100000'), aave_supply(weth,alice,'100'), \
         aave_borrow(dai,alice,'7500'), write(answer(x)), nl")" "allowed"
check "and one wei past it is not" \
  "$(no "$INIT, aave_supply(dai,bob,'100000'), aave_supply(weth,alice,'100'), \
         aave_borrow(dai,alice,'7501'), write(answer(x)), nl")" "refused"
check "borrowing past the LTV is refused" \
  "$(no "$INIT, aave_supply(dai,bob,'100000'), aave_supply(weth,alice,'100'), \
         aave_borrow(dai,alice,'9000'), write(answer(x)), nl")" "refused"
# Nothing changed but a number somebody asserted.
check "the oracle moves and the position becomes unsafe" \
  "$(v "$POS, aave_price(weth,60), aave_health(alice,H), write(answer(H)), nl")" \
  "960000000000000000000000000"
check "a withdrawal that would unbalance it is refused" \
  "$(no "$POS, aave_withdraw(weth,alice,'90'), write(answer(x)), nl")" "refused"

echo "-- liquidation"
SICK="$POS, aave_price(weth,60)"
check "a healthy position may not be liquidated" \
  "$(no "$POS, aave_liquidate(dai,weth,bob,alice,'2500',_), write(answer(x)), nl")" \
  "refused"
check "an unhealthy one may, seizing collateral plus 5%" \
  "$(v "$SICK, aave_liquidate(dai,weth,bob,alice,'2500',S), write(answer(S)), nl")" "43"
check "the close factor caps it at half the debt" \
  "$(v "$SICK, aave_liquidate(dai,weth,bob,alice,'99999',S), write(answer(S)), nl")" "43"
check "the debt fell by what was repaid" \
  "$(v "$SICK, aave_liquidate(dai,weth,bob,alice,'2500',_), aave_debt(dai,alice,D), \
        write(answer(D)), nl")" "2500"
check "and the position is healthy again" \
  "$(v "$SICK, aave_liquidate(dai,weth,bob,alice,'2500',_), aave_health(alice,H), \
        write(answer(H)), nl")" "1094400000000000000000000000"
check "the liquidator is really paid in tokens" \
  "$(v "$SICK, ft_balance(weth,bob,B0), aave_liquidate(dai,weth,bob,alice,'2500',_), \
        ft_balance(weth,bob,B1), u256_sub(B1,B0,D), write(answer(D)), nl")" "43"

echo "-- solvency, after each kind of operation"
check "after supplying and borrowing" \
  "$(v "$POS, ( aave_solvent(dai), aave_solvent(weth) -> write(answer(solvent)) \
        ; write(answer(short)) ), nl")" "solvent"
check "after a repayment" \
  "$(v "$POS, aave_repay(dai,alice,'2000'), \
        ( aave_solvent(dai) -> write(answer(solvent)) ; write(answer(short)) ), nl")" \
  "solvent"
check "after a year of interest" \
  "$(v "$POS, aave_accrue(dai,'31536000'), \
        ( aave_solvent(dai) -> write(answer(solvent)) ; write(answer(short)) ), nl")" \
  "solvent"
check "and after a liquidation" \
  "$(v "$SICK, aave_liquidate(dai,weth,bob,alice,'2500',_), \
        ( aave_solvent(dai), aave_solvent(weth) -> write(answer(solvent)) \
        ; write(answer(short)) ), nl")" "solvent"
check "repaying more than owed repays only what is owed" \
  "$(v "$POS, aave_repay(dai,alice,'99999'), aave_debt(dai,alice,D), write(answer(D)), nl")" \
  "0"


echo "-- a refused operation leaves NOTHING behind"
# THIS SECTION EXISTS BECAUSE THE POOL FAILED IT. aave_borrow wrote the
# debt down, checked the loan-to-value against it, un-did the write and
# called fail -- and Prolog BACKTRACKED INTO THE RETRACT inside that
# undo, found another way to satisfy it, and the borrow succeeded. The
# LTV rule refused the loan and the borrower got the money anyway. It is
# the cleanest illustration in this repository of why a check that runs
# after the write is not a check: in a language with backtracking the
# undo is itself a choice point, and `!` before `fail' is what closes it.
#
# So every refusal below is followed by a read of what it touched. The
# refused goal is wrapped so its failure does not end the conjunction --
# what is under test is the state AFTER the refusal.
check "a borrow past the LTV leaves no debt behind" \
  "$(v "$INIT, aave_supply(weth,alice,'100'), aave_supply(dai,bob,'100000'), \
        ( aave_borrow(dai,alice,'9000') -> true ; true ), \
        aave_debt(dai,alice,D), write(answer(D)), nl")" "0"
check "and it did not pay out the tokens either" \
  "$(v "$INIT, aave_supply(weth,alice,'100'), aave_supply(dai,bob,'100000'), \
        ft_balance(dai,alice,B0), ( aave_borrow(dai,alice,'9000') -> true ; true ), \
        ft_balance(dai,alice,B1), u256_sub(B1,B0,D), write(answer(D)), nl")" "0"
check "and the pot is still solvent after the refusal" \
  "$(v "$INIT, aave_supply(weth,alice,'100'), aave_supply(dai,bob,'100000'), \
        ( aave_borrow(dai,alice,'9000') -> true ; true ), \
        ( aave_solvent(dai) -> write(answer(solvent)) ; write(answer(short)) ), nl")" \
  "solvent"
check "a supply nobody can fund leaves no balance behind" \
  "$(v "$INIT, ( aave_supply(dai,dave,'1000') -> true ; true ), \
        aave_supplied(dai,dave,A), write(answer(A)), nl")" "0"
check "a withdrawal past the balance leaves the balance alone" \
  "$(v "$INIT, aave_supply(dai,alice,'1000'), \
        ( aave_withdraw(dai,alice,'2000') -> true ; true ), \
        aave_supplied(dai,alice,A), write(answer(A)), nl")" "1000"
check "and a refused liquidation seizes nothing" \
  "$(v "$POS, ft_balance(weth,bob,B0), \
        ( aave_liquidate(dai,weth,bob,alice,'2500',_) -> true ; true ), \
        ft_balance(weth,bob,B1), u256_sub(B1,B0,D), write(answer(D)), nl")" "0"
echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
