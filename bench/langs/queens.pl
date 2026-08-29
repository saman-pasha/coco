%% N queens, ALL solutions counted -- backtracking search, which is the
%% one shape both languages express naturally: Prolog gets it from the
%% engine, Python writes the recursion by hand.
%%
%%   main(+N)   answer is the number of solutions (8 -> 92)

safe(_, _, []).
safe(Q, D, [P|Ps]) :-
    Q =\= P + D,
    Q =\= P - D,
    D1 is D + 1,
    safe(Q, D1, Ps).

place([], Qs, Qs).
place(Un, Placed, Qs) :-
    select(Q, Un, Un1),
    safe(Q, 1, Placed),
    place(Un1, [Q|Placed], Qs).

queens(N, Qs) :- numlist(1, N, Ns), place(Ns, [], Qs).

%% One rep is one whole search, and every rep answers the same count.
searches(0, _, C, C) :- !.
searches(K, N, _, C) :-
    findall(1, queens(N, _), L),
    length(L, C0),
    K1 is K - 1,
    searches(K1, N, C0, C).

main(N, Reps) :-
    searches(Reps, N, 0, C),
    format("answer(~w)~n", [C]).
