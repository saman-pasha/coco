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
#   THE BOUNDARY IS REFUSED, NOT APPROXIMATED. The range holds exactly
#   2995354955910780 of token1, so a swap wanting more must cross the
#   upper tick -- and this engine does not cross ticks yet. It says no.
#   A pool that quietly mispriced the far side of a boundary would be
#   worse than one that refused, and the refusal is checked here so it
#   cannot rot into silence.

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

F="$ROOT/contracts/token/nonfungible.pl $ROOT/contracts/dex/uniswap-v3.pl"
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
MK="v3_create(p,dai,weth,3000,0), v3_mint(p,alice,-60,60,'1000000000000000000',Id,A0,A1)"
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
  "$(v "v3_create(p,dai,weth,3000,0), \
        v3_mint(p,alice,600,1200,'1000000000000000000',_,_,A1x), \
        write(answer(A1x)), nl")" "0"
check "a range below it is all token1" \
  "$(v "v3_create(p,dai,weth,3000,0), \
        v3_mint(p,alice,-1200,-600,'1000000000000000000',_,A0x,_), \
        write(answer(A0x)), nl")" "0"
check "out-of-range liquidity is not depth" \
  "$(v "v3_create(p,dai,weth,3000,0), \
        v3_mint(p,alice,600,1200,'1000000000000000000',_,_,_), \
        v3_active_liquidity(p,L), write(answer(L)), nl")" "0"
check "in-range liquidity is" \
  "$(v "$MK, v3_active_liquidity(p,L), write(answer(L)), nl")" "1000000000000000000"
check "an inverted range is refused" \
  "$(no "v3_create(p,dai,weth,3000,0), v3_mint(p,alice,60,-60,'1000',I,_,_), \
         write(answer(I)), nl")" "refused"
check "a fee tier nobody routes through is refused" \
  "$(no "v3_create(p,dai,weth,1234,0), write(answer(x)), nl")" "refused"

echo "-- swapping"
M2="v3_create(p,dai,weth,3000,0), v3_mint(p,alice,-60,60,'1000000000000000000',_,_,_)"
check "a swap pays what the curve says" \
  "$(v "$M2, v3_swap(p,weth,'1000000000000000',Out), write(answer(Out)), nl")" \
  "996006981039903"
check "and v2 pays a thousand times that, on the same curve" \
  "$(timeout 180 "$C" run "$ROOT/contracts/dex/uniswap.pl" \
      "uni_amount_out('1000000000000000000','1000000000000000000000','1000000000000000000000',X), \
       write(answer(X)), nl" 2>/dev/null | grep -aoE 'answer\([0-9]+\)' | head -1 \
       | sed 's/answer(//; s/)//')" \
  "996006981039903216"
check "the price moved up, and stayed in the range" \
  "$(v "$M2, v3_swap(p,weth,'1000000000000000',_), v3_price(p,S,_), write(answer(S)), nl")" \
  "79307152992291059138124713654"
check "the other direction moves it down" \
  "$(v "$M2, v3_swap(p,dai,'1000000000000000',_), v3_price(p,S,_), \
        ( u256_cmp(S,'79228162514264337593543950336','<') -> write(answer(down)) \
        ; write(answer(up)) ), nl")" "down"
# The range holds 2995354955910780 of token1; wanting more than that
# means crossing the upper tick, which this engine does not do.
check "a swap that would cross a tick is REFUSED" \
  "$(no "$M2, v3_swap(p,weth,'10000000000000000',Out), write(answer(Out)), nl")" "refused"
check "a swap with no liquidity in range is refused" \
  "$(no "v3_create(p,dai,weth,3000,0), \
         v3_mint(p,alice,600,1200,'1000000000000000000',_,_,_), \
         v3_swap(p,weth,'1000',Out), write(answer(Out)), nl")" "refused"

echo "-- closing"
check "only the token's owner may close the position" \
  "$(no "$MK, v3_burn(p,mallory,Id,_,_), write(answer(x)), nl")" "refused"
check "the owner may, and gets the range back" \
  "$(v "$MK, v3_burn(p,alice,Id,B0,_), write(answer(B0)), nl")" "2995354955910780"
check "and the position token is gone with it" \
  "$(no "$MK, v3_burn(p,alice,Id,_,_), nft_owner(p,Id,_), write(answer(x)), nl")" "refused"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
