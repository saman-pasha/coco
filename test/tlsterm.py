#!/usr/bin/env python3
"""A TLS terminator in front of a plaintext port, for test/secure.pl.

THIS IS A REHEARSAL AND SAYS SO, exactly as cocolog's own
test/zigurat-tls.sh does. Turning ZiguratIP's SERVER/TLS_MODE on means
restarting the shared server with credentials every other case in the
family would then have to speak, and one server sits under all of them.
So a terminator stands in front of 2160 instead. What that proves is the
CLIENT half and the CONSENSUS half -- the handshake, the certificate
check, the framing, and every verdict above them. What it does not prove
is ZiguratIP's own server side.

It was a heredoc inside test/secure.sh until that case became a cocolog
script. A .pl case has no reason to write a Python file at run time, and
a file in the tree can be read, reviewed and linted; the one written
into a temp directory could not.

    python3 tlsterm.py CHAIN_PEM LISTEN_PORT ORIGIN_PORT

Prints `up' when it is listening, or `CANNOT BIND' and exits 3.
"""
import sys
import socket
import ssl
import threading

FULL, PORT, ORIGIN = sys.argv[1], int(sys.argv[2]), int(sys.argv[3])

ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
ctx.load_cert_chain(FULL, FULL)


def pump(a, b):
    try:
        while True:
            d = a.recv(65536)
            if not d:
                break
            b.sendall(d)
    except Exception:
        pass
    finally:
        for s in (a, b):
            try:
                s.close()
            except Exception:
                pass


s = socket.socket()
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
try:
    s.bind(("127.0.0.1", PORT))
except OSError:
    print("CANNOT BIND", flush=True)
    sys.exit(3)
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
        try:
            c.close()
        except Exception:
            pass
