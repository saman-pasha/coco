%% mallory reads the benchmark.
%%
%% Every earlier rung's criminal attacked a rule. This one attacks the
%% MEASUREMENT, which is the softest target on the ladder: a number
%% nobody can check is worth exactly as much as a signature nobody
%% verifies, and it is far easier to publish.
%%
%%   attack_count_uncommitted(-V)   claim work that never committed
%%   attack_batch_as_transactions(-V)  call one transaction N of them
%%   attack_cpu_time(-V)            divide by CPU time, not the wall
%%   attack_local_as_database(-V)   report a no-database run as a store rate
%%   attack_first_run(-V)           report the cold run
%%   attack_short_run(-V)           report a run too short to mean anything
%%   attack_no_arrangement(-V)      publish a rate with nothing attached
%%   attack_choose_the_workload(-V) pick the flattering lane -- SUCCEEDS
%%
%% The last one succeeds and no harness can stop it.

:- use_module(library(lists)).

verdict(G, refused) :- \+ call(G), !.
verdict(_, 'ACCEPTED').

%% 1. COUNT WHAT DID NOT COMMIT. She ran a thousand seals; the store has
%% four hundred, because the rest threw, or the turn was lost, or she
%% counted the loop rather than the writes. The number is real
%% arithmetic over a fictional numerator, and no amount of care about
%% the clock would catch it.
attack_count_uncommitted(V) :-
    verify_count(1000, 400, Verdict),
    verdict(honest(reading(seal, 1000, 4.0, server_one_kb, Verdict)), V).

%% 2. A BATCH IS ONE TRANSACTION. A hundred seals inside one turn commit
%% together: that is one transaction that wrote a hundred blocks, and it
%% is a perfectly good number to publish under that name. Published as
%% "a hundred transactions" it is off by a hundred.
%%
%% The harness cannot know what happened inside a turn, so it does not
%% try: the ARRANGEMENT carries it, and a lane that will not say which
%% one it ran does not print. She is refused at rule 3 rather than by
%% cleverness, which is the point of rule 3.
attack_batch_as_transactions(V) :-
    verdict(honest(reading(seal, 100, 41.7, none, verified)), V).

%% 3. THE WRONG CLOCK. Four workers for ten seconds of wall time burn
%% forty seconds of CPU. Dividing by the CPU makes a parallel run look
%% like a serial one that got four times faster, and the mistake is
%% invisible in the output -- both numbers are seconds.
%%
%% The harness takes seconds and cannot see which kind they are, so this
%% is not caught by a rule: it is caught by the harness never READING a
%% CPU clock. `date +%s.%N' is the only clock in bench/tps.sh, and the
%% check below is that a shorter number is not more honest.
attack_cpu_time(V) :-
    Wall = reading(parallel, 400, 10.0, server_four_kbs, verified),
    Cpu  = reading(parallel, 400, 2.5,  server_four_kbs, verified),
    tps(Wall, RW), tps(Cpu, RC),
    verdict(RC =< RW, V).

%% 4. `--local' HAS NO DATABASE IN IT. It is the fastest lane by a wide
%% margin and it measures the engine, not the system. Reporting it as a
%% store rate is the most common benchmark lie there is, and the only
%% defence is that the arrangement travels with the number.
attack_local_as_database(V) :-
    R = reading(validate, 250, 1.0, local_no_database, verified),
    tps(R, _),
    verdict(( R = reading(_,_,_,A,_), A == server_one_kb ), V).

%% 5. THE COLD RUN. The store has read no pages, the connection is new,
%% nothing is warm. The first number is always the worst and is never
%% the number.
%%
%% Refused by the harness DISCARDING it rather than by a check on the
%% reading -- so what this attack asks is whether the second run is the
%% one reported, and the answer has to come from the shell.
attack_first_run(V) :-
    Cold = reading(seal, 10, 4.0, server_one_kb, verified),
    Warm = reading(seal, 10, 2.5, server_one_kb, verified),
    tps(Cold, RCold), tps(Warm, RWarm),
    verdict(RCold >= RWarm, V).

%% 6. TOO SHORT TO MEAN ANYTHING. Under a second is process start-up and
%% scheduler noise wearing a number's clothes, and dividing by it makes
%% any rate you like.
attack_short_run(V) :-
    verdict(honest(reading(seal, 5, 0.2, server_one_kb, verified)), V).

%% 7. A NAKED RATE. No arrangement, so no claim -- and therefore nothing
%% anyone can check or reproduce.
attack_no_arrangement(V) :-
    verdict(honest(reading(seal, 100, 40.0, none, verified)), V).

%% 8. CHOOSE THE WORKLOAD -- AND THIS ONE WORKS.
%%
%% Every reading below is honest. Every one passes every rule. She simply
%% publishes the largest.
%%
%% NO HARNESS CAN REFUSE THIS, and pretending otherwise would be the
%% easy lie in a rung about not telling easy lies. A benchmark is only
%% ever a statement about the workload it ran; choosing the workload is
%% upstream of every rule a harness can have. The only defence is the one
%% this repository already uses everywhere else: publish the whole table,
%% name the arrangement on every line, and never write "competes with".
attack_choose_the_workload(V) :-
    Rs = [ reading(validate, 250, 1.0, local_no_database, verified),
           reading(seal,     100, 41.7, server_one_kb_batched, verified),
           reading(seal,      20, 13.5, server_one_kb_per_turn, verified) ],
    findall(Rate, (member(R, Rs), tps(R, Rate)), Rates),
    max_list(Rates, Best),
    min_list(Rates, Worst),
    %% she wanted a flattering number that is nonetheless entirely honest
    verdict(( Best > Worst * 10, forall(member(R2, Rs), honest(R2)) ), V).

%% For the choreography: the spread she is choosing from.
workload_spread(Best, Worst) :-
    Rs = [ reading(validate, 250, 1.0, local_no_database, verified),
           reading(seal,     100, 41.7, server_one_kb_batched, verified),
           reading(seal,      20, 13.5, server_one_kb_per_turn, verified) ],
    findall(Rate, (member(R, Rs), tps(R, Rate)), Rates),
    max_list(Rates, Best),
    min_list(Rates, Worst).
