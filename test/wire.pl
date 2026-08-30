%% wire: one process WRITES a module's clauses into a knowledge base, and
%% a second -- which consulted nothing -- reads them back.
%%
%% THE FAMILY'S CROSS-PROCESS CLAIM, made from this repository and made in
%% the smallest possible way: `consult' puts modules/hello.pl into a
%% knowledge base on the server, a separate cocolog opens the same base and
%% proves a goal over clauses it never loaded. Every other case that says
%% "a bare process reads it back" is this sentence with a chain in it.
%%
%% SKIPS WITHOUT A SERVER, because "no server here" and "the hub is wrong"
%% are different findings, and a case that cannot tell them apart reports
%% the second when it means the first.
%%
%% AND IT MUST SPAWN. This is the one claim run_isolated/2 cannot make at
%% all: a fresh machine in THIS process shares this process's connection,
%% and what is being proved is that a second PROCESS finds the clauses.
%%
%% Run:  cocolog -s test/wire.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

wire_half :-
    zig(kb, KB),
    wire_forget(KB),
    wire_consult(KB, 'modules/hello.pl'),
    iso('a second process, which consulted nothing, reads the clauses back',
        ( (   wire(KB, 'pillar(coco, Role, Deed), write(Role), write('' ''), write(Deed), nl',
                   '^engineer', A)
          ->  true ;  A = none ),
          want(A, 'engineer makes it think') )),
    wire_forget(KB).

main :-
    (   server_up
    ->  wire_half
    ;   skip('no Zigurat server')
    ),
    nl, checks_done.
