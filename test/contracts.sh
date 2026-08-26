#!/bin/sh
# Rung 3: contracts. A contract is a predicate, deployment is a block,
# and mallory writes contracts too.
#
# WHAT IT IS CHECKING, in five parts.
#
#   THE FENCE HOLDS. Every goal in every clause body must be in the
#   vocabulary or defined by the same contract. Seven criminal contracts
#   are refused, including the two that a whitelist ALONE would let
#   through -- `call/1' and `=..' build goals at run time, so a static
#   check cannot see what they will call, and both are refused outright
#   rather than merely left off the list. The one that hides `assertz'
#   inside `findall' is there because a fence that checked only the outer
#   functor would pass it.
#
#   ISOLATION IS STRUCTURAL, NOT POLITE. Two contracts each keep a key
#   called `n' and neither can see the other's, because `state_put/2' and
#   `state_get/2' take no contract argument at all: the name comes from
#   the caller, who is the node. A contract has no way to SAY which
#   contract's state it means.
#
#   A CALL IS ALL OR NOTHING. `assertz' is not undone by backtracking in
#   any Prolog, so "it rolls back with the turn" would be false for a
#   FAILED goal -- half a contract's writes, committed. Writes are staged
#   and flushed only on success, and the suite proves a failing contract
#   leaves nothing behind while still reading its own writes as it runs.
#
#   DEPLOYMENT IS A BLOCK, so it inherits the chain. A contract arrives
#   signed by an authority, hash-chained and identical on every node, and
#   a contract in a block that does not validate is never parsed, never
#   fenced, never seen. Two layers, and the suite shows both refusing.
#
#   AND GAS IS THE ENGINE'S OWN. A contract that loops forever is
#   ADMITTED -- nothing is wrong with its vocabulary and no static check
#   can know it does not stop. `--steps' answers it: the machine suspends
#   at its budget, the node is unharmed, and the runaway can be dropped.
#
# SKIPs without a Zigurat server for parts four and five.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

BASE="--host $ZIGURAT_HOST --port $ZIGURAT_PORT --timeout 30"
LED="$ROOT/ledger"
CON="$ROOT/contracts"
FILES="$LED/federation.pl $LED/node.pl $CON/sources.pl $CON/node.pl"
ALICE=1111111111111111111111111111111111111111111111111111111111111111
BOB=2222222222222222222222222222222222222222222222222222222222222222
CAROL=3333333333333333333333333333333333333333333333333333333333333333
BOBPUB=466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f276728176c3c6431f8eeda4538dc37c865e2784f3a9e77d044f33e407797e1278a
CAROLPUB=3c72addb4fdf09af94f0c94d7fe92a386a7e70cf8a1d85916386bb2535c7b1b13b306b0fe085665d8fc1b28ae1676cd3ad6e08eaeda225fe38d0da4de55703e0

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-52s %s\n' "$1" "$(echo "$2" | cut -c1-18)"
  else
    printf 'FAIL %-52s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi

# Anchored, always: cocolog echoes the goal it ran, so an unanchored
# search for `refused' would match the goal text and agree with anything.
K="use_module(library(poa)), use_module(library(contract))"
loc() { timeout 90 "$C" run $FILES "$K, $1" 2>/dev/null | grep -aoE "$2" | head -1; }

# ---- part one: the fence ---------------------------------------------
echo "-- the fence"
V='^(admitted|refused)$'
for a in thief saboteur spy shapeshifter univ shadow smuggler; do
  what=$(timeout 90 "$C" run $FILES "attack_source($a,_,W), write(W), nl" 2>/dev/null \
           | grep -aoE '^[a-z][a-z ]+$' | head -1)
  check "refuses: $what" \
    "$(loc "attack_source($a, Cs, _), contract_admit($a, Cs, R), write(R), nl" "$V")" "refused"
done
check "admits a contract that loops (gas is the answer)" \
  "$(loc "attack_source(runaway, Cs, _), contract_admit(runaway, Cs, R), write(R), nl" "$V")" "admitted"
for h in escrow registry adder; do
  check "admits the honest contract '$h'" \
    "$(loc "contract_source($h, Cs), contract_admit($h, Cs, R), write(R), nl" "$V")" "admitted"
done

# ---- part two: isolation, the door, and atomicity --------------------
echo
echo "-- isolation, the door, and all-or-nothing"
check "two contracts keep separate keys of the same name" \
  "$(loc "contract_install(x1,[(s :- state_put(n, from_x1))]), contract_install(x2,[(s2 :- state_put(n, from_x2))]), contract_call(x1,s), contract_call(x2,s2), contract_enter(x1), state_get(n,A), contract_enter(x2), state_get(n,B), ( A == from_x1, B == from_x2 -> write(separate) ; write('LEAKED') ), nl" \
     '^(separate|LEAKED)$')" "separate"
check "a caller cannot run assertz through a contract's door" \
  "$(loc "contract_install(y1,[(s :- state_put(n,1))]), ( contract_call(y1, assertz(sneaky(1))) -> write('ACCEPTED') ; write(refused) ), nl" \
     '^(ACCEPTED|refused)$')" "refused"
check "a failing contract leaves nothing behind" \
  "$(loc "contract_install(z1,[(halfway :- state_put(k,written), fail)]), ( contract_call(z1, halfway) -> true ; true ), contract_enter(z1), ( state_get(k,_) -> write('SURVIVED') ; write(nothing_written) ), nl" \
     '^(SURVIVED|nothing_written)$')" "nothing_written"
check "and a succeeding one reads its own write, then commits it" \
  "$(loc "contract_install(z2,[(go(V) :- state_put(k,42), state_get(k,V))]), contract_call(z2, go(V)), contract_enter(z2), state_get(k,W), ( V == 42, W == 42 -> write(committed) ; write('LOST') ), nl" \
     '^(committed|LOST)$')" "committed"
check "recursion inside a contract is allowed and works" \
  "$(loc "contract_source(adder, Cs), contract_install(adder, Cs), contract_call(adder, sum_to(10, S)), write(S), nl" '^55$')" "55"

# ---- the server half -------------------------------------------------
if ! timeout 20 "$C" $BASE --kb contracts_test list >/dev/null 2>&1; then
  echo
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT (parts three to five)"
  echo
  if [ "$failures" -eq 0 ]; then echo "GREEN: 0 failure(s)"; exit 0
  else echo "RED: $failures failure(s)"; exit 1; fi
fi

KB="$BASE --kb contracts_test"
node() { NODE_NAME=$1 NODE_KEY=$(key_of "$1") timeout 90 "$C" $KB query "$K, $2" 2>/dev/null; }
key_of() { case "$1" in alice) echo "$ALICE";; bob) echo "$BOB";; carol) echo "$CAROL";; esac; }
srv() { node "$1" "$2" | grep -aoE "$3" | head -1; }

timeout 90 "$C" $KB forget >/dev/null 2>&1
for f in $FILES; do timeout 90 "$C" $KB consult "$f" >/dev/null 2>&1; done

# ---- part three: deployment is a block -------------------------------
echo
echo "-- deployment is a block, and inherits the chain"
node alice "deploy(escrow)"   >/dev/null
node alice "deploy(registry)" >/dev/null
# An AUTHORITY deploying a criminal contract. The ledger is content --
# alice is entitled to seal -- and the fence is what refuses it. Two
# different questions: who may deploy, and what may run.
node alice "deploy(thief)"    >/dev/null
node alice "install_from_chain" >/dev/null
check "the honest contracts install; the criminal one is refused" \
  "$(srv alice "deployed_report" '^installed \[escrow,registry\] refused \[thief\]$')" \
  "installed [escrow,registry] refused [thief]"

# And now the other layer: mallory is not an authority, so her
# deployment block never joins the chain and the contract is never seen.
check "a contract in a block that does not validate is never even parsed" \
  "$(srv alice "contract_source(registry, Cs), contract_deploy_payload(mallory_coin, Cs, P), genesis_prev(G), seal('4444444444444444444444444444444444444444444444444444444444444444', 0, G, mallory, P, S, H), ledger_sync([block(0,G,mallory,P,S,H)]), ( contract_clause(mallory_coin,_) -> write('INSTALLED') ; write(never_arrived) ), nl" \
     '^(INSTALLED|never_arrived)$')" "never_arrived"

# ---- part four: the escrow, with real signatures ---------------------
echo
echo "-- the escrow contract, end to end"
node alice "contract_call(escrow, open_escrow(e1, '$BOBPUB', '$CAROLPUB', 100))" >/dev/null
check "an escrow opens" \
  "$(srv alice "contract_call(escrow, status(e1, S)), write(S), nl" '^(open|released)$')" "open"
SIGC=$(timeout 90 "$C" query "use_module(library(secp256k1)), use_module(library(sha256)), sha256(e1,H), secp256k1_sign('$CAROL',H,S), write(S), nl" 2>/dev/null | grep -aoE '^[0-9a-f]{128}$' | head -1)
SIGB=$(timeout 90 "$C" query "use_module(library(secp256k1)), use_module(library(sha256)), sha256(e1,H), secp256k1_sign('$BOB',H,S), write(S), nl" 2>/dev/null | grep -aoE '^[0-9a-f]{128}$' | head -1)
check "the SELLER cannot release it" \
  "$(srv alice "( contract_call(escrow, release(e1, '$SIGC')) -> write('RELEASED') ; write(refused) ), nl" '^(RELEASED|refused)$')" "refused"
check "the buyer's signature does" \
  "$(srv alice "( contract_call(escrow, release(e1, '$SIGB')) -> write(released_ok) ; write('REFUSED') ), nl" '^(released_ok|REFUSED)$')" "released_ok"
check "and the status moved" \
  "$(srv alice "contract_call(escrow, status(e1, S)), write(S), nl" '^(open|released)$')" "released"
check "an escrow id cannot be opened twice" \
  "$(srv alice "( contract_call(escrow, open_escrow(e1, '$BOBPUB', '$CAROLPUB', 5)) -> write('REOPENED') ; write(refused) ), nl" '^(REOPENED|refused)$')" "refused"

# ---- part five: gas --------------------------------------------------
echo
echo "-- gas: a contract that never stops"
timeout 90 "$C" $KB query "$K, attack_source(runaway, Cs, _), contract_install(runaway, Cs)" >/dev/null 2>&1
timeout 90 "$C" $KB --steps 400 start spinner "spin(0)" >/dev/null 2>&1
got=$(timeout 90 "$C" $KB --steps 400 step spinner 2>&1 | grep -acE 'suspended at [0-9]+ inference')
check "it suspends at its budget instead of running" "$got" "1"
timeout 90 "$C" $KB drop spinner >/dev/null 2>&1
got=$(timeout 90 "$C" $KB list 2>&1 | grep -ac 'no suspended machines')
check "and dropping it leaves the node clean" "$got" "1"
check "the node still answers afterwards" \
  "$(srv alice "contract_call(escrow, status(e1, S)), write(S), nl" '^(open|released)$')" "released"

# ---- and an auditor reads the CODE off the chain ---------------------
echo
echo "-- an auditor, with no prior state"
check "a fresh process reads a contract's source out of the chain" \
  "$(timeout 90 "$C" $KB query "$K, findall(1, contract_clause(escrow, _), L), length(L, N), ( N =:= 3 -> write(three_clauses) ; write(N) ), nl" 2>/dev/null | grep -aoE '^(three_clauses|[0-9]+)$' | head -1)" \
  "three_clauses"

# ---- money is u256, inside the fence ---------------------------------
# `is/2' is in the vocabulary and it is SIXTY-FOUR BITS: at ordinary
# token scale -- one token is 10^18 -- it wraps in silence, so a
# contract that priced anything with it would be confidently wrong and
# its own checks would agree with it. library(u256) is the type a
# balance, a price or an amount is written in throughout The Coco, and
# it is inside the fence for the same reason everything else there is:
# deterministic, total, blind to everything but its arguments, and
# unable to wrap -- an operation that cannot represent its answer
# raises. `is/2' stays admitted, because heights and counters are
# honest 64-bit work; what changed is that MONEY has a type.
Q="u256_mul(In,'997',F), u256_mul(R0,'1000',S), u256_add(S,F,D), u256_muldiv(F,R1,D,Out)"
AMM="[(quote(In,R0,R1,Out) :- $Q)]"
check "admits a contract that prices in u256" \
  "$(loc "use_module(library(u256)), contract_admit(amm, $AMM, R), write(R), nl" "$V")" \
  "admitted"
# And it does not merely pass the fence -- it runs, and pays Uniswap's
# own number for one token into a 1000/1000 pool.
check "and it runs, paying the constant-product quote" \
  "$(loc "use_module(library(u256)), contract_install(amm, $AMM), \
          contract_call(amm, quote('1000000000000000000','1000000000000000000000','1000000000000000000000',Out)), \
          write(Out), nl" '^[0-9]+$')" \
  "996006981039903216"
# The fence is still a fence: u256 got in because it is safe, not
# because the list grew careless.
check "still refuses assertz beside the u256 calls" \
  "$(loc "use_module(library(u256)), contract_admit(sneak, [(q(A,B,C) :- u256_add(A,B,C), assertz(owned(C)))], R), write(R), nl" "$V")" \
  "refused"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"; exit 0
else
  echo "RED: $failures failure(s)"; exit 1
fi
