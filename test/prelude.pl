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

%% The same, as SOMEBODY: the spawned process inherits this one's
%% environment, so `as/2' setting NODE_NAME and NODE_KEY here reaches the
%% cocolog it starts.
wire_as(Who, KB, Goal, Pattern, A) :- as(Who, wire(KB, Goal, Pattern, A)).

solo_as(Who, Goal, Pattern, A) :- as(Who, solo_answer(Goal, Pattern, A)).

%% every matching line, not just the first -- a report is many lines
wire_lines(KB, Goal, Pattern, Ls) :-
    coco_bin(C), dial(D),
    ( is_list(Goal) -> sh_join(Goal, G) ; G = Goal ),
    shl([C, ' ', D, ' --kb ', KB, ' query "', G, '" 2>/dev/null'], Out),
    re_lines(Pattern, Out, Ls).

%% one file into a shared knowledge base, the way `cocolog consult' does
wire_consult(KB, File) :-
    coco_bin(C), dial(D),
    ( shl([C, ' ', D, ' --kb ', KB, ' consult ', File, ' >/dev/null 2>&1'])
    -> true ; true ).

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
iso(L0, Goal) :-
    label(L0, L),
    (   run_isolated(Goal, true)
    ->  format("ok   ~w~n", [L])
    ;   format("FAIL ~w~n", [L]), assertz('$check_failed'(L))
    ).

%% A LABEL WRITTEN WITH DOUBLE QUOTES IS A CODE LIST, because
%% `double_quotes' is `codes' here and "a segment's end" is the only way
%% to write an apostrophe without escaping it. Printed with ~w that is a
%% row of numbers, which is what the first two converted cases did before
%% anybody looked. The harness absorbs it: a code list becomes the text
%% it spells, and every other term is left alone.
label(L0, L) :-
    (   is_list(L0), L0 = [C|_], integer(C)
    ->  atom_codes(L, L0)
    ;   L = L0
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

%% RUN IT AND KEEP THE OUTPUT, WHATEVER IT EXITED WITH. `shl/2' is
%% `proc_run' expecting status 0, which is right for a command whose
%% failure is a failure -- and wrong for one whose non-zero status is an
%% ANSWER. `cocolog step' exits with the turn's outcome, so a machine
%% that suspended at its budget -- the success this suite is checking for
%% -- comes back non-zero and shl/2 fails on it. The .sh cases never saw
%% this because they piped into grep and read GREP's status instead.
sh_any(Parts, Out) :-
    ( is_list(Parts) -> sh_join(Parts, C0) ; C0 = Parts ),
    sh_join([C0, ' ; true'], C),
    sh(C, Out).

%% SH_JOIN CONCATENATES, IT DOES NOT SEPARATE, which is right for
%% building one command out of fragments and wrong for a list of file
%% names -- five paths came out as one word, and the process that got it
%% printed nothing and failed in a way that named nothing. Where the
%% parts are ARGUMENTS rather than fragments, this is the join.
join_sp([], '').
join_sp([X], X) :- !.
join_sp([X|Xs], J) :- join_sp(Xs, R), sh_join([X, ' ', R], J).

%% ---- who is asking ------------------------------------------------------

%% NODE IDENTITY ARRIVES FROM THE ENVIRONMENT -- `ledger/node.pl' reads
%% NODE_NAME and NODE_KEY with getenv/2, at call time -- so a scene that
%% needs to BE somebody sets them first. The .sh cases did this by
%% spawning a whole cocolog per identity, one process per check; setenv/2
%% makes it a property of the scene instead.
%%
%% IT IS NOT A SUBSTITUTE FOR A SECOND PROCESS, and the distinction is
%% the one this harness turns on: `as/2' changes WHO IS ASKING inside one
%% process, which is what a settlement or a signature check needs.
%% `wire/4' and `solo/3' are what a claim about two PROCESSES sharing a
%% knowledge base needs, and no amount of setenv makes one into the
%% other.
node_key(alice, '1111111111111111111111111111111111111111111111111111111111111111').
node_key(bob,   '2222222222222222222222222222222222222222222222222222222222222222').
node_key(carol, '3333333333333333333333333333333333333333333333333333333333333333').
node_key(dave,  '4444444444444444444444444444444444444444444444444444444444444444').
node_key(mallory, '6666666666666666666666666666666666666666666666666666666666666666').

as(Who, Goal) :-
    ( node_key(Who, K) -> true ; K = Who ),
    setenv('NODE_NAME', Who),
    setenv('NODE_KEY', K),
    call(Goal).

%% the same, as a check: one isolated proof, run as somebody
iso_as(Who, L, Goal) :- iso(L, as(Who, Goal)).

%% A SECTION HEADING IS A LABEL TOO, and a heading written with double
%% quotes -- the only way to put an apostrophe in one without escaping it
%% -- is a code list, printed by ~w as a row of numbers. label/2 absorbs
%% it here for the same reason it does in iso/2, and for the same reason
%% it exists at all: the first case to write one found out by reading the
%% output, which is not a thing a suite should rely on.
section(S0) :- label(S0, S), format("~n-- ~w~n", [S]).

skip(Why) :- format("SKIP ~w~n", [Why]).

%% ---- modules, and the SKIP when one will not build ----------------------

%% A module this repository builds for itself. Missing means no sbcl or
%% no CICILI checkout, which is a SKIP with its reason and not a red line.
have_module(M) :- coco_lib(M, P), atom_concat(P, '.so', S), exists_file(S).

%% A TOOL THIS SUITE NEEDS, looked for along PATH by library(os) --
%% access(2), no shell, and one spelling for `command -v X >/dev/null
%% 2>&1'. The .sh cases each carried their own.
have_tool(Tool) :- os_has(Tool).

build_modules(Group) :-
    coco_root(R), sh_join([R, '/modules/', Group, '/build.sh'], B),
    ( exists_file(B) -> catch(shl(['sh ', B, ' >/dev/null 2>&1']), _, true) ; true ).

%% Ask for a group's modules, building them once if they are not there;
%% answer whether they are all present afterwards.
modules_ready(Group, Ms) :-
    ( forall(member(M, Ms), have_module(M)) -> true ; build_modules(Group) ),
    forall(member(M, Ms), have_module(M)).
