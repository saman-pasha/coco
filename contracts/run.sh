#!/bin/sh
# Rung 3: contracts, narrated.
#
# A contract is a predicate. Deployment is a ledger block whose payload
# is the contract's clauses -- so the source is signed by an authority,
# hash-chained, gossiped and identical on every node, and none of that
# needed a new mechanism.
#
# What this walks through, in order:
#
#   1. alice DEPLOYS the escrow and the registry, which is two ordinary
#      seals whose payloads happen to be source code;
#   2. every node INSTALLS what its chain carries -- after the block has
#      been validated by the ledger's rules and the contract by the
#      fence, in that order;
#   3. an escrow RUNS: opened, refused to the seller, released to the
#      buyer, and the release is a real secp256k1 signature the contract
#      checks itself;
#   4. mallory's contracts are REFUSED, one per law they attack;
#   5. and a contract that never stops is stopped by GAS, which is the
#      engine's own `--steps' and needs nothing from this rung at all.
#
# Needs a Zigurat server. SKIPs without one.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../test/config.sh"
C="$COCOLOG_BIN"

BASE="--host $ZIGURAT_HOST --port $ZIGURAT_PORT --timeout 30"
KB="$BASE --kb contracts_demo"
FILES="$ROOT/ledger/federation.pl $ROOT/ledger/node.pl $ROOT/contracts/sources.pl $ROOT/contracts/node.pl"
K="use_module(library(poa)), use_module(library(contract))"

ALICE=1111111111111111111111111111111111111111111111111111111111111111
BOB=2222222222222222222222222222222222222222222222222222222222222222
CAROL=3333333333333333333333333333333333333333333333333333333333333333
BOBPUB=466d7fcae563e5cb09a0d1870bb580344804617879a14949cf22285f1bae3f276728176c3c6431f8eeda4538dc37c865e2784f3a9e77d044f33e407797e1278a
CAROLPUB=3c72addb4fdf09af94f0c94d7fe92a386a7e70cf8a1d85916386bb2535c7b1b13b306b0fe085665d8fc1b28ae1676cd3ad6e08eaeda225fe38d0da4de55703e0

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi
if ! timeout 20 "$C" $KB list >/dev/null 2>&1; then
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT"; exit 0
fi

node() { NODE_NAME=alice NODE_KEY=$ALICE timeout 90 "$C" $KB query "$K, $1" 2>/dev/null; }

timeout 90 "$C" $KB forget >/dev/null 2>&1
for f in $FILES; do timeout 90 "$C" $KB consult "$f" >/dev/null 2>&1; done

echo "== deploying: two seals whose payload is source code"
for c in escrow registry; do
  node "deploy($c)" >/dev/null
  echo "   sealed $c into a block"
done
node "deploy(thief)" >/dev/null
echo "   sealed thief   into a block  (alice is entitled to seal ANYTHING)"

echo
echo "== installing what the chain carries"
node "install_from_chain" >/dev/null
node "deployed_report" | grep -a '^installed'
echo "   -- the ledger let the thief through: alice is an authority and the"
echo "      block is valid. The FENCE refused it. Who may deploy and what"
echo "      may run are two questions with two answers."

echo
echo "== the escrow, with real signatures"
node "contract_call(escrow, open_escrow(e1, '$BOBPUB', '$CAROLPUB', 100))" >/dev/null
printf '   opened   e1: bob buys from carol for 100, status '
node "contract_call(escrow, status(e1,S)), write(S), nl" | grep -aoE '^(open|released)$'

SIGC=$(timeout 90 "$C" query "use_module(library(secp256k1)), use_module(library(sha256)), sha256(e1,H), secp256k1_sign('$CAROL',H,S), write(S), nl" 2>/dev/null | grep -aoE '^[0-9a-f]{128}$' | head -1)
SIGB=$(timeout 90 "$C" query "use_module(library(secp256k1)), use_module(library(sha256)), sha256(e1,H), secp256k1_sign('$BOB',H,S), write(S), nl" 2>/dev/null | grep -aoE '^[0-9a-f]{128}$' | head -1)
printf '   carol (the seller) signs a release: '
node "( contract_call(escrow, release(e1,'$SIGC')) -> write(released) ; write(refused) ), nl" | grep -aoE '^(released|refused)$'
printf '   bob (the buyer) signs a release:    '
node "( contract_call(escrow, release(e1,'$SIGB')) -> write(released) ; write(refused) ), nl" | grep -aoE '^(released|refused)$'
printf '   status now: '
node "contract_call(escrow, status(e1,S)), write(S), nl" | grep -aoE '^(open|released)$'

echo
echo "== mallory's contracts, one per law"
timeout 90 "$C" run $FILES "$K, forall(attack_source(N,Cs,W), (contract_admit(N,Cs,V), format(\"   ~w ~w: ~w~n\", [V,N,W])))" 2>/dev/null | grep -a '^   '

echo
echo "== gas: a contract that never stops"
node "attack_source(runaway,Cs,_), contract_install(runaway,Cs)" >/dev/null
timeout 90 "$C" $KB --steps 400 start spinner "spin(0)" 2>&1 | tail -1 | sed 's/^/   /'
timeout 90 "$C" $KB --steps 400 step spinner 2>&1 | tail -1 | sed 's/^/   /'
timeout 90 "$C" $KB drop spinner 2>&1 | tail -1 | sed 's/^/   /'
printf '   and the node still answers: '
node "contract_call(escrow, status(e1,S)), write(S), nl" | grep -aoE '^(open|released)$'
