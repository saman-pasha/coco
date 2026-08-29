%% A counting loop: the sum of 1..N, one addition at a time. Nothing but
%% arithmetic and control -- the cheapest thing a language does, and the
%% one where an interpreter's per-step cost is the whole measurement.
%%
%%   main(+N)   answer is the sum

sumto(0, A, A) :- !.
sumto(K, A0, A) :-
    A1 is A0 + K,
    K1 is K - 1,
    sumto(K1, A1, A).

%% One rep is one full count to N, and every rep answers the same sum.
reps(0, _, S, S) :- !.
reps(K, N, _, S) :-
    sumto(N, 0, S0),
    K1 is K - 1,
    reps(K1, N, S0, S).

main(N, Reps) :-
    reps(Reps, N, 0, S),
    format("answer(~w)~n", [S]).
