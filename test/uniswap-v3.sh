#!/bin/sh
# contracts/dex/uniswap-v3: concentrated liquidity, and positions that
# are non-fungible tokens.
#
# WHAT IS BEING PINNED, and where the numbers come from:
#
#   THE TICK MATH IS UNISWAP'S, CONSTANT FOR CONSTANT. tick 0 is price
#   1, so its sqrt ratio is exactly 2^96 = 79228162514264337593543950336,
#   and the two ends of the axis are the values TickMath.sol publishes:
#   MIN_SQRT_RATIO 4295128739 and MAX_SQRT_RATIO
#   1461446703485210103287273052203988822378723970342. Nothing here
#   computed those three; they are what the library says, and getting
#   any of the twenty magic constants wrong moves them.
#
#   A SYMMETRIC RANGE COSTS THE SAME OF BOTH. A position over ticks
#   -60..60 with the price at tick 0 needs equal amounts of token0 and
#   token1, which is a fact about the curve rather than about this
#   code -- and an implementation with the two formulas swapped, or the
#   reciprocal taken the wrong way, fails it immediately.
#
#   THE POSITION IS AN NFT, AND OWNERSHIP IS THE TOKEN'S. Minting one
#   mints an id in the pool's own collection; the owner reported by the
#   position is the owner the collection says, so a position that has
#   been sold reports its new owner without anything here being
#   updated. Only whoever the token authorises may close it.
#
#   AND v3 AGREES WITH v2 ON THE CURVE. A v3 pool of L = 10^18 at price
#   1 is a v2 pool of 10^18 against 10^18, so swapping a thousandth of
#   the depth must pay a thousandth of what v2 pays: v2's
#   996006981039903216 against v3's 996006981039903, which is that
#   number divided by a thousand and floored. Two engines written
#   differently, one curve.
#
#   CROSSING A TICK CHANGES THE DEPTH, and that is what makes a range a
#   range. Two positions, one narrow and one wide: a trade big enough
#   walks out of the narrow one, the liquidity halves as it crosses, and
#   the rest of the trade is priced against what is left. The whole
#   crossing swap is checked against an independent implementation of
#   Uniswap's own SwapMath -- output, unspent, resulting tick, resulting
#   liquidity and fee growth, all five.
#
#   FEES BELONG TO THE RANGES THAT EARNED THEM. Two equal positions both
#   in range earn equally; after a trade that walks one of them out of
#   range, the one that stayed earns more. AND THE TWO SUM TO EXACTLY
#   WHAT WAS CHARGED -- 0.3% of the input, to the wei -- which is the
#   conservation law of the fee accounting and the one check that would
#   catch a slow leak.

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

F="$ROOT/contracts/token/fungible.pl $ROOT/contracts/token/nonfungible.pl \
   $ROOT/contracts/dex/uniswap-v3.pl"
if ! timeout 60 "$C" run $F "write(ok), nl" 2>/dev/null | grep -aq '\bok\b'; then
  echo "SKIP (the v3 pool will not load -- did the u256 module build?)"
  exit 0
fi

v()  { timeout 180 "$C" run $F "$1" 2>/dev/null \
       | grep -aoE 'answer\([^)]*\)' | head -1 | sed 's/^answer(//; s/)$//'; }
no() { if timeout 180 "$C" run $F "$1" 2>/dev/null | grep -aq 'answer('; \
       then echo allowed; else echo refused; fi; }

echo "-- the tick axis"
check "tick 0 is price 1, so its ratio is 2^96" \
  "$(v "tm_sqrt_ratio_at_tick(0,S), write(answer(S)), nl")" \
  "79228162514264337593543950336"
check "the bottom of the axis is MIN_SQRT_RATIO" \
  "$(v "tm_min_tick(T), tm_sqrt_ratio_at_tick(T,S), write(answer(S)), nl")" \
  "4295128739"
check "and the top is MAX_SQRT_RATIO" \
  "$(v "tm_max_tick(T), tm_sqrt_ratio_at_tick(T,S), write(answer(S)), nl")" \
  "1461446703485210103287273052203988822378723970342"
check "one tick up is one basis point up" \
  "$(v "tm_sqrt_ratio_at_tick(1,S), write(answer(S)), nl")" \
  "79232123823359799118286999568"
check "and one tick down is its reciprocal side" \
  "$(v "tm_sqrt_ratio_at_tick(-1,S), write(answer(S)), nl")" \
  "79224201403219477170569942574"
check "a tick past the end is not a price" \
  "$(no "tm_sqrt_ratio_at_tick(887273,S), write(answer(S)), nl")" "refused"

echo "-- positions"
TOK="ft_create(dai,'DAI',18), ft_create(weth,'WETH',18), \
     ft_mint(dai,alice,'1000000000000000000000000'), ft_mint(weth,alice,'1000000000000000000000000'), \
     ft_mint(dai,bob,'1000000000000000000000000'), ft_mint(weth,bob,'1000000000000000000000000'), \
     ft_mint(dai,carol,'1000000000000000000000000'), ft_mint(weth,carol,'1000000000000000000000000')"
MK="$TOK, v3_create(p,dai,weth,3000,0), v3_mint(p,alice,-60,60,'1000000000000000000',Id,A0,A1)"
check "a symmetric range needs equal token0" \
  "$(v "$MK, write(answer(A0)), nl")" "2995354955910780"
check "and equal token1" \
  "$(v "$MK, write(answer(A1)), nl")" "2995354955910780"
check "the position is minted as an NFT" \
  "$(v "$MK, nft_owner(p,Id,O), write(answer(O)), nl")" "alice"
check "and its owner is the token's owner" \
  "$(v "$MK, v3_position(Id,_,O,_,_,_), write(answer(O)), nl")" "alice"
check "selling the position moves who owns it" \
  "$(v "$MK, nft_transfer_from(p,alice,alice,bob,Id), \
        v3_position(Id,_,O,_,_,_), write(answer(O)), nl")" "bob"
check "a range above the price is all token0" \
  "$(v "$TOK, v3_create(p,dai,weth,3000,0), \
        v3_mint(p,alice,600,1200,'1000000000000000000',_,_,A1x), \
        write(answer(A1x)), nl")" "0"
check "a range below it is all token1" \
  "$(v "$TOK, v3_create(p,dai,weth,3000,0), \
        v3_mint(p,alice,-1200,-600,'1000000000000000000',_,A0x,_), \
        write(answer(A0x)), nl")" "0"
check "out-of-range liquidity is not depth" \
  "$(v "$TOK, v3_create(p,dai,weth,3000,0), \
        v3_mint(p,alice,600,1200,'1000000000000000000',_,_,_), \
        v3_active_liquidity(p,L), write(answer(L)), nl")" "0"
check "in-range liquidity is" \
  "$(v "$MK, v3_active_liquidity(p,L), write(answer(L)), nl")" "1000000000000000000"
check "an inverted range is refused" \
  "$(no "$TOK, v3_create(p,dai,weth,3000,0), v3_mint(p,alice,60,-60,'1000',I,_,_), \
         write(answer(I)), nl")" "refused"
check "a fee tier nobody routes through is refused" \
  "$(no "$TOK, v3_create(p,dai,weth,1234,0), write(answer(x)), nl")" "refused"

echo "-- swapping, within one range"
M2="$TOK, v3_create(p,dai,weth,3000,0), v3_mint(p,alice,-60,60,'1000000000000000000',_,_,_)"
check "a swap pays what the curve says" \
  "$(v "$M2, v3_swap(p,bob,weth,'1000000000000000',Out,_), write(answer(Out)), nl")" \
  "996006981039903"
check "and v2 pays a thousand times that, on the same curve" \
  "$(timeout 180 "$C" run "$ROOT/contracts/dex/uniswap.pl" \
      "uni_amount_out('1000000000000000000','1000000000000000000000','1000000000000000000000',X), \
       write(answer(X)), nl" 2>/dev/null | grep -aoE 'answer\([0-9]+\)' | head -1 \
       | sed 's/answer(//; s/)//')" \
  "996006981039903216"
check "the price moved up and stayed in the range" \
  "$(v "$M2, v3_swap(p,bob,weth,'1000000000000000',_,_), v3_price(p,S,_), write(answer(S)), nl")" \
  "79307152992291059138124713654"
check "the other direction moves it down" \
  "$(v "$M2, v3_swap(p,bob,dai,'1000000000000000',_,_), v3_price(p,S,_), \
        ( u256_cmp(S,'79228162514264337593543950336','<') -> write(answer(down)) \
        ; write(answer(up)) ), nl")" "down"

echo "-- crossing ticks"
# Two ranges: alice narrow, bob wide, equal liquidity. A trade big
# enough walks out of alice's and the depth halves under it. Every
# number here comes from an independent implementation of Uniswap's
# SwapMath, not from this one.
MX="$TOK, v3_create(p,dai,weth,3000,0), \
    v3_mint(p,alice,-60,60,'1000000000000000000',A,_,_), \
    v3_mint(p,bob,-600,600,'1000000000000000000',B,_,_)"
check "two ranges over the price stack their depth" \
  "$(v "$MX, v3_liq(p,L), write(answer(L)), nl")" "2000000000000000000"
check "a crossing swap pays what the reference says" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',Out,_), write(answer(Out)), nl")" \
  "9912816306615178"
check "and spends all of it" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',_,U), write(answer(U)), nl")" "0"
check "the price ends at the tick it crossed" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',_,_), v3_price(p,_,T), write(answer(T)), nl")" \
  "60"
check "and the depth halved, because a range ended" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',_,_), v3_liq(p,L), write(answer(L)), nl")" \
  "1000000000000000000"
check "fee growth matches the reference too" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',_,_), v3_fg(p,_,G), write(answer(G)), nl")" \
  "7132256228676415841154124566172760"
# A gap is not a wall: the walk moves to where the liquidity starts.
GAP="$TOK, v3_create(p,dai,weth,3000,0), v3_mint(p,alice,600,1200,'1000000000000000000',_,_,_)"
check "a swap reaches liquidity across a gap" \
  "$(v "$GAP, v3_swap(p,bob,weth,'1000000000000000',Out,_), write(answer(Out)), nl")" \
  "938034474824077"
check "and the price got to where the range starts" \
  "$(v "$GAP, v3_swap(p,bob,weth,'1000000000000000',_,_), v3_price(p,_,T), write(answer(T)), nl")" \
  "600"
# A range holds a finite amount. Ask for more and the pool pays what it
# has and HANDS BACK the rest rather than swallowing it.
check "a swap past all the liquidity pays out what there was" \
  "$(v "$M2, v3_swap(p,bob,weth,'100000000000000000',Out,_), write(answer(Out)), nl")" \
  "2995354955910780"
check "and returns the rest unspent" \
  "$(v "$M2, v3_swap(p,bob,weth,'100000000000000000',_,U), write(answer(U)), nl")" \
  "96986605754521638"

echo "-- fees, and whose they are"
check "two equal ranges, both in range, earn equally" \
  "$(v "$MX, v3_swap(p,bob,weth,'1000000000000000',_,_), \
        v3_fees_owed(A,_,FA), v3_fees_owed(B,_,FB), \
        ( u256_cmp(FA,FB,'=') -> write(answer(equal)) ; write(answer(FA-FB)) ), nl")" \
  "equal"
check "after a crossing, the one that stayed earns more" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',_,_), \
        v3_fees_owed(A,_,FA), v3_fees_owed(B,_,FB), \
        u256_cmp(FA,FB,C), write(answer(C)), nl")" "<"
# The conservation law of the fee accounting: what the positions are
# owed sums to what the trade was charged, to the wei.
check "and the two sum to exactly the 0.3% charged" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',_,_), \
        v3_fees_owed(A,_,FA), v3_fees_owed(B,_,FB), u256_add(FA,FB,S), \
        write(answer(S)), nl")" "30000000000000"
check "a position opened after the trade earns nothing from it" \
  "$(v "$MX, v3_swap(p,bob,weth,'1000000000000000',_,_), \
        v3_mint(p,carol,-60,60,'1000000000000000000',Cid,_,_), \
        v3_fees_owed(Cid,_,F), write(answer(F)), nl")" "0"
check "collecting hands them over and zeroes the debt" \
  "$(v "$MX, v3_swap(p,bob,weth,'1000000000000000',_,_), v3_collect(A,alice,_,_), \
        v3_fees_owed(A,_,F), write(answer(F)), nl")" "0"
check "collecting twice does not pay twice" \
  "$(v "$MX, v3_swap(p,bob,weth,'1000000000000000',_,_), v3_collect(A,alice,_,_), \
        v3_collect(A,alice,_,F), write(answer(F)), nl")" "0"
check "and a stranger may not collect" \
  "$(no "$MX, v3_swap(p,bob,weth,'1000000000000000',_,_), \
         v3_collect(A,mallory,_,F), write(answer(F)), nl")" "refused"

echo "-- closing"
check "only the token's owner may close the position" \
  "$(no "$MK, v3_burn(p,mallory,Id,_,_,_,_), write(answer(x)), nl")" "refused"
check "the owner may, and gets the range back" \
  "$(v "$MK, v3_burn(p,alice,Id,B0,_,_,_), write(answer(B0)), nl")" "2995354955910780"
check "closing pays out the fees it earned" \
  "$(v "$MX, v3_swap(p,bob,weth,'1000000000000000',_,_), \
        v3_burn(p,alice,A,_,_,_,F1), write(answer(F1)), nl")" "1499999999999"
check "and the position token is gone with it" \
  "$(no "$MK, v3_burn(p,alice,Id,_,_,_,_), nft_owner(p,Id,_), write(answer(x)), nl")" "refused"
check "closing a range frees its ticks as boundaries" \
  "$(v "$MX, v3_burn(p,alice,A,_,_,_,_), v3_liq(p,L), write(answer(L)), nl")" \
  "1000000000000000000"
# The maintained liquidity is a second copy of a fact -- the kind that
# goes stale silently. This is the derivation, checked against it after
# the operations most likely to disagree.
check "the kept liquidity agrees with the positions" \
  "$(v "$MX, ( v3_liquidity_agrees(p) -> write(answer(agrees)) ; write(answer(drifted)) ), nl")" \
  "agrees"
check "and still agrees after crossing a tick" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',_,_), \
        ( v3_liquidity_agrees(p) -> write(answer(agrees)) ; write(answer(drifted)) ), nl")" \
  "agrees"
check "and after crossing back down again" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',_,_), \
        v3_swap(p,bob,dai,'10000000000000000',_,_), \
        ( v3_liquidity_agrees(p) -> write(answer(agrees)) ; write(answer(drifted)) ), nl")" \
  "agrees"
check "and after a burn" \
  "$(v "$MX, v3_burn(p,alice,A,_,_,_,_), \
        ( v3_liquidity_agrees(p) -> write(answer(agrees)) ; write(answer(drifted)) ), nl")" \
  "agrees"

echo "-- and the tokens are real"
# Opening a position MOVES the two amounts; a swap moves the input in
# and the output out; collecting and closing move them back. A position
# or a trade nobody can fund fails at the ledger, not at a check here.
check "the deposit actually leaves the provider" \
  "$(v "$MK, ft_balance(dai,alice,B), u256_sub('1000000000000000000000000',B,D), write(answer(D)), nl")" \
  "2995354955910780"
check "and the pool actually holds it" \
  "$(v "$MK, v3_account(p,Ac), ft_balance(dai,Ac,B), write(answer(B)), nl")" \
  "2995354955910780"
check "a position nobody can fund is refused" \
  "$(no "$MK, v3_mint(p,dave,-60,60,'1000000000000000000',I,_,_), write(answer(I)), nl")" \
  "refused"
check "a swap pays the trader in actual tokens" \
  "$(v "$M2, v3_swap(p,bob,weth,'1000000000000000',_,_), ft_balance(dai,bob,B), \
        u256_sub(B,'1000000000000000000000000',D), write(answer(D)), nl")" "996006981039903"
check "a swap nobody can fund is refused" \
  "$(no "$M2, v3_swap(p,dave,weth,'1000',O,_), write(answer(O)), nl")" "refused"
check "collecting fees pays out real tokens" \
  "$(v "$MK, v3_swap(p,bob,weth,'1000000000000000',_,_), \
        ft_balance(weth,alice,B0), v3_collect(Id,alice,_,_), \
        ft_balance(weth,alice,B1), u256_sub(B1,B0,D), write(answer(D)), nl")" \
  "2999999999999"
# The question that matters after all of it: does the pool hold what it
# has promised -- every position's amounts plus every position's
# unclaimed fees?
check "the pool is backed after a swap" \
  "$(v "$MX, v3_swap(p,bob,weth,'1000000000000000',_,_), \
        ( v3_backed(p) -> write(answer(backed)) ; write(answer(short)) ), nl")" "backed"
check "and after one that crossed a tick" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',_,_), \
        ( v3_backed(p) -> write(answer(backed)) ; write(answer(short)) ), nl")" "backed"
check "and after the fees are taken out of it" \
  "$(v "$MX, v3_swap(p,bob,weth,'10000000000000000',_,_), \
        v3_collect(A,alice,_,_), v3_collect(B,bob,_,_), \
        ( v3_backed(p) -> write(answer(backed)) ; write(answer(short)) ), nl")" "backed"


echo "-- a refused operation leaves NOTHING behind"
# THIS SECTION EXISTS BECAUSE THE POOL FAILED IT. v3_mint used to move
# the ticks, the pool's liquidity and the NFT into place and pay for
# them afterwards, so a mint nobody could fund raised the pool's active
# liquidity to 1e18 with no position anywhere backing it -- and every
# later swap priced itself off depth that did not exist. The invariant
# that caught it is v3_liquidity_agrees/1: the pool's own liquidity
# against the sum of the positions that span the current price. A
# contract is not "safe because the operation was refused"; it is safe
# because the refusal left the state where it found it.
#
# The refused goal is wrapped so its failure does not end the
# conjunction -- what is under test is what comes AFTER the refusal.
check "a mint nobody can fund does not raise the depth" \
  "$(v "$MK, ( v3_mint(p,dave,-60,60,'1000000000000000000',_,_,_) -> true ; true ), \
        v3_state(p,_,_,L), write(answer(L)), nl")" "1000000000000000000"
check "and the liquidity still agrees with the positions" \
  "$(v "$MK, ( v3_mint(p,dave,-60,60,'1000000000000000000',_,_,_) -> true ; true ), \
        ( v3_liquidity_agrees(p) -> write(answer(agrees)) ; write(answer(drifted)) ), nl")" \
  "agrees"
check "and no position was minted for the payer who could not pay" \
  "$(no "$MK, ( v3_mint(p,dave,-60,60,'1000000000000000000',_,_,_) -> true ; true ), \
         v3_position(_,_,dave,_,_,_), write(answer(found)), nl")" "refused"
check "a swap nobody can fund does not move the price" \
  "$(v "$MK, v3_state(p,S0,_,_), ( v3_swap(p,dave,weth,'1000',_,_) -> true ; true ), \
        v3_state(p,S1,_,_), ( S0 == S1 -> write(answer(still)) ; write(answer(moved)) ), nl")" \
  "still"
check "and the pool is still backed after the refusal" \
  "$(v "$MK, ( v3_mint(p,dave,-60,60,'1000000000000000000',_,_,_) -> true ; true ), \
        ( v3_backed(p) -> write(answer(backed)) ; write(answer(short)) ), nl")" "backed"
echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
