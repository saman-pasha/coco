#!/bin/sh
# The other system on the same box.
#
# The bench's founding rule -- no sentence says "competes with" until
# the number is on the page -- was never a refusal to compare; it was
# the price of comparing. This lane pays it: a SINGLE-NODE Solana test
# validator on the SAME container the Coco lanes ran on, driven by
# Solana's own CLI, measured under the same six rules, both
# arrangements named on every line. The reader gets both tables and
# writes the sentence themselves; this file still does not.
#
# WHAT IS HELD EQUAL, and what cannot be:
#
#   equal: the hardware (this container); the finality bar (a
#   transaction counts only when ITS OWN SIGNATURE reads confirmed
#   afterwards -- rule 1, per transaction; votes are never counted
#   because only our signatures are); the clock (the wall); the
#   batching, matched lane for lane -- pipelined submits against
#   seal_batched, one process per transaction against seal_per_turn;
#   and the first run discarded.
#
#   not equal, and printed rather than adjusted: the unit of work. A
#   Solana transaction is an ed25519-signed transfer between accounts;
#   a Coco block is a secp256k1-sealed append to a hash chain. Close
#   enough to put side by side, different enough that the arrangement
#   column is the truth of each line.
#
# SKIPs without the toolchain (cargo install agave-validator solana-cli
# solana-keygen), because "no Solana here" and "the lane is wrong" are
# different findings.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/../test/config.sh"

now()  { date +%s.%N; }
secs() { python3 -c "import sys;print(f'{float(sys.argv[2])-float(sys.argv[1]):.3f}')" "$1" "$2"; }
rate() { python3 -c "import sys;print(f'{float(sys.argv[1])/float(sys.argv[2]):.2f}')" "$1" "$2"; }

BIN="$HOME/.cargo/bin"
for b in solana-test-validator solana solana-keygen; do
  if [ ! -x "$BIN/$b" ] && ! command -v "$b" >/dev/null 2>&1; then
    echo "SKIP no $b -- cargo install agave-validator solana-cli solana-keygen"
    exit 0
  fi
done
PATH="$BIN:$PATH"; export PATH

RPC=http://127.0.0.1:8899
LEDGER=/tmp/coco-solana-ledger
KEY=/tmp/coco-solana-id.json
LOG=/tmp/coco-solana-validator.log

rpc() {  # method params-json
  curl -s -m 20 "$RPC" -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$1\",\"params\":$2}"
}

echo "== the arrangement"
echo "   $(uname -s) $(uname -m), $(nproc) cores -- the same container the"
echo "   Coco lanes ran on; solana-test-validator, ONE node, default"
echo "   commitment 'confirmed'; every transaction verified by its own"
echo "   signature afterwards, so votes are never in the count"
echo

# ---- the validator, fresh ---------------------------------------------
pkill -9 -f solana-test-validator 2>/dev/null
sleep 2
rm -rf "$LEDGER"
solana-keygen new -o "$KEY" --no-bip39-passphrase --force >/dev/null 2>&1
( solana-test-validator --reset --quiet --ledger "$LEDGER" \
    --mint "$(solana-keygen pubkey "$KEY")" >"$LOG" 2>&1 & )
ready=0
for i in $(seq 1 60); do
  if rpc getHealth '[]' 2>/dev/null | grep -q '"ok"'; then ready=1; break; fi
  sleep 1
done
if [ "$ready" != 1 ]; then
  echo "SKIP the test validator would not come up (see $LOG)"
  exit 0
fi
solana config set --url "$RPC" --keypair "$KEY" >/dev/null 2>&1
solana-keygen new --no-bip39-passphrase -o /tmp/coco-solana-dest.json --force >/dev/null 2>&1
DEST=$(solana-keygen pubkey /tmp/coco-solana-dest.json)
if [ -z "$DEST" ]; then echo "SKIP could not derive a destination key"; exit 0; fi

# how many of these SIGNATURES read confirmed -- rule 1, per transaction
confirmed_of() {  # file-of-signatures
  n=0
  while read -r sig; do
    [ -n "$sig" ] || continue
    if rpc getSignatureStatuses "[[\"$sig\"],{\"searchTransactionHistory\":true}]" \
       | grep -q '"confirmationStatus":"\(confirmed\|finalized\)"'; then
      n=$((n+1))
    fi
  done < "$1"
  echo $n
}

# ---- the per-process lane: seal_per_turn's twin ------------------------
# one CLI process per transaction, each waiting for its own confirmation
# -- the same shape as ten cocolog processes each sealing one block.
solana transfer "$DEST" 0.000001 --allow-unfunded-recipient >/dev/null 2>&1  # discarded
: > /tmp/coco-solana-perproc.sigs
t0=$(now)
i=0; ok=0
while [ $i -lt 10 ]; do
  out=$(solana transfer "$DEST" "0.0000$((101+i))" --allow-unfunded-recipient 2>/dev/null | grep -ao '^Signature: .*' | cut -d' ' -f2)
  [ -n "$out" ] && { echo "$out" >> /tmp/coco-solana-perproc.sigs; ok=$((ok+1)); }
  i=$((i+1))
done
t1=$(now)
V=$(confirmed_of /tmp/coco-solana-perproc.sigs)
S=$(secs $t0 $t1)
printf '  %-22s %9s /s   %-38s %s of 10 confirmed in %ss\n' \
  solana_per_process "$(rate $V $S)" solana_1node_one_process_per_txn "$V" "$S"
echo "     ^ ten CLI processes, each waiting for its own confirmation --"
echo "       seal_per_turn's twin, start-up cost and all."

# ---- the pipelined lane: seal_batched's twin ---------------------------
# 100 transfers submitted without waiting, in waves; then EVERY signature
# checked. Amounts differ so no two messages are identical. The clock
# runs from the first submit to the last confirmation, because a
# submitted transaction is a claim and a confirmed one is a fact.
: > /tmp/coco-solana-pipe.sigs
t0=$(now)
i=0
while [ $i -lt 100 ]; do
  j=0
  while [ $j -lt 10 ] && [ $i -lt 100 ]; do
    ( solana transfer "$DEST" "0.0000$((1000+i))" --allow-unfunded-recipient --no-wait 2>/dev/null \
        | grep -ao '^Signature: .*' | cut -d' ' -f2 >> /tmp/coco-solana-pipe.sigs ) &
    j=$((j+1)); i=$((i+1))
  done
  wait
done
# wait for the tail of them to land, bounded
settle=0
while [ $settle -lt 30 ]; do
  V=$(confirmed_of /tmp/coco-solana-pipe.sigs)
  [ "$V" -ge 100 ] && break
  sleep 1; settle=$((settle+1))
done
t1=$(now)
V=$(confirmed_of /tmp/coco-solana-pipe.sigs)
S=$(secs $t0 $t1)
printf '  %-22s %9s /s   %-38s %s of 100 confirmed in %ss\n' \
  solana_pipelined "$(rate $V $S)" solana_1node_pipelined_submits "$V" "$S"
echo "     ^ a hundred submits in waves of ten, then every signature"
echo "       verified confirmed -- seal_batched's twin: the submit cost"
echo "       is pipelined away and the store's own pace is what is left."

pkill -f solana-test-validator 2>/dev/null
echo
echo "   Put these beside bench/README.md's Coco table, arrangements and"
echo "   all. The units differ and both columns say so; the sentence is"
echo "   still the reader's to write."
