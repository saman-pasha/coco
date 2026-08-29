%% Rung 5: the PoH spine -- a clock nobody can wind backwards.
%%
%% WHAT IT IS CHECKING.
%%
%%   THE SPINE IS THE SPINE. Three independent implementations of the same
%%   definition must agree: the C module's loop, a Prolog loop that does
%%   one tick per goal through library(sha256), and -- in the vectors
%%   below -- a number computed outside this project entirely. A spine
%%   nobody can check independently is a number somebody made up.
%%
%%   PRODUCTION IS SEQUENTIAL, VERIFICATION IS PARALLEL. That asymmetry is
%%   the only reason a spine is worth having, and this case checks the
%%   half that is checkable: that a range split K ways verifies segment by
%%   segment with no segment knowing about any other. The measured
%%   speedup lives in bench/poh.sh, where it belongs -- a timing is not a
%%   pass/fail, and putting one here would make the suite fail on a busy
%%   machine.
%%
%%   SEGMENTS MUST ALSO CHAIN. Every segment verifying is not enough: a
%%   set of perfectly good pieces that were never one sequence would pass
%%   that test. `spine_sound/0' checks the joins too, and the splice
%%   attack is what happens when nobody does.
%%
%%   AND ONE ATTACK SUCCEEDS. Two spines from the same start both verify.
%%   Nothing inside a hash chain prefers one, and no amount of hashing
%%   will make it -- that is what a clock IS, and the ledger is what
%%   answers it.
%%
%% SKIPs when the module cannot be built (no sbcl, or no CICILI).
%%
%% Run:  cocolog -s test/spine.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

%% The program under test, loaded once into this proof; every iso/2
%% below gets a fresh machine filled from the module registry, so a
%% scene that anchors blocks cannot leave them for the next one.
spine_program :-
    use_module(library(poh)),
    use_module('spine/node.pl'),
    use_module('spine/mallory.pl').

main :-
    (   modules_ready(crypto, [spine])
    ->  true
    ;   skip('(the spine module would not build -- no sbcl or CICILI)')
    ),
    ( have_module(spine) -> checks ; true ).

checks :-
    spine_program,

    section('three implementations of one definition'),
    %% Computed outside this project: 2000 iterations of sha256 over 32
    %% zero bytes. Nothing here produced this constant.
    iso('2000 ticks from genesis',
        ( poh_genesis(G), poh_run(G, 2000, X),
          want(X, '4aa241482140ae279432edae9365b656b054a9598a28b670340b72545068c117') )),
    iso('the Prolog loop reaches the same hash',
        ( poh_genesis(G), poh_slow_run(G, 2000, X),
          want(X, '4aa241482140ae279432edae9365b656b054a9598a28b670340b72545068c117') )),
    %% sha256 of 64 zero bytes -- the event fold with a zero event at
    %% genesis.
    iso('the event fold matches a published sha256',
        ( poh_genesis(G), poh_mix(G, G, X),
          want(X, 'f5a5fd42d16a20302798ef6ed309979b43003d2320d9f0e8ea9831a92759fb4b') )),
    iso('one tick is one sha256, not two',
        ( poh_genesis(G), poh_run(G, 1, X),
          want(X, '66687aadf862bd776c8fc18b8e9f8e20089714856ee233b3902a591d0d5f2925') )),
    iso('zero ticks is where you started',
        ( poh_genesis(G), poh_run(G, 0, X), want(X, G) )),

    section('a range split, and every piece checkable alone'),
    iso('1000 ticks split four ways gives four segments',
        ( poh_genesis(G), poh_segments(G, 1000, 4, S), length(S, N), want(N, 4) )),
    iso('and every segment verifies on its own',
        ( poh_genesis(G), poh_segments(G, 1000, 4, S), poh_verify_segments(S) )),
    iso('the segments chain end to start',
        ( spine_produce(1000, 4), spine_sound )),
    iso("a segment's end is the whole run's end",
        ( poh_genesis(G), poh_segments(G, 800, 4, S),
          last(S, seg(_, _, _, E)), poh_run(G, 800, W), want(E, W) )),

    section('what the spine is actually for: order'),
    iso('two anchored blocks come back in the order they went in',
        ( use_module(library(sha256)), spine_produce(200, 2),
          sha256(first, B1), anchor_block(B1),
          sha256(second, B2), anchor_block(B2),
          anchor_order([T1-_, T2-_]), T1 < T2 )),
    iso('an anchor recomputes to the hash on the record',
        ( use_module(library(sha256)), spine_produce(200, 2),
          sha256(only, B), anchor_block(B),
          anchor_order([T-_]), anchor_genuine(T) )),

    section('mallory attacks the clock'),
    iso('claiming a tick count without doing the ticks',
        ( attack_skip(V), want(V, refused) )),
    iso('doing fewer ticks than claimed',
        ( attack_shorten(V), want(V, refused) )),
    iso('backdating a block to an earlier tick',
        ( attack_backdate(V), want(V, refused) )),
    iso('splicing a segment from another spine',
        ( attack_splice(V), want(V, refused) )),
    %% AND THIS ONE MUST SUCCEED. Two spines from one start both verify;
    %% nothing inside a hash chain prefers either, and the ledger is what
    %% answers it. A suite where every attack fails is a suite that has
    %% not found the boundary.
    iso('forking the clock -- SUCCEEDS, and must',
        ( attack_fork(V), want(V, 'ACCEPTED') )),

    nl, checks_done.
