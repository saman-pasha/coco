%% The Coco -- test/prelude.pl: what every .pl case shares.
%%
%% THE CASES ARE COCOLOG SCRIPTS. Each is `main/0', a run of checks and a
%% verdict, run as `cocolog -s test/<case>.pl' from coco/ -- and THE EXIT
%% CODE IS THE VERDICT, 0 exactly when main proved, which `checks_done'
%% withholds on any red check. This is CivV's shape, brought here for the
%% same reason it went there: every one of the eighteen .sh cases carried
%% its own copy of a check() function, its own `q()' that spawned cocolog
%% and grepped the output, and its own way of asking whether a module
%% built. Eighteen copies of one idea disagree eventually, and the
%% disagreement is silent.
%%
%% WHAT REPLACES WHAT:
%%
%%   check() in every file        library(process)'s check/3, one copy
%%   q() spawning cocolog          iso/2 -- run_isolated/2, same process,
%%                                 fresh machine, fresh store
%%   `grep -aoE' on the output     the goal's own bindings, compared with
%%                                 want/2, which prints both on a mismatch
%%   spawning for ISOLATION        iso/2 again -- but NOT where the claim
%%                                 is about two processes; see below
%%   `command -v', `uname -s'      library(os), one answer on both systems
%%
%% AND THE ONE THING THAT MUST STILL SPAWN. Half of this repository's
%% claims are about SEPARATE PROCESSES -- one writes the knowledge base
%% and a second, which consulted nothing, reads it back. `run_isolated/2'
%% is a fresh machine in the SAME process and deliberately cannot make
%% that claim. So `solo/2' and `solo_answer/3' below still start a real
%% cocolog, and every case that proves something across processes uses
%% them. Converting those to iso/2 would keep the suite green and delete
%% the proof.
%%
%% THE ENVIRONMENT IS THE CONFIGURATION, which is `test/config.sh's own
%% rule read the other way: every value it exports is a DEFAULT the
%% environment overrides, so a case run under `test/run.sh' inherits what
%% config.sh parsed out of coco.yaml, and a case run alone falls back to
%% the same defaults. There is deliberately no second coco.yaml parser
%% here -- a fact that appears in two places will disagree with itself.

:- use_module(library(process)).
:- use_module(library(text)).
:- use_module(library(os)).
:- use_module(library(thread)).

%% ---- where things are ---------------------------------------------------

%% The engine's own answer to "which binary am I", because there is no
%% /proc/self/exe on a Mac and a failing cocolog_bin/1 fails every case
%% here with nothing printed.
coco_bin(C) :-
    (   getenv('COCOLOG_BIN', B)
    ->  C = B
    ;   getenv('COCOLOG', D)
    ->  atom_concat(D, '/cocolog', C)
    ;   current_prolog_flag(executable, C)
    ).

coco_root(R) :- ( getenv('ROOT', R) -> true ; R = '.' ).

%% This repository's own modules land here; cocolog's are on the search
%% path behind it. The distinction matters: COCOLOG_LIBRARY is a LIST now
%% and `$COCOLOG_LIBRARY/u256.so' stopped being a path when it became one.
coco_lib_dir(D) :-
    (   getenv('COCO_PATHS_LIBRARY', D0)
    ->  D = D0
    ;   coco_root(R), atom_concat(R, '/library', D)
    ).

coco_lib(File, P) :- coco_lib_dir(D), sh_join([D, '/', File], P).

%% ---- the store, as one dial string --------------------------------------

zig(host, H)    :- ( getenv('ZIGURAT_HOST', H) -> true ; H = '127.0.0.1' ).
zig(port, P)    :- ( getenv('ZIGURAT_PORT', P) -> true ; P = '2160' ).
zig(timeout, T) :- ( getenv('ZIGURAT_TIMEOUT', T) -> true ; T = '15' ).
zig(kb, K)      :- ( getenv('ZIGURAT_KB', K) -> true ; K = coco_hello ).

%% ONE DIAL STRING, config.sh's rule kept: twelve copies of `--host H
%% --port P' were twelve places to edit, and `--port' is deprecated in
%% cocolog anyway -- `--tcp PORT' is the same field and names the
%% transport.
dial(D) :-
    (   getenv('ZIGURAT_DIAL', D0)
    ->  D = D0
    ;   zig(host, H), zig(port, P), zig(timeout, T),
        sh_join(['--host ', H, ' --tcp ', P, ' --timeout ', T], D)
    ).

%% ---- a second process, where the claim needs one ------------------------

%% ONE GOAL IN A REAL COCOLOG, and its matching output lines. This is the
%% only spawning left, and it is here because the claim is about
%% processes: `--local' proves nothing about a shared knowledge base.
solo(Goal, Pattern, Lines) :-
    coco_bin(C),
    ( is_list(Goal) -> sh_join(Goal, G) ; G = Goal ),
    shl([C, ' query "', G, '" 2>/dev/null'], Out),
    re_lines(Pattern, Out, Lines).

solo_answer(Goal, Pattern, A) :-
    solo(Goal, Pattern, [L|_]), atom_codes(A, L).

%% The same, against the SERVER rather than --local: a knowledge base a
%% second process can open. KB is the base's name; the dial is one string.
wire(KB, Goal, Pattern, A) :-
    coco_bin(C), dial(D),
    ( is_list(Goal) -> sh_join(Goal, G) ; G = Goal ),
    shl([C, ' ', D, ' --kb ', KB, ' query "', G, '" 2>/dev/null'], Out),
    re_lines(Pattern, Out, [L|_]),
    atom_codes(A, L).

wire_forget(KB) :-
    coco_bin(C), dial(D),
    ( shl([C, ' ', D, ' --kb ', KB, ' forget >/dev/null 2>&1']) -> true ; true ).

%% IS THERE A SERVER? "no server here" and "the backend is wrong" are
%% different findings, and a case that cannot tell them apart reports the
%% second when it means the first.
server_up :-
    coco_bin(C), dial(D),
    catch(shl([C, ' ', D, ' --kb ', probe_up, ' list >/dev/null 2>&1']), _, fail).

%% ---- what a check looks like --------------------------------------------

%% ONE ISOLATED PROOF PER SCENE -- fresh machine, fresh store filled from
%% the module registry -- with the comparison INSIDE it, so want/2 prints
%% both values on a mismatch and fails the proof that carried it.
iso(L, Goal) :-
    (   run_isolated(Goal, true)
    ->  format("ok   ~w~n", [L])
    ;   format("FAIL ~w~n", [L]), assertz('$check_failed'(L))
    ).

want(Got, Want) :-
    (   Got == Want -> true
    ;   format("     got  ~q~n     want ~q~n", [Got, Want]), fail ).

%% A GOAL THAT MUST RAISE, and WHAT it raised -- an error is the answer,
%% not an accident. The .sh cases did this by grepping stderr for a
%% phrase; here the error term itself is the value compared.
raises(Goal, Kind) :-
    catch(( call(Goal), fail ), E, true),
    nonvar(E),
    ( E = error(K, _) -> Kind = K ; Kind = E ).

%% A GOAL THAT MUST SIMPLY FAIL, which is not the same as raising, and
%% every gate in this repository that reads a stranger's bytes must do
%% this one rather than that one.
refuses(Goal) :- \+ catch(Goal, _, fail).

section(S) :- format("~n-- ~w~n", [S]).

skip(Why) :- format("SKIP ~w~n", [Why]).

%% ---- modules, and the SKIP when one will not build ----------------------

%% A module this repository builds for itself. Missing means no sbcl or
%% no CICILI checkout, which is a SKIP with its reason and not a red line.
have_module(M) :- coco_lib(M, P), atom_concat(P, '.so', S), exists_file(S).

build_modules(Group) :-
    coco_root(R), sh_join([R, '/modules/', Group, '/build.sh'], B),
    ( exists_file(B) -> catch(shl(['sh ', B, ' >/dev/null 2>&1']), _, true) ; true ).

%% Ask for a group's modules, building them once if they are not there;
%% answer whether they are all present afterwards.
modules_ready(Group, Ms) :-
    ( forall(member(M, Ms), have_module(M)) -> true ; build_modules(Group) ),
    forall(member(M, Ms), have_module(M)).
