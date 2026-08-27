#!/bin/sh
# THE CONSENSUS RUNGS, OVER TLS -- proof of authority, proof of stake and
# proof of history, each run again with the node-to-store link encrypted,
# and each required to reach THE SAME VERDICTS.
#
# WHAT THIS IS ACTUALLY ASKING. cocolog grew `--tls' -- the binary
# protocol on 2160 with ZiguratIP's `SERVER/TLS_MODE: TRUE' on the other
# end -- so every node in this repository can now reach its chain over an
# encrypted, server-authenticated link. The question that raises is not
# "does it still work" but "does it change what is TRUE about the
# consensus", and the answer has to be demonstrated rather than asserted.
#
# THE ANSWER IS NO, AND THAT IS THE POINT. Every law these three rungs
# enforce is a law about CONTENT: a hash recomputed from the block's own
# fields, a signature checked against the author's published key, a tick
# count re-run, a quorum weighed against a stake table read out of rows.
# Not one of them asks who handed the bytes over. So an encrypted link
# cannot make a bad block good, and -- this is the half worth testing --
# it must not make a bad block ACCEPTABLE either, by tempting a node to
# treat an authenticated peer as a trusted one.
#
# So this case runs `ledger', `spine' and `votes' twice, once in the
# clear and once over TLS, and requires the verdict lines to be IDENTICAL
# -- every attack refused that was refused, and every one of the two
# deliberate successes still succeeding. A run where mallory suddenly
# failed to grind the leader draw would be as much of a failure as one
# where she got through.
#
# WHAT TLS DOES ADD is on the other side of the seam: with
# `SECURITY/PERMISSIONS_MODE' on, a certificate decides which knowledge
# bases a node may reach at all, so a compromised node can be cut off
# from its peers' chains without any rule in library(poa) changing. That
# is ZiguratIP's to enforce and ZiguratIP's suite's to prove; what is
# proved here is that turning it on costs this repository nothing.
#
# THE TERMINATOR IS A REHEARSAL, and says so, exactly as cocolog's
# test/zigurat-tls.sh does: turning TLS_MODE on means restarting the
# shared server with credentials every other case would then have to
# speak. So a TLS terminator stands in front of 2160. What that proves is
# the CLIENT half and the CONSENSUS half -- the handshake, the framing,
# and every verdict above it. What it does not prove is ZiguratIP's own
# server side.
#
# SKIPS without a server, without openssl, without python3, or without a
# cocolog built with TLS.

HERE=$(cd "$(dirname "$0")" && pwd)
. "$HERE/config.sh"
C="$COCOLOG_BIN"

[ -x "$C" ] || { echo "SKIP no cocolog binary at $C"; exit 0; }
command -v openssl >/dev/null 2>&1 || { echo "SKIP no openssl"; exit 0; }
command -v python3 >/dev/null 2>&1 || { echo "SKIP no python3"; exit 0; }

if ! timeout 20 "$C" $ZIGURAT_DIAL --timeout 10 --kb "$ZIGURAT_KB" list >/dev/null 2>&1; then
  echo "SKIP no Zigurat server at $ZIGURAT_HOST:$ZIGURAT_PORT"
  exit 0
fi

OUT=$(mktemp -d "${TMPDIR:-/tmp}/coco-secure-XXXXXX")
TPORT=${COCO_TLS_PORT:-22162}
trap 'kill $TERM_PID 2>/dev/null; rm -rf "$OUT"' EXIT INT TERM

openssl req -x509 -newkey rsa:2048 -nodes -keyout "$OUT/s.pem" -out "$OUT/s.crt" \
  -days 2 -subj '/CN=localhost' -addext 'subjectAltName=DNS:localhost' >/dev/null 2>&1 \
  || { echo "SKIP openssl would not make a certificate"; exit 0; }
cat "$OUT/s.pem" "$OUT/s.crt" > "$OUT/full.pem"

# A SECOND, UNRELATED AUTHORITY. Never presented by anything -- it exists
# to be the wrong answer, for the check that a node which cannot verify
# the store reaches no chain at all.
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$OUT/o.pem" -out "$OUT/other.crt" \
  -days 2 -subj '/CN=somebody-else' >/dev/null 2>&1 \
  || { echo "SKIP openssl would not make a second certificate"; exit 0; }

cat > "$OUT/term.py" <<'PYEOF'
import sys, socket, ssl, threading
FULL, PORT, ORIGIN = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])
ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(FULL, FULL)
def pump(a, b):
    try:
        while True:
            d = a.recv(65536)
            if not d: break
            b.sendall(d)
    except Exception:
        pass
    finally:
        for s in (a, b):
            try: s.close()
            except Exception: pass
s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    s.bind(("127.0.0.1", PORT))
except OSError:
    print("CANNOT BIND", flush=True); sys.exit(3)
s.listen(64)
print("up", flush=True)
while True:
    c, _ = s.accept()
    try:
        c = ctx.wrap_socket(c, server_side=True)
        o = socket.create_connection(("127.0.0.1", ORIGIN), timeout=120)
        threading.Thread(target=pump, args=(c, o), daemon=True).start()
        threading.Thread(target=pump, args=(o, c), daemon=True).start()
    except Exception:
        try: c.close()
        except Exception: pass
PYEOF

python3 "$OUT/term.py" "$OUT/full.pem" "$TPORT" "$ZIGURAT_PORT" > "$OUT/term.out" 2>&1 &
TERM_PID=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  grep -q up "$OUT/term.out" 2>/dev/null && break
  grep -q "CANNOT BIND" "$OUT/term.out" 2>/dev/null && { echo "SKIP cannot bind $TPORT"; exit 0; }
  sleep 0.3
done
grep -q up "$OUT/term.out" || { echo "SKIP the terminator did not come up"; exit 0; }

# The environment a node uses to reach the store THROUGH the terminator.
# `localhost' and not 127.0.0.1 because the hostname is checked, not just
# the chain -- which is the check a hand-rolled client forgets.
secure_env() {
  ZIGURAT_TRANSPORT=tls ZIGURAT_HOST=localhost ZIGURAT_PORT="$TPORT" \
  ZIGURAT_CACERT="$OUT/s.crt" "$@"
}

if ! secure_env timeout 20 "$C" --host localhost --tls "$TPORT" --cacert "$OUT/s.crt" \
       --timeout 10 --kb "$ZIGURAT_KB" list >/dev/null 2>&1; then
  echo "SKIP this cocolog cannot reach the store over TLS (built without OpenSSL?)"
  exit 0
fi

failures=0
check() {
  if [ "$2" = "$3" ]; then
    printf 'ok   %-56s %s\n' "$1" "$(echo "$2" | cut -c1-24)"
  else
    printf 'FAIL %-56s\n     got  %s\n     want %s\n' "$1" "$2" "$3"
    failures=$((failures + 1))
  fi
}

# ---- 1. the three rungs, twice, verdict for verdict -------------------
#
# WHOLE LINES, values included. Every input to these three rungs is
# fixed -- the demonstration keys, the payloads, a knowledge base each
# case empties before it starts -- so every hash, height and count they
# print is a function of the rules alone. Comparing only the names would
# let a run agree that a block "audits clean" while auditing a different
# block; comparing the lines makes "TLS changed nothing" mean it.
verdicts() { grep -aE '^(ok|FAIL) '; }

for rung in ledger spine votes; do
  sh "$HERE/$rung.sh" > "$OUT/$rung.plain" 2>&1
  secure_env sh "$HERE/$rung.sh" > "$OUT/$rung.tls" 2>&1

  if grep -q '^SKIP' "$OUT/$rung.plain"; then
    printf 'skip %-56s %s\n' "$rung in the clear" "$(head -1 "$OUT/$rung.plain")"
    continue
  fi

  verdicts < "$OUT/$rung.plain" > "$OUT/$rung.plain.v"
  verdicts < "$OUT/$rung.tls"   > "$OUT/$rung.tls.v"

  n=$(wc -l < "$OUT/$rung.plain.v" | tr -d ' ')
  check "$rung: over TLS it still ends green" \
    "$(grep -c '^GREEN' "$OUT/$rung.tls")" "1"
  check "$rung: the same $n verdicts, in the same order" \
    "$(cmp -s "$OUT/$rung.plain.v" "$OUT/$rung.tls.v" && echo identical || echo DIFFER)" \
    "identical"
  # AND THE DELIBERATE SUCCESSES ARE STILL SUCCESSES. A suite that
  # reported every attack refused would be lying; one that started
  # refusing them because of TLS would be lying differently.
  acc=$(grep -c 'ACCEPTED' "$OUT/$rung.plain.v")
  check "$rung: its $acc deliberate success(es) still succeed" \
    "$(grep -c 'ACCEPTED' "$OUT/$rung.tls.v")" "$acc"
done

# ---- 2. the link really is TLS ---------------------------------------
#
# Without this the section above proves only that a run with different
# environment variables also passes.
echo
check "plaintext against the TLS port reaches no chain" \
  "$(timeout 15 "$C" --host localhost --tcp "$TPORT" --timeout 5 \
       --kb ledger_alice query 'block(_,_,_,_,_,_)' 2>&1 | grep -c 'cocolog:')" "1"

# ---- 3. a node that cannot verify the store gets NOTHING ---------------
#
# Not a partial read, not a warning: no chain. `--cacert' names an
# authority that signed nothing here, so the handshake fails and the
# audit never begins. This is the property `--insecure' spends, which is
# why cocolog says so on stderr every time it is used.
got=$(timeout 15 "$C" --host localhost --tls "$TPORT" --cacert "$OUT/other.crt" \
        --timeout 5 --kb ledger_alice query 'block(_,_,_,_,_,_)' 2>&1)
check "a node whose authority does not match reads no blocks" \
  "$(echo "$got" | grep -c '^block(')" "0"
check "and is told why, by name" \
  "$(echo "$got" | grep -c 'certificate')" "1"

# ---- 4. THE ONE THAT MATTERS: TLS AUTHENTICATES THE LINK, NOT THE BLOCK
#
# This is the mistake an encrypted transport invites, and the reason this
# case exists at all. Mallory now arrives over a verified TLS connection
# to the very same store the honest nodes use -- she is, at the transport
# layer, exactly as authenticated as alice. She offers a block she signed
# with her own real key.
#
# `ledger_sync/1' must refuse it anyway, because the law it enforces is
# that the AUTHOR is in the federation and the SIGNATURE is the author's
# -- neither of which a handshake has anything to say about. A node that
# skipped re-verification for peers on an authenticated link would pass
# every other check in this file and be broken.
echo
FED="$ROOT/ledger/federation.pl"
NODE="$ROOT/ledger/node.pl"
MAL="$ROOT/ledger/mallory.pl"
MKB=secure_tls_test

secure_env sh -c '
  . "$1/config.sh"
  timeout 30 "$2" $ZIGURAT_DIAL --timeout 30 --kb '"$MKB"' forget >/dev/null 2>&1
  timeout 30 "$2" $ZIGURAT_DIAL --timeout 30 --kb '"$MKB"' consult "$3" >/dev/null 2>&1
  timeout 30 "$2" $ZIGURAT_DIAL --timeout 30 --kb '"$MKB"' consult "$4" >/dev/null 2>&1
' sh "$HERE" "$C" "$FED" "$NODE"

# Her block, made locally -- a real secp256k1 signature over a real hash,
# by somebody the federation never admitted.
MBLOCK=$(timeout 30 "$C" run "$FED" "$NODE" "$MAL" \
  "mallory_key(K), genesis_prev(G), seal(K, 0, G, mallory, 'a block from outside', S, H), format(\"block(0,'~w',mallory,'a block from outside','~w','~w')~n\", [G,S,H])" \
  2>/dev/null | grep -a '^block(' | head -1)

check "mallory produced a real, well-formed block" \
  "$( [ -n "$MBLOCK" ] && echo made || echo "EMPTY" )" "made"

secure_env sh -c '
  . "$1/config.sh"
  NODE_NAME=alice NODE_KEY=1111111111111111111111111111111111111111111111111111111111111111 \
  timeout 30 "$2" $ZIGURAT_DIAL --timeout 30 --kb '"$MKB"' \
    query "use_module(library(poa)), ledger_sync([$3])" >/dev/null 2>&1
' sh "$HERE" "$C" "$MBLOCK"

got=$(secure_env sh -c '
  . "$1/config.sh"
  timeout 30 "$2" $ZIGURAT_DIAL --timeout 30 --kb '"$MKB"' \
    query "( block(_,_,mallory,_,_,_) -> write('"'"'STORED'"'"') ; write(refused) ), nl"
' sh "$HERE" "$C" 2>/dev/null | grep -aoE '^(STORED|refused)$' | head -1)
check "offered over a verified TLS link, it is still refused" "$got" "refused"

# And the same block, checked directly against the law, so the refusal
# above is the LAW's and not an accident of the sync path.
got=$(timeout 30 "$C" run "$FED" "$NODE" "$MAL" \
  "mallory_key(K), genesis_prev(G), seal(K,0,G,mallory,'a block from outside',S,H), ( valid_block(0,G,mallory,'a block from outside',S,H) -> write('VALID') ; write(refused) ), nl" \
  2>/dev/null | grep -aoE '^(VALID|refused)$' | head -1)
check "because the law is about the author, not the connection" "$got" "refused"

secure_env sh -c '
  . "$1/config.sh"
  timeout 30 "$2" $ZIGURAT_DIAL --timeout 30 --kb '"$MKB"' forget >/dev/null 2>&1
' sh "$HERE" "$C"

echo
if [ "$failures" -eq 0 ]; then
  echo "GREEN: 0 failure(s)"
else
  echo "RED: $failures failure(s)"
  exit 1
fi
