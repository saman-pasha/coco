%% Sort N pseudo-random integers. Both sides generate the SAME numbers
%% from the same linear congruential recurrence, so the answer checksums
%% agree only if both sorted the same list.
%%
%%   main(+N)   answer is a checksum over the sorted list

lcg(0, _, []) :- !.
lcg(K, X0, [X|T]) :-
    X1 is (1103515245 * X0 + 12345) mod 2147483648,
    X is X1 mod 100000,
    K1 is K - 1,
    lcg(K1, X1, T).

sum31([], A, A).
sum31([H|T], A0, A) :- A1 is (A0 * 31 + H) mod 1000003, sum31(T, A1, A).

%% One rep is one generate-and-sort, and every rep answers the same
%% checksum.
reps(0, _, C, C) :- !.
reps(K, N, _, C) :-
    lcg(N, 12345, L),
    msort(L, S),
    sum31(S, 0, C0),
    K1 is K - 1,
    reps(K1, N, C0, C).

main(N, Reps) :-
    reps(Reps, N, 0, C),
    format("answer(~w)~n", [C]).
