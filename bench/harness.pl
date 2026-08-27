%% The TPS harness: what a reading has to carry before it may be printed.
%%
%%   reading(Lane, Count, Seconds, Arrangement, Verified)
%%   honest(+Reading)          every rule below, or nothing
%%   tps(+Reading, -Rate)      a rate, only from an honest reading
%%   verify_count(+Claimed, +Actual, -Verdict)
%%   report(+Reading)
%%
%% A BENCHMARK IS A CLAIM ABOUT A NUMBER, and a number is the easiest
%% thing in this repository to get wrong in a way nobody can see. Every
%% other rung has a criminal who attacks the rules; this one has a
%% criminal who attacks the MEASUREMENT, and each of her eight attempts
%% is a rule below.
%%
%% FIVE RULES, AND A READING THAT BREAKS ANY OF THEM IS NOT PRINTED:
%%
%%   1. THE COUNT IS VERIFIED AGAINST ROWS. A lane says it did N
%%      transactions; the harness counts what is actually in the store
%%      afterwards and refuses the reading unless the two agree. A
%%      transaction that did not commit is not a transaction, and this
%%      is the only rule that can catch that.
%%   2. THE RUN IS LONG ENOUGH. Under a second is process start-up and
%%      scheduler noise wearing a number's clothes.
%%   3. THE ARRANGEMENT IS NAMED. `--local' has no database in it and is
%%      not a database number; a batch is not N transactions; four
%%      writers on four knowledge bases is not four writers on one. A
%%      rate without its arrangement is not a smaller truth, it is a
%%      different claim.
%%   4. THE CLOCK IS THE WALL. CPU time makes a parallel run look like a
%%      serial one that went four times as fast.
%%   5. THE FIRST RUN IS THROWN AWAY. The store is cold, the pages are
%%      unread, and the number means nothing.
%%
%% WHAT NO RULE CAN CATCH is which workload was chosen, and that is
%% `attack_choose_the_workload' -- the one attack in this rung that
%% succeeds. A benchmark is only ever a statement about the workload it
%% ran, which is why every reading here carries its arrangement and why
%% no sentence anywhere compares this to anything.

:- dynamic reading/5.

%% Under a second is not a measurement.
min_seconds(1.0).

record(Lane, Count, Seconds, Arrangement, Verified) :-
    assertz(reading(Lane, Count, Seconds, Arrangement, Verified)).

%% The count came from the shell; the actual came from counting rows in
%% the store afterwards. They agree or the reading is worthless.
verify_count(Claimed, Actual, verified)   :- Claimed =:= Actual, !.
verify_count(_, _, unverified).

honest(reading(Lane, Count, Seconds, Arrangement, Verified)) :-
    atom(Lane),
    Verified == verified,
    Count > 0,
    min_seconds(M),
    Seconds >= M,
    nonvar(Arrangement),
    Arrangement \== none.

tps(Reading, Rate) :-
    honest(Reading),
    Reading = reading(_, Count, Seconds, _, _),
    Rate is Count / Seconds.

%% A reading prints with its arrangement or it does not print. There is
%% no format in this file that emits a rate on its own.
report(Reading) :-
    Reading = reading(Lane, Count, Seconds, Arrangement, _),
    (   tps(Reading, Rate)
    ->  format("~w ~2f ~w ~w ~3f~n", [Lane, Rate, Arrangement, Count, Seconds])
    ;   format("~w REFUSED ~w~n", [Lane, Arrangement])
    ).

%% Why a reading was refused, for the choreography to print.
refusal(Reading, Why) :-
    Reading = reading(Lane, Count, Seconds, Arrangement, Verified),
    (   \+ atom(Lane)                -> Why = 'the lane has no name'
    ;   Verified \== verified        -> Why = 'the count is not backed by rows'
    ;   Count =< 0                   -> Why = 'nothing happened'
    ;   min_seconds(M), Seconds < M  -> Why = 'the run was too short to mean anything'
    ;   ( var(Arrangement) ; Arrangement == none )
                                     -> Why = 'the arrangement is not named'
    ;   Why = none
    ).

%% ---- the scaling curve ------------------------------------------------
%%
%% Not a rate but a SHAPE: seconds per batch at increasing chain length.
%% A single rate hides it completely -- a system that is fast at length
%% zero and unusable at length ten thousand has a perfectly respectable
%% average, and the average is the least interesting thing about it.
:- dynamic scale_point/3.       % scale_point(Lane, Length, Seconds)

scale_shape(Lane, Shape) :-
    findall(L-S, scale_point(Lane, L, S), Raw),
    Raw \== [],
    keysort(Raw, Shape).

%% Flat, linear or worse, decided from the points rather than asserted.
%% The test is the ratio between the last gap and the first: a constant
%% cost gives about 1, a cost that grows with the length gives the ratio
%% of the lengths.
scale_verdict(Lane, Verdict) :-
    scale_shape(Lane, Shape),
    Shape = [_, _|_],
    Shape = [_-First|_],
    last(Shape, _-Last),
    First > 0,
    R is Last / First,
    (   R < 1.5 -> Verdict = flat
    ;   R < 12  -> Verdict = grows_with_length
    ;   Verdict = worse_than_linear
    ).
