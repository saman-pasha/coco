%% naive reverse -- the classic Prolog benchmark, and a list-building
%% workload for anything else. `app/3' is quadratic on purpose: this
%% measures the cost of building and matching list cells, which is what a
%% Prolog engine is made of.
%%
%%   main(+N, +Reps)   reverse [1..N] Reps times; answer is a checksum

app([], L, L).
app([H|T], L, [H|R]) :- app(T, L, R).

nrev([], []).
nrev([H|T], R) :- nrev(T, RT), app(RT, [H], R).

sum31([], A, A).
sum31([H|T], A0, A) :- A1 is (A0 * 31 + H) mod 1000003, sum31(T, A1, A).

%% Every rep is the same unit of work and answers the same checksum, so
%% the ANSWER does not depend on how many reps the harness chose -- which
%% is what lets the two languages run different rep counts (each long
%% enough to be a measurement) and still be checked against each other.
rounds(0, _, C, C) :- !.
rounds(K, L, _, C) :-
    nrev(L, R), sum31(R, 0, C0),
    K1 is K - 1,
    rounds(K1, L, C0, C).

main(N, Reps) :-
    numlist(1, N, L),
    rounds(Reps, L, 0, C),
    format("answer(~w)~n", [C]).
