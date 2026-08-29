%% N facts, then M lookups by key. THIS IS THE ONE THAT SHOWS THE
%% ARCHITECTURE: cocolog has no clause indexing, so a lookup walks the
%% clauses in order, while Python's dict is a hash. The ratio here is not
%% a constant factor, it grows with N -- which is why the harness prints
%% two sizes of it.
%%
%%   main(+N, +M)   assert N facts, probe M keys; answer is their sum

:- dynamic f/2.

build(0) :- !.
build(K) :-
    V is (K * 7) mod 1000,
    assertz(f(K, V)),
    K1 is K - 1,
    build(K1).

probe(0, _, A, A) :- !.
probe(M, N, A0, A) :-
    K is ((M * 37) mod N) + 1,
    ( f(K, V) -> A1 is A0 + V ; A1 = A0 ),
    M1 is M - 1,
    probe(M1, N, A1, A).

%% One rep is a sweep of a THOUSAND probes over the same N clauses, so
%% the answer is the same however many sweeps the harness runs.
sweeps(0, _, S, S) :- !.
sweeps(K, N, _, S) :-
    probe(1000, N, 0, S0),
    K1 is K - 1,
    sweeps(K1, N, S0, S).

main(N, Reps) :-
    build(N),
    sweeps(Reps, N, 0, S),
    format("answer(~w)~n", [S]).
