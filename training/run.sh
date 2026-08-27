#!/bin/sh
# Rung 4: training as settlement -- proof of USEFUL work.
#
# THE DISCIPLINE IN ONE SENTENCE: train freely, verify deterministically,
# commit rows.
#
# Training is expensive, non-deterministic and unverifiable -- two honest
# workers with the same data and the same seed can land on different
# weights, and nobody can audit a gradient step after the fact.
# EVALUATION is none of those things. So settlement never asks "did you
# really train this". It asks the only question with a checkable answer:
# DOES IT WORK.
#
# What this walks through:
#
#   1. a TASK is published -- data, architecture, seed, held-out range
#      and threshold, with the holdout COMMITTED by hash before any
#      worker exists;
#   2. workers TRAIN in --local with no connection open, and print their
#      weights as facts. Three seconds of gradient descent never sits
#      inside a database turn;
#   3. the weights are PUBLISHED as chunked rows and the submission is
#      SEALED as an ordinary ledger block. The digest is the join: the
#      block is signed, the rows are only believed if they hash back;
#   4. SETTLEMENT re-evaluates every submission on the committed holdout
#      and judges on the measured number. The worker's claim is read only
#      to be reported;
#   5. and PROVENANCE -- where this model came from -- is one query.
#
# Needs a Zigurat server. SKIPs without one.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../test/config.sh"
C="$COCOLOG_BIN"

BASE="$ZIGURAT_DIAL --timeout 60"
KB="$BASE --kb training_demo"
F="$ROOT/ledger/federation.pl $ROOT/ledger/node.pl $ROOT/training/task.pl $ROOT/training/worker.pl $ROOT/training/mallory.pl"
K="use_module(library(poa)), use_module(library(settle))"
OUT=$(mktemp -d "${TMPDIR:-/tmp}/coco-train-XXXXXX")
trap 'rm -rf "$OUT"' EXIT INT TERM

key_of() {
  case "$1" in
    alice) echo 1111111111111111111111111111111111111111111111111111111111111111 ;;
    bob)   echo 2222222222222222222222222222222222222222222222222222222222222222 ;;
    carol) echo 3333333333333333333333333333333333333333333333333333333333333333 ;;
  esac
}

if [ ! -x "$C" ]; then echo "no cocolog binary at $C"; exit 1; fi
if ! timeout 20 "$C" $KB list >/dev/null 2>&1; then
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT"; exit 0
fi

srv() { who=$1; shift; NODE_NAME=$who NODE_KEY=$(key_of "$who") \
          timeout 120 "$C" $KB query "$K, $*" 2>/dev/null; }

timeout 60 "$C" $KB forget >/dev/null 2>&1
for f in $F; do timeout 60 "$C" $KB consult "$f" >/dev/null 2>&1; done

echo "== the task"
timeout 60 "$C" run $F "the_task(T), T = task(Id,_,holdout(A,B),holdout_commit(HC),_,seed(S),accept(_,Th)), format(\"   ~w: holdout ~w..~w committed as ~w~n   seed ~w, accept at ~w~n\", [Id,A,B,HC,S,Th])" 2>/dev/null | grep -a '^   '

echo
echo "== workers train, in --local, with nothing connected"
# who trains what: alice honestly, bob honestly, carol lies about a
# barely-trained model, and mallory submits untrained weights.
for w in alice:honest bob:honest carol:liar; do
  who=${w%%:*}; how=${w##*:}
  printf '   %-6s trains (%s) ... ' "$who" "$how"
  NODE_NAME=$who NODE_KEY=$(key_of "$who") \
    timeout 300 "$C" run $F "$K, train_and_export($how)" 2>/dev/null \
    | grep -aE '^(param_chunk|submission_ready)' > "$OUT/$who.pl"
  echo "$(grep -ac '^param_chunk' "$OUT/$who.pl") rows of weights"
done

echo
echo "== publishing the rows, then sealing the submissions"
for w in alice:0.99 bob:0.99 carol:0.99; do
  who=${w%%:*}; claim=${w##*:}
  timeout 60 "$C" $KB consult "$OUT/$who.pl" >/dev/null 2>&1
  # The digest comes from THIS worker's export, named explicitly. Looking
  # it up in the store would find every worker's, and seal them all.
  dg=$(grep -a '^submission_ready' "$OUT/$who.pl" | sed "s/.*'\\([0-9a-f]*\\)'.*/\\1/")
  srv "$who" "submit_ready('$dg', $claim)" >/dev/null
  echo "   $who sealed a submission claiming $claim  ($(echo "$dg" | cut -c1-8))"
done

echo
echo "== settlement: every claim re-measured on the committed holdout"
srv alice "settle_submissions" >/dev/null
srv alice "settlement_report" | grep -aE '^[a-z]+ [0-9a-f]{8} '  | sed 's/^/   /'
echo "   -- carol claimed 0.99 like everyone else. Nobody read the claim."

echo
echo "== where did this model come from"
srv alice "provenance_report" | grep -a '^model ' | sed 's/^/   /'
