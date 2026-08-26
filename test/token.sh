#!/bin/sh
# contracts/token: the two standards, and their invariants.
#
# WHAT IS BEING PINNED:
#
#   CONSERVATION, for the fungible one. The balances sum to the supply,
#   always -- checked by a predicate that nothing in the token needs to
#   be true for its own code to work, which is exactly why it is worth
#   checking. Mint, transfer, spend-someone-else's, burn, and the sum
#   still matches.
#
#   EXACTLY ONE OWNER, for the non-fungible one. Not "at most" and not
#   "at least": minting an id that exists is refused, and the stored
#   balances are checked against the ids actually held rather than
#   trusted -- a count kept beside the ownership rows is a second copy
#   of a fact, and this is what proves the copy.
#
#   THE APPROVE RACE IS CLOSED. ERC-20's `approve' lets a watching
#   spender use an old allowance and a new one when it is changed from
#   one non-zero value to another. The usual advice is to zero it first,
#   which is advice rather than a rule. Here it IS the rule, and the
#   check below is that the dangerous overwrite is refused.
#
#   AND THE SINGLE-ID APPROVAL DIES WITH THE TRANSFER, which is
#   ERC-721's rule and the one reimplementations forget. Without it an
#   approval granted to a buyer survives the sale and lets them take the
#   token back from its new owner -- so that exact theft is attempted
#   here, and must fail.
#
#   THE OPERATOR APPROVAL SURVIVES, because it is the owner's
#   arrangement with a marketplace rather than anything about one token.
#   Both halves are checked, since getting either backwards is a bug
#   with a real victim.

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

FT="$ROOT/contracts/token/fungible.pl"
NFT="$ROOT/contracts/token/nonfungible.pl"
if ! timeout 60 "$C" run "$FT" "write(ok), nl" 2>/dev/null | grep -aq '\bok\b'; then
  echo "SKIP (the token contracts will not load -- did the u256 module build?)"
  exit 0
fi

f()  { timeout 120 "$C" run "$FT" "$1" 2>/dev/null \
       | grep -aoE 'answer\([^)]*\)' | head -1 | sed 's/^answer(//; s/)$//'; }
fno() { if timeout 120 "$C" run "$FT" "$1" 2>/dev/null | grep -aq 'answer('; \
        then echo allowed; else echo refused; fi; }
n()  { timeout 120 "$C" run "$NFT" "$1" 2>/dev/null \
       | grep -aoE 'answer\([^)]*\)' | head -1 | sed 's/^answer(//; s/)$//'; }
nno() { if timeout 120 "$C" run "$NFT" "$1" 2>/dev/null | grep -aq 'answer('; \
        then echo allowed; else echo refused; fi; }

ONE=1000000000000000000
K=1000000000000000000000
MK="ft_create(dai,'DAI',18), ft_mint(dai,alice,'$K')"

echo "-- fungible"
check "a fresh balance is zero, not missing" \
  "$(f "ft_create(dai,'DAI',18), ft_balance(dai,nobody,B), write(answer(B)), nl")" "0"
check "minting raises the balance" \
  "$(f "$MK, ft_balance(dai,alice,B), write(answer(B)), nl")" "$K"
check "and the supply with it" \
  "$(f "$MK, ft_total(dai,T), write(answer(T)), nl")" "$K"
check "conservation holds after minting" \
  "$(f "$MK, ( ft_conservation(dai) -> write(answer(held)) ; write(answer(broken)) ), nl")" "held"
check "a transfer moves exactly what it says" \
  "$(f "$MK, ft_transfer(dai,alice,bob,'$ONE'), ft_balance(dai,bob,B), write(answer(B)), nl")" \
  "$ONE"
check "and takes it from the sender" \
  "$(f "$MK, ft_transfer(dai,alice,bob,'$ONE'), ft_balance(dai,alice,B), write(answer(B)), nl")" \
  "999000000000000000000"
check "conservation holds after a transfer" \
  "$(f "$MK, ft_transfer(dai,alice,bob,'$ONE'), \
        ( ft_conservation(dai) -> write(answer(held)) ; write(answer(broken)) ), nl")" "held"
check "spending more than you have is refused" \
  "$(fno "$MK, ft_transfer(dai,alice,bob,'99999999999999999999999999'), write(answer(x)), nl")" \
  "refused"
# The classic bug: a self-transfer written as subtract-then-add against
# a re-read balance MINTS money. It must be a no-op, and it must still
# have been affordable.
check "a self-transfer is a no-op, not a mint" \
  "$(f "$MK, ft_transfer(dai,alice,alice,'$ONE'), ft_balance(dai,alice,B), write(answer(B)), nl")" \
  "$K"
check "and an unaffordable self-transfer is still refused" \
  "$(fno "$MK, ft_transfer(dai,alice,alice,'99999999999999999999999999'), write(answer(x)), nl")" \
  "refused"
check "burning lowers balance and supply together" \
  "$(f "$MK, ft_burn(dai,alice,'$ONE'), ft_total(dai,T), write(answer(T)), nl")" \
  "999000000000000000000"
check "burning more than held is refused" \
  "$(fno "$MK, ft_burn(dai,alice,'99999999999999999999999999'), write(answer(x)), nl")" "refused"

echo "-- allowances"
check "an allowance starts at zero" \
  "$(f "$MK, ft_allowance(dai,alice,bob,A), write(answer(A)), nl")" "0"
check "transfer_from spends it" \
  "$(f "$MK, ft_approve(dai,alice,bob,'$ONE'), \
        ft_transfer_from(dai,bob,alice,carol,'$ONE'), \
        ft_balance(dai,carol,B), write(answer(B)), nl")" "$ONE"
check "and the allowance comes down by what was spent" \
  "$(f "$MK, ft_approve(dai,alice,bob,'$K'), \
        ft_transfer_from(dai,bob,alice,carol,'$ONE'), \
        ft_allowance(dai,alice,bob,A), write(answer(A)), nl")" "999000000000000000000"
check "spending past the allowance is refused" \
  "$(fno "$MK, ft_approve(dai,alice,bob,'$ONE'), \
          ft_transfer_from(dai,bob,alice,carol,'$K'), write(answer(x)), nl")" "refused"
check "spending with no allowance is refused" \
  "$(fno "$MK, ft_transfer_from(dai,bob,alice,carol,'$ONE'), write(answer(x)), nl")" "refused"
# The approve race, closed: non-zero over non-zero is refused outright.
check "overwriting a live allowance is REFUSED (the approve race)" \
  "$(fno "$MK, ft_approve(dai,alice,bob,'$ONE'), ft_approve(dai,alice,bob,'$K'), \
          write(answer(x)), nl")" "refused"
check "zeroing it first is the way, and works" \
  "$(f "$MK, ft_approve(dai,alice,bob,'$ONE'), ft_approve(dai,alice,bob,'0'), \
        ft_approve(dai,alice,bob,'$K'), ft_allowance(dai,alice,bob,A), \
        write(answer(A)), nl")" "$K"

echo "-- non-fungible"
NMK="nft_create(punks,'Punks'), nft_mint(punks,alice,'1')"
check "the minter owns it" \
  "$(n "$NMK, nft_owner(punks,'1',O), write(answer(O)), nl")" "alice"
check "and the balance counts it" \
  "$(n "$NMK, nft_balance(punks,alice,B), write(answer(B)), nl")" "1"
check "minting the same id twice is refused" \
  "$(nno "$NMK, nft_mint(punks,bob,'1'), write(answer(x)), nl")" "refused"
MAXID=115792089237316195423570985008687907853269984665640564039457584007913129639935
check "a huge id is fine -- ids are u256" \
  "$(n "nft_create(punks,'Punks'), nft_mint(punks,alice,'$MAXID'), nft_owner(punks,'$MAXID',O), write(answer(O)), nl")" "alice"
check "the owner can move it" \
  "$(n "$NMK, nft_transfer_from(punks,alice,alice,bob,'1'), nft_owner(punks,'1',O), \
        write(answer(O)), nl")" "bob"
check "a stranger cannot" \
  "$(nno "$NMK, nft_transfer_from(punks,mallory,alice,mallory,'1'), write(answer(x)), nl")" \
  "refused"
check "an approved spender can" \
  "$(n "$NMK, nft_approve(punks,alice,bob,'1'), \
        nft_transfer_from(punks,bob,alice,bob,'1'), nft_owner(punks,'1',O), \
        write(answer(O)), nl")" "bob"
check "an operator can move any of the owner's" \
  "$(n "$NMK, nft_mint(punks,alice,'2'), nft_set_operator(punks,alice,market,on), \
        nft_transfer_from(punks,market,alice,bob,'2'), nft_owner(punks,'2',O), \
        write(answer(O)), nl")" "bob"
check "and cannot once the operator is switched off" \
  "$(nno "$NMK, nft_set_operator(punks,alice,market,on), \
          nft_set_operator(punks,alice,market,off), \
          nft_transfer_from(punks,market,alice,bob,'1'), write(answer(x)), nl")" "refused"
# The theft the standard's clearing rule exists to stop: bob is approved
# for the token, buys it, sells it on -- and must NOT be able to take it
# back with the approval he was given before.
check "an approval does not survive the transfer (the take-back)" \
  "$(nno "$NMK, nft_approve(punks,alice,bob,'1'), \
          nft_transfer_from(punks,bob,alice,carol,'1'), \
          nft_transfer_from(punks,bob,carol,bob,'1'), write(answer(x)), nl")" "refused"
check "but an operator approval does survive it" \
  "$(n "$NMK, nft_mint(punks,alice,'2'), nft_set_operator(punks,alice,market,on), \
        nft_transfer_from(punks,market,alice,bob,'1'), \
        nft_transfer_from(punks,market,alice,bob,'2'), nft_owner(punks,'2',O), \
        write(answer(O)), nl")" "bob"
check "burning removes it" \
  "$(nno "$NMK, nft_burn(punks,'1'), nft_owner(punks,'1',_), write(answer(x)), nl")" "refused"
check "the counts agree with the tokens actually held" \
  "$(n "$NMK, nft_mint(punks,alice,'2'), nft_mint(punks,bob,'3'), \
        nft_transfer_from(punks,alice,alice,bob,'1'), \
        ( nft_conservation(punks) -> write(answer(held)) ; write(answer(broken)) ), nl")" \
  "held"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
