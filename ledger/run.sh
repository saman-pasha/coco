#!/bin/sh
# The PoA federation ledger: three nodes, no centre, no daemon.
#
# WHAT THIS ARRANGEMENT IS. Three authorities -- alice, bob, carol --
# each with its own knowledge base, which IS its chain. A node is not a
# process that runs: it is a cocolog invocation that seals or syncs and
# exits. Everything a node knows is rows, so a node that dies has lost
# nothing and a node that starts has missed nothing.
#
# THE ORDER INSIDE A ROUND IS THE POINT, and it is the balancer's order
# from cocolog's coworker tasks, doing a different job:
#
#   1. the authority whose TURN it is seals a block -- its own work
#      first, committed with its head mark in ONE turn;
#   2. only then do the others gossip: each fetches every block its peers
#      hold and offers them to its own `ledger_sync/1';
#   3. every offered block is RE-VERIFIED by the receiver. A peer's word
#      is a claim. The hash is recomputed, the author checked against the
#      federation, the signature checked against the author's key;
#   4. each node's head is then whatever FORK CHOICE says over the tips
#      it holds -- not what arrived last, and not what a peer asserted.
#
# THE FORK IS DELIBERATE. Round four has alice seal in turn and carol
# seal out of turn at the SAME height, which is what a partition looks
# like from the inside: two valid chains of equal length. Both nodes then
# see both blocks, and both must land on alice's -- not because alice is
# alice, but because her block is in turn and the rule prefers the
# schedule. A fork that closes the same way on every node, from rules
# alone, is the property this whole rung exists to demonstrate.
#
# Needs a Zigurat server: the three knowledge bases are the three nodes,
# and the gossip is one process reading another's kb. SKIPs without one.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../test/config.sh"
C="$COCOLOG_BIN"

BASE="--host $ZIGURAT_HOST --port $ZIGURAT_PORT --timeout 30"
FED="$HERE/federation.pl"
NODE="$HERE/node.pl"

ALICE_KEY=1111111111111111111111111111111111111111111111111111111111111111
BOB_KEY=2222222222222222222222222222222222222222222222222222222222222222
CAROL_KEY=3333333333333333333333333333333333333333333333333333333333333333

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi
if ! timeout 20 "$C" $BASE --kb ledger_alice list >/dev/null 2>&1; then
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT"
  exit 0
fi

key_of() {
  case "$1" in
    alice) echo "$ALICE_KEY" ;;
    bob)   echo "$BOB_KEY" ;;
    carol) echo "$CAROL_KEY" ;;
  esac
}

# A node's turn at the machine: its own kb, its own name, its own key.
# The key travels in the ENVIRONMENT and never through a file, because a
# consulted file becomes clauses and clauses become rows -- a private key
# in the database is a private key published to every reader of the
# chain.
# A LIBRARY LOADS INTO THE PROCESS, NOT INTO THE CHAIN. node.pl's
# clauses are rows and every invocation sees them; library(poa) is not,
# because `use_module' is a directive and a directive is not a clause --
# cocolog's MODULES.md is explicit that a loaded library's clauses are
# muted so a second process on the same knowledge base does not inherit
# them. So every invocation loads the rules itself. That is not a
# workaround: it is the property that lets a node upgrade its consensus
# rules without rewriting the chain, and lets an auditor read the chain
# under rules of its own.
node() {
  who=$1; shift
  NODE_NAME="$who" NODE_KEY="$(key_of "$who")" \
    timeout 60 "$C" $BASE --kb "ledger_$who" \
      query "use_module(library(poa)), $*" 2>/dev/null
}

echo "== a fresh federation"
for who in alice bob carol; do
  timeout 60 "$C" $BASE --kb "ledger_$who" forget >/dev/null 2>&1
  timeout 60 "$C" $BASE --kb "ledger_$who" consult "$FED" >/dev/null 2>&1
  timeout 60 "$C" $BASE --kb "ledger_$who" consult "$NODE" >/dev/null 2>&1
done

# Every block a node holds, as goal text its peer can run. This is the
# whole of the wire protocol: one node reads another's kb and offers what
# it finds. There is no message format, because a chain is a knowledge
# base and a knowledge base is already readable.
blocks_of() {
  node "$1" "ledger_export" | grep -a '^block(' | sed 's/\.$//'
}

gossip() {
  me=$1
  for peer in alice bob carol; do
    [ "$peer" = "$me" ] && continue
    list=$(blocks_of "$peer" | paste -sd, -)
    [ -z "$list" ] && continue
    node "$me" "ledger_sync([$list])" >/dev/null
  done
}

round() {
  sealer=$1; payload=$2
  echo "-- $sealer seals '$payload'"
  node "$sealer" "ledger_seal('$payload')" >/dev/null
  for who in alice bob carol; do gossip "$who"; done
}

round alice "genesis of the federation"
round bob   "the second block"
round carol "the third"

echo
echo "== a fork: alice in turn and carol out of turn, at the same height"
# Neither has heard the other yet -- which is what a partition is.
node alice "ledger_seal('alice in turn')" >/dev/null
node carol "ledger_seal('carol out of turn')" >/dev/null
echo "-- before gossip, the two disagree:"
for who in alice carol; do printf '   %-6s ' "$who"; node "$who" "ledger_report"; done
echo "-- after gossip, the rule closes it:"
for who in alice bob carol; do gossip "$who"; done

echo
echo "== every node, after everything"
for who in alice bob carol; do printf '%-6s ' "$who"; node "$who" "ledger_report" | grep -a '^head'; done
