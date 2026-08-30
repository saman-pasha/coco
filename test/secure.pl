%% THE CONSENSUS RUNGS, OVER TLS -- proof of authority, proof of stake and
%% proof of history, each run again with the node-to-store link encrypted,
%% and each required to reach THE SAME VERDICTS.
%%
%% WHAT THIS IS ACTUALLY ASKING. cocolog grew `--tls' -- the binary
%% protocol on 2160 with ZiguratIP's `SERVER/TLS_MODE: TRUE' on the other
%% end -- so every node in this repository can now reach its chain over an
%% encrypted, server-authenticated link. The question that raises is not
%% "does it still work" but "does it change what is TRUE about the
%% consensus", and the answer has to be demonstrated rather than asserted.
%%
%% THE ANSWER IS NO, AND THAT IS THE POINT. Every law these three rungs
%% enforce is a law about CONTENT: a hash recomputed from the block's own
%% fields, a signature checked against the author's published key, a tick
%% count re-run, a quorum weighed against a stake table read out of rows.
%% Not one of them asks who handed the bytes over. So an encrypted link
%% cannot make a bad block good, and -- this is the half worth testing --
%% it must not make a bad block ACCEPTABLE either, by tempting a node to
%% treat an authenticated peer as a trusted one.
%%
%% So this case runs `ledger', `spine' and `votes' twice, once in the
%% clear and once over TLS, and requires the verdict lines to be IDENTICAL
%% -- every attack refused that was refused, and every one of the two
%% deliberate successes still succeeding. A run where mallory suddenly
%% failed to grind the leader draw would be as much of a failure as one
%% where she got through.
%%
%% WHAT TLS DOES ADD is on the other side of the seam: with
%% `SECURITY/PERMISSIONS_MODE' on, a certificate decides which knowledge
%% bases a node may reach at all, so a compromised node can be cut off
%% from its peers' chains without any rule in library(poa) changing. That
%% is ZiguratIP's to enforce and ZiguratIP's suite's to prove; what is
%% proved here is that turning it on costs this repository nothing.
%%
%% THE TERMINATOR IS A REHEARSAL, and says so, exactly as cocolog's
%% test/zigurat-tls.sh does: turning TLS_MODE on means restarting the
%% shared server with credentials every other case would then have to
%% speak. So a TLS terminator stands in front of 2160 -- test/tlsterm.py,
%% a file in the tree now rather than a heredoc, because a .pl case has no
%% reason to write a Python program at run time. What that proves is the
%% CLIENT half and the CONSENSUS half -- the handshake, the framing, and
%% every verdict above it. What it does not prove is ZiguratIP's own
%% server side.
%%
%% AND THE AUDIT PLANE, THROUGH THE SAME KIND OF TUNNEL. Zeytun is the
%% chain's read-only public face, and behind a Cloudflare-shaped tunnel an
%% https:// URL is the only kind it has. The last section stands a TLS
%% edge in front of Zeytun and reads the ledger through it BOTH ways a
%% public reader exists: `--https', the arrangement, re-verifying every
%% block of alice's chain from rules it loads itself; and library(curl),
%% a PROGRAM, fetching the pages a query needs. An auditor should not
%% need the binary port, and after this section that sentence is tested
%% rather than assumed.
%%
%% THIS CASE IS THE ONE THAT SPAWNS MOST, AND HAS TO. Its whole subject
%% is a LINK between two processes: a terminator, a store behind it, and
%% node after node dialling through. `run_isolated/2' has no link in it
%% at all, so nothing here is an isolated proof except the one check that
%% is genuinely about a rule -- that the law refusing mallory's block is
%% about the author and not the connection.
%%
%% SKIPS without a server, without openssl, without python3, or without a
%% cocolog built with TLS.
%%
%% Run:  cocolog -s test/secure.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

tls_port(P) :- ( getenv('COCO_TLS_PORT', P) -> true ; P = '22162' ).
zeytun_port(P) :- ( getenv('ZEYTUN_PORT', P) -> true ; P = '2190' ).
audit_kb(ledger_alice).
mallory_kb(secure_tls_test).

%% the three rungs run twice, verdict for verdict
rungs([ledger, spine, votes]).

%% ---- the environment a node dials the store with ------------------------
%%
%% CONFIG.SH'S RULE, USED FROM THE OTHER SIDE: every value it exports is a
%% default the environment overrides, and it rebuilds $ZIGURAT_DIAL from
%% the transport every time it is sourced. So a spawned case picks the
%% encrypted link up from these five variables and nothing else changes.
%% The dial is set here too, because THIS process reaches the store
%% through the prelude's dial/1, which reads $ZIGURAT_DIAL first.

env_keys(['ZIGURAT_TRANSPORT', 'ZIGURAT_HOST', 'ZIGURAT_PORT',
          'ZIGURAT_CACERT', 'ZIGURAT_DIAL']).

save_env(Saved) :-
    env_keys(Ks),
    findall(K-V, ( member(K, Ks), ( getenv(K, V) -> true ; V = '' ) ), Saved).

restore_env(Saved) :- forall(member(K-V, Saved), setenv(K, V)).

%% `localhost' and not 127.0.0.1 because the hostname is checked, not just
%% the chain -- which is the check a hand-rolled client forgets.
secure_env(Dir) :-
    tls_port(P), ca(Dir, CA),
    setenv('ZIGURAT_TRANSPORT', tls),
    setenv('ZIGURAT_HOST', localhost),
    setenv('ZIGURAT_PORT', P),
    setenv('ZIGURAT_CACERT', CA),
    sh_join(['--host localhost --tls ', P, ' --cacert ', CA], D),
    setenv('ZIGURAT_DIAL', D).

ca(Dir, CA)    :- sh_join([Dir, '/s.crt'], CA).
other(Dir, O)  :- sh_join([Dir, '/other.crt'], O).
chain_pem(Dir, F) :- sh_join([Dir, '/full.pem'], F).

%% ---- the ground the case stands on --------------------------------------

tmpdir(D) :-
    sh('mktemp -d "${TMPDIR:-/tmp}/coco-secure-XXXXXX"', Cs),
    ( append(Ds, [10], Cs) -> true ; Ds = Cs ),
    atom_codes(D, Ds).

%% A certificate for localhost, and A SECOND, UNRELATED AUTHORITY that is
%% never presented by anything -- it exists to be the wrong answer, for
%% the check that a node which cannot verify the store reaches no chain.
certificates(Dir) :-
    shl(['openssl req -x509 -newkey rsa:2048 -nodes -keyout ', Dir, '/s.pem -out ',
         Dir, '/s.crt -days 2 -subj /CN=localhost ',
         '-addext subjectAltName=DNS:localhost >/dev/null 2>&1']),
    %% THE CHAIN IS BUILT, NOT `cat'-ed. A concatenation of two files into a
    %% third is two reads and a write, and cocolog answers all three now:
    %% write_file_from_codes/2 masks its bytes exactly as
    %% read_file_to_codes/2 does, so a PEM survives whole and no shell has
    %% to be trusted with three paths in one string.
    sh_join([Dir, '/s.pem'], Pem),
    sh_join([Dir, '/s.crt'], Crt),
    sh_join([Dir, '/full.pem'], Full),
    read_file_to_codes(Pem, PemCs),
    read_file_to_codes(Crt, CrtCs),
    append(PemCs, CrtCs, FullCs),
    write_file_from_codes(Full, FullCs),
    shl(['openssl req -x509 -newkey rsa:2048 -nodes -keyout ', Dir, '/o.pem -out ',
         Dir, '/other.crt -days 2 -subj /CN=somebody-else >/dev/null 2>&1']).

%% the terminator, and the wait for it to say `up'
terminator(Dir, Listen, Origin, Log, Pid) :-
    coco_root(R), chain_pem(Dir, Full),
    sh_join([Dir, '/', Log], Out),
    %% proc_spawn/2 takes ONE atom -- shl/1's list is the prelude's
    %% joining, not the module's
    %% `exec', so the pid proc_spawn/2 answers with IS the terminator.
    %% Without it /bin/sh stays in front of python3 -- the redirection
    %% keeps it from exec'ing -- and proc_kill/2 at the end of the case
    %% killed the shell and left the terminator holding the port, which
    %% is how two of them ended up bound across a rerun.
    sh_join(['exec python3 ', R, '/test/tlsterm.py ', Full, ' ', Listen, ' ',
             Origin, ' > ', Out, ' 2>&1'], Cmd),
    proc_spawn(Cmd, Pid),
    up(Out, 10).

up(_, 0) :- !, fail.
up(Out, N) :-
    (   exists_file(Out), read_file_to_codes(Out, Cs), re_lines('^up$', Cs, [_|_])
    ->  true
    ;   proc_sleep(300), N1 is N - 1, up(Out, N1) ).

%% ---- 1. the three rungs, twice, verdict for verdict ---------------------
%%
%% WHOLE LINES. Every input to these three rungs is fixed -- the
%% demonstration keys, the payloads, a knowledge base each case empties
%% before it starts -- so every verdict they print is a function of the
%% rules alone. Comparing only the names would let a run agree that a
%% block "audits clean" while auditing a different block; comparing the
%% lines makes "TLS changed nothing" mean it.

%% run one case the way test/run.sh runs it, and keep whatever it exited
%% with -- a RED case is a READING here rather than an error, and the
%% comparison below is what decides the verdict
case_out(Case, File) :-
    coco_bin(C), coco_root(R),
    sh_any(['cd ', R, ' && timeout 3600 ', C, ' -s test/', Case, '.pl > ',
            File, ' 2>&1'], _).

lines_of(File, Pattern, Ls) :-
    (   exists_file(File), read_file_to_codes(File, Cs), re_lines(Pattern, Cs, Ls0)
    ->  Ls = Ls0 ;  Ls = [] ).

%% the deliberate successes, counted by the marker their labels carry --
%% "-- SUCCEEDS, and must". A suite that reported every attack refused
%% would be lying; one that started refusing them because of TLS would be
%% lying differently.
deliberate(File, N) :-
    lines_of(File, '^ok .*SUCCEEDS, and must', Ls), length(Ls, N).

rung(Dir, Saved, Rung) :-
    sh_join([Dir, '/', Rung, '.plain'], Plain),
    sh_join([Dir, '/', Rung, '.tls'], Tls),
    restore_env(Saved), case_out(Rung, Plain),
    secure_env(Dir),   case_out(Rung, Tls),
    restore_env(Saved),
    (   lines_of(Plain, '^SKIP', [_|_])
    ->  sh_join([Rung, ' in the clear'], W), skip(W)
    ;   lines_of(Plain, '^(ok|FAIL) ', PV),
        lines_of(Tls,   '^(ok|FAIL) ', TV),
        length(PV, N), deliberate(Plain, Acc),
        sh_join([Rung, ': over TLS it still ends green'], L1),
        iso(L1, ( lines_of(Tls, '^GREEN', G), length(G, GN), want(GN, 1) )),
        sh_join([Rung, ': the same ', N, ' verdicts, in the same order'], L2),
        iso(L2, want(PV, TV)),
        sh_join([Rung, ': its ', Acc, ' deliberate success(es) still succeed'], L3),
        iso(L3, ( deliberate(Tls, A2), want(A2, Acc) ))
    ).

rungs_half(Dir, Saved) :-
    rungs(Rs), forall(member(R, Rs), rung(Dir, Saved, R)).

%% ---- 2 and 3. the link really is TLS, and an authority that does not match

%% Without the first of these, section 1 proves only that a run with
%% different environment variables also passes.
link_half(Dir) :-
    coco_bin(C), tls_port(P), other(Dir, Other), audit_kb(KB),
    nl,
    iso('plaintext against the TLS port reaches no chain',
        ( sh_any(['timeout 15 ', C, ' --host localhost --tcp ', P,
                  ' --timeout 5 --kb ', KB,
                  ' query "block(_,_,_,_,_,_)" 2>&1'], O),
          count(O, 'cocolog:', N), want(N, 1) )),
    %% Not a partial read, not a warning: no chain. `--cacert' names an
    %% authority that signed nothing here, so the handshake fails and the
    %% audit never begins. This is the property `--insecure' spends, which
    %% is why cocolog says so on stderr every time it is used.
    sh_any(['timeout 15 ', C, ' --host localhost --tls ', P, ' --cacert ', Other,
            ' --timeout 5 --kb ', KB,
            ' query "block(_,_,_,_,_,_)" 2>&1'], Got),
    iso('a node whose authority does not match reads no blocks',
        ( count(Got, '^block\\(', N), want(N, 0) )),
    iso('and is told why, by name',
        ( count(Got, 'certificate', N), want(N, 1) )).

count(Codes, Pattern, N) :-
    ( re_lines(Pattern, Codes, Ls) -> true ; Ls = [] ), length(Ls, N).

%% ---- 4. TLS AUTHENTICATES THE LINK, NOT THE BLOCK -----------------------
%%
%% This is the mistake an encrypted transport invites, and the reason this
%% case exists at all. Mallory now arrives over a verified TLS connection
%% to the very same store the honest nodes use -- she is, at the transport
%% layer, exactly as authenticated as alice. She offers a block she signed
%% with her own real key.
%%
%% `ledger_sync/1' must refuse it anyway, because the law it enforces is
%% that the AUTHOR is in the federation and the SIGNATURE is the author's
%% -- neither of which a handshake has anything to say about. A node that
%% skipped re-verification for peers on an authenticated link would pass
%% every other check in this file and be broken.

ledger_rules :-
    use_module(library(poa)),
    use_module('ledger/federation.pl'),
    use_module('ledger/node.pl'),
    use_module('ledger/mallory.pl').

%% her block, made HERE -- a real secp256k1 signature over a real hash, by
%% somebody the federation never admitted
mallory_block(B) :-
    ledger_rules, mallory_key(K), genesis_prev(G),
    seal(K, 0, G, mallory, 'a block from outside', S, H),
    sh_join(['block(0,''', G, ''',mallory,''a block from outside'',''',
             S, ''',''', H, ''')'], B).

mallory_half(Dir) :-
    mallory_kb(KB), nl,
    secure_env(Dir),
    wire_forget(KB),
    wire_consult(KB, 'ledger/federation.pl'),
    wire_consult(KB, 'ledger/node.pl'),
    iso('mallory produced a real, well-formed block',
        ( ( mallory_block(B) -> W = made ; W = 'EMPTY' ), want(W, made) )),
    mallory_block(B),
    ( wire_as(alice, KB, ['use_module(library(poa)), ledger_sync([', B, '])'],
              '.', _) -> true ; true ),
    iso('offered over a verified TLS link, it is still refused',
        ( (   wire(KB, ['use_module(library(poa)), ',
                        '( block(_,_,mallory,_,_,_) -> write(''STORED'') ',
                        '; write(refused) ), nl'],
                   '^(STORED|refused)$', A)
          ->  true ;  A = none ),
          want(A, refused) )),
    %% And the same block, checked directly against the law, so the
    %% refusal above is the LAW's and not an accident of the sync path.
    iso('because the law is about the author, not the connection',
        ( ledger_rules, mallory_key(K), genesis_prev(G),
          seal(K, 0, G, mallory, 'a block from outside', S, H),
          refuses(valid_block(0, G, mallory, 'a block from outside', S, H)) )),
    wire_forget(KB).

%% ---- 5. THE PUBLIC AUDIT PLANE, THROUGH A TUNNEL ------------------------
%%
%% Everything above encrypts the BINARY port -- the writers' road. The
%% chain's public face is Zeytun, read-only by construction, and behind a
%% Cloudflare-shaped tunnel it is reachable only as https. So: a TLS edge
%% in front of Zeytun, and alice's ledger -- the chain section 1's run
%% left behind -- read through it by both kinds of public reader.

zeytun_here :-
    zeytun_port(Z), audit_kb(KB),
    catch(( use_module(library(curl)),
            sh_join(['http://127.0.0.1:', Z, '/cocolog/predicates.zt?kb=', KB], U),
            curl_get(U, S, Body), S == 200,
            atom_codes(A, Body), sub_atom(A, _, _, _, block) ),
          _, fail).

audit_half(Dir, Saved) :-
    restore_env(Saved), nl,
    (   \+ zeytun_here
    ->  skip('audit plane: no Zeytun, no library(curl), or no chain in ledger_alice -- run the ledger case first')
    ;   tls_port(P0), atom_number(P0, P1), ZP0 is P1 + 1, atom_number(ZP, ZP0),
        zeytun_port(Z), ca(Dir, CA), audit_kb(KB), coco_bin(C),
        (   terminator(Dir, ZP, Z, 'zterm.out', Pid)
        ->  %% A PROGRAM reads the pages: library(curl), an https URL, the
            %% edge's certificate vouched for by name -- the reader
            %% cocolog's own test/tunnel.sh proves in the small, here
            %% reading a real chain.
            iso('curl_get lists the chain through the Zeytun tunnel',
                ( use_module(library(curl)),
                  sh_join(['https://localhost:', ZP,
                           '/cocolog/predicates.zt?kb=', KB], U),
                  curl_get(U, [ca_info(CA)], S, Body),
                  atom_codes(A, Body),
                  (   S == 200, sub_atom(A, _, _, _, block)
                  ->  W = chain_listed ;  W = wrong(S) ),
                  want(W, chain_listed) )),
            %% THE ARRANGEMENT audits: `--https' warms alice's whole
            %% knowledge base through the edge, loads the consensus rules
            %% ITSELF, and re-verifies every block it finds -- the ledger
            %% case's part-five auditor, moved from the writers' port to
            %% the public one. The rules come from the auditor's own
            %% library path, never from the chain being audited, which is
            %% what makes the audit worth anything.
            iso('an --https auditor re-verifies every block through it',
                ( sh_any(['timeout 120 ', C, ' --host localhost --https ', ZP,
                          ' --cacert ', CA, ' --kb ', KB, ' --timeout 60 query ',
                          '"use_module(library(poa)), ( forall(block(H,Pv,A,P,Sg,Hs), ',
                          'valid_block(H,Pv,A,P,Sg,Hs)) -> write(all_verified) ',
                          '; write(''SOME_INVALID'') ), nl" 2>/dev/null'], O),
                  (   re_lines('^(all_verified|SOME_INVALID)$', O, [L|_])
                  ->  atom_codes(V, L) ;  V = none ),
                  want(V, all_verified) )),
            proc_stop(Pid)
        ;   skip('audit plane: the Zeytun terminator did not come up')
        )
    ).

%% ---- the case ------------------------------------------------------------

secure_run(Dir, Saved, Pid) :-
    rungs_half(Dir, Saved),
    link_half(Dir),
    mallory_half(Dir),
    audit_half(Dir, Saved),
    restore_env(Saved),
    %% proc_stop/1 rather than a kill of our own: 15, a moment to die
    %% well, then 9 -- and ALWAYS the wait, so the terminator is reaped
    %% instead of left defunct for whatever runs this next. The hand-
    %% rolled version here sent one signal and never waited.
    proc_stop(Pid).

main :-
    coco_bin(C),
    (   \+ exists_file(C)         -> skip('no cocolog binary')
    ;   \+ have_tool(openssl)     -> skip('no openssl')
    ;   \+ have_tool(python3)     -> skip('no python3')
    ;   \+ server_up              -> skip('no Zigurat server')
    ;   tmpdir(Dir), save_env(Saved),
        (   \+ catch(certificates(Dir), _, fail)
        ->  skip('openssl would not make a certificate'), clean(Dir)
        ;   tls_port(P), zig(port, Origin),
            %% POSITIVE, BECAUSE NEGATION DOES NOT BIND. Written as
            %% `\+ terminator(...)' this reads the same and leaves Pid
            %% UNBOUND in the branch that needs it, so the proc_kill/2 at
            %% the end threw an instantiation error into a catch and the
            %% terminator outlived the case -- holding 22162, so the NEXT
            %% run could not bind and skipped itself quietly. A leaked
            %% listener is a case that stops testing without saying so.
            (   terminator(Dir, P, Origin, 'term.out', Pid)
            ->  secure_env(Dir),
                (   \+ tls_reaches(C, Dir)
                ->  restore_env(Saved),
                    skip('this cocolog cannot reach the store over TLS (built without OpenSSL?)'),
                    proc_stop(Pid), clean(Dir)
                ;   restore_env(Saved),
                    ( secure_run(Dir, Saved, Pid) -> true ; true ),
                    restore_env(Saved), proc_stop(Pid), clean(Dir),
                    nl, checks_done
                )
            ;   skip('the TLS terminator did not come up'), clean(Dir)
            )
        )
    ).

tls_reaches(C, Dir) :-
    tls_port(P), ca(Dir, CA), zig(kb, KB),
    catch(shl([C, ' --host localhost --tls ', P, ' --cacert ', CA,
               ' --timeout 10 --kb ', KB, ' list >/dev/null 2>&1']), _, fail).

clean(Dir) :- ( catch(shl(['rm -rf ', Dir]), _, true) -> true ; true ).
