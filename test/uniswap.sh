#!/bin/sh
# contracts/dex/uniswap: a constant-product pool as rules, and mallory at it.
#
# WHAT IS BEING PINNED, and where the numbers come from:
#
#   THE QUOTE IS UNISWAP'S. One token into a thousand-for-a-thousand
#   pool pays 996006981039903216 at a 0.3% fee. The Coco did not invent
#   that number -- it is what the constant-product formula pays, quoted
#   wherever the formula is explained, and reproducible in any language
#   with wide integers. Three independent implementations agree on it:
#   library(u256)'s fixed-width limbs (which the pool is built on),
#   cocolog's library(bigint) over Zigurat's arbitrary-precision
#   BigInt, and Python's own integers.
#
#   AND IT IS ITS OWN INVERSE. Asking what input buys that exact output
#   returns the input we started with. A formula that is not its own
#   inverse leaks value on every round trip, and the leak is invisible
#   in a single direction.
#
#   THE INVARIANT IS CHECKED, NOT TRUSTED. `uni_swap/4' recomputes k on
#   the reserves that actually landed and refuses if it fell. The
#   formula is right; the check is what makes the pool checkable by
#   someone who does not believe the formula.
#
#   MINIMUM_LIQUIDITY IS REAL. The first deposit mints sqrt(a0*a1)
#   MINUS a thousand units that are burned to nobody -- v2's answer to
#   the donation attack -- so the depositor's own balance is short by
#   exactly that, and the pool can never be emptied.
#
#   ROUNDING ALWAYS FAVOURS THE POOL. Deposit, withdraw the whole share
#   back, and you do not come out ahead: what the floors dropped stays
#   with the pool. That is the direction every truncation in the
#   library goes, and a pool that rounded the other way could be
#   drained a wei at a time.
#
#   MONEY IS u256. Balances, prices and amounts are 256 bits wide
#   throughout The Coco, and NOTHING IN THEM WRAPS -- an operation that
#   cannot represent its answer raises, the way Solidity 0.8 made
#   overflow revert. v2's own uint112 reserve ceiling is enforced too,
#   because that ceiling is WHY v2's products cannot overflow a word.
#
#   AND THE ARITHMETIC IS NOT `is/2'. The first check asserts cocolog's
#   64-bit multiply giving the WRONG answer for the first product a
#   swap computes. A pool built on it would quote confidently wrong
#   prices and check its invariant against the same wrong numbers.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-46s %s\n' "$1" "$(echo "$2" | cut -c1-26)"
  else
    printf 'FAIL %-46s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi

# THE CONTRACT IS REACHED BY PATH, not by library(Name): it lives under
# contracts/, categorised, because it is a thing deployed on a chain
# rather than machinery The Coco offers. library/ holds the fence and
# the money type; a pool is neither.
CONTRACT="$ROOT/contracts/dex/uniswap.pl"
if ! timeout 60 "$C" run "$CONTRACT" "write(ok), nl" 2>/dev/null | grep -aq '\bok\b'; then
  echo "SKIP (contracts/dex/uniswap.pl will not load -- did the u256 module build?)"
  exit 0
fi

# Every answer is written inside `answer(...)' so the extraction cannot
# pick up a stray digit from the echoed goal or from "1 answer(s)".
q() { timeout 120 "$C" run "$CONTRACT" "$1" 2>/dev/null \
      | grep -aoE 'answer\([^)]*\)' | head -1 | sed 's/^answer(//; s/)$//'; }
no() { if timeout 120 "$C" run "$CONTRACT" "$1" 2>/dev/null \
            | grep -aq 'answer('; then echo allowed; else echo refused; fi; }

ONE=1000000000000000000            # one token, 18 decimals
POOL=1000000000000000000000        # a thousand of them
QUOTE=996006981039903216           # what one token buys, at 0.3%

check "cocolog's 64-bit is/2 would get it wrong" \
  "$(timeout 60 "$C" query "X is ${ONE}*997, write(answer(X)), nl" 2>/dev/null \
     | grep -aoE 'answer\([0-9]+\)' | head -1 | sed 's/answer(//; s/)//')" \
  "875820019684212736"

# ---- the quote -------------------------------------------------------
check "one token into a 1000/1000 pool" \
  "$(q "uni_amount_out('$ONE','$POOL','$POOL',X), write(answer(X)), nl")" "$QUOTE"
check "and the inverse returns the input" \
  "$(q "uni_amount_in('$QUOTE','$POOL','$POOL',X), write(answer(X)), nl")" "$ONE"
check "a bigger pool moves the price less" \
  "$(q "uni_amount_out('$ONE','10000000000000000000000','10000000000000000000000',X), \
        u256_cmp(X,'$QUOTE',C), write(answer(C)), nl")" ">"

# ---- liquidity -------------------------------------------------------
MINT="uni_create(dai,weth), uni_mint(dai,weth,'$POOL','$POOL',L)"
check "the first deposit mints sqrt(a0*a1) - 1000" \
  "$(q "$MINT, write(answer(L)), nl")" "999999999999999999000"
check "and the burned thousand is in the supply" \
  "$(q "$MINT, uni_supply(dai,weth,T), write(answer(T)), nl")" "1000000000000000000000"
check "a second, in ratio, mints its share" \
  "$(q "$MINT, uni_mint(dai,weth,'$POOL','$POOL',L2), write(answer(L2)), nl")" \
  "1000000000000000000000"
check "off-ratio mints the SMALLER share" \
  "$(q "$MINT, uni_mint(dai,weth,'$POOL','${POOL}0',L2), write(answer(L2)), nl")" \
  "1000000000000000000000"

# ---- the invariant ---------------------------------------------------
check "k grows across a swap -- that is the fee" \
  "$(q "$MINT, uni_k(dai,weth,K0), uni_swap(dai,weth,'$ONE',_), \
        uni_k(dai,weth,K1), u256_cmp(K1,K0,C), write(answer(C)), nl")" ">"
check "the swap pays the quoted amount" \
  "$(q "$MINT, uni_swap(dai,weth,'$ONE',Out), write(answer(Out)), nl")" "$QUOTE"
check "the pair is unordered: same pool either way" \
  "$(q "uni_create(dai,weth), uni_mint(weth,dai,'$POOL','$POOL',_), \
        uni_reserves(dai,weth,R0,_), write(answer(R0)), nl")" "$POOL"

# ---- mallory ---------------------------------------------------------
# She cannot take more than the pool holds, and she cannot take all of
# it: the formula's denominator grows with her input, so the output
# approaches the reserve without ever reaching it.
check "mallory cannot drain the pool in one swap" \
  "$(no "$MINT, uni_swap(dai,weth,'1000000000000000000000000000000',Out), \
         u256_cmp(Out,'$POOL','<'), write(answer(Out)), nl")" "allowed"
check "and what she got was still less than the reserve" \
  "$(q "$MINT, uni_swap(dai,weth,'1000000000000000000000000000000',Out), \
        u256_cmp(Out,'$POOL',C), write(answer(C)), nl")" "<"
check "a swap on a pool that does not exist fails" \
  "$(no "uni_swap(nosuch,token,'$ONE',_), write(answer(x)), nl")" "refused"
check "a zero swap is not a swap" \
  "$(no "$MINT, uni_swap(dai,weth,'0',_), write(answer(x)), nl")" "refused"
check "burning more than exists is refused" \
  "$(no "$MINT, uni_burn(dai,weth,'99999999999999999999999999',_,_), \
         write(answer(x)), nl")" "refused"

# ---- rounding, and which way it falls --------------------------------
# Deposit, take the whole share back, and be no better off: what the
# floors dropped stayed with the pool.
check "a mint and burn round trip does not profit" \
  "$(q "$MINT, uni_burn(dai,weth,L,O0,_), u256_cmp(O0,'$POOL',C), write(answer(C)), nl")" \
  "<"
check "and the pool keeps the minimum liquidity" \
  "$(q "$MINT, uni_burn(dai,weth,L,_,_), uni_supply(dai,weth,T), write(answer(T)), nl")" \
  "1000"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
