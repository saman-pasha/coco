%% local: the one cocolog binary consults modules/hello.pl and answers,
%% with no server anywhere.
%%
%% WHAT IT IS FOR. It is the suite's first case and its smallest: the
%% pillars built, the binary runs, a .pl file in this repository loads and
%% proves a goal. Everything after it assumes all four of those, so when
%% one of them is untrue this is the line that says so -- and it says it
%% without a store, a key or a chain in the way.
%%
%% IT SPAWNS, AND THAT IS THE CLAIM. `run_isolated/2' would prove that
%% pillar/3 has three clauses, which is not what is being asked: the
%% question is whether THE BINARY, started from a shell with a file and a
%% goal, prints the three lines. This case was those eight lines inline in
%% test/run.sh until the suite became cocolog scripts; it is a case now for
%% the reason the others are -- one shape of check, in one place.
%%
%% Run:  cocolog -s test/local.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

pillars(['cicili, the philosopher, writes it',
         'zigurat, the warrior, keeps it',
         'coco, the engineer, makes it think']).

%% every non-empty line of what a command printed, as atoms
lines(Cmd, As) :-
    (   sh_any(Cmd, O), re_lines('^.', O, Ls)
    ->  true ;  Ls = [] ),
    %% the empty tail a trailing newline leaves is not a line
    findall(A, ( member(L, Ls), L \== [], atom_codes(A, L) ), As).

main :-
    coco_bin(C), coco_root(R), pillars(Want),
    iso('the three pillars answer, from one binary and no server',
        ( lines(['timeout 60 ', C, ' run ', R, '/modules/hello.pl hello 2>&1'], Got),
          want(Got, Want) )),
    nl, checks_done.
