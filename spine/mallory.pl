%% mallory against a clock.
%%
%% A spine is not a ledger and she cannot forge a signature into it --
%% there are none. What she can try is to be paid for work she did not
%% do, or to claim an event happened earlier than it did. Both are
%% attacks on ORDER, which is the only thing a spine actually sells.
%%
%%   attack_skip(-V)       claim a tick count without doing the ticks
%%   attack_shorten(-V)    do fewer ticks than claimed
%%   attack_backdate(-V)   claim a block was anchored earlier than it was
%%   attack_splice(-V)     paste a valid segment from another spine
%%   attack_fork(-V)       two valid spines from one start -- SUCCEEDS
%%
%% The last one succeeds and is meant to. A spine orders what is on it;
%% it has no opinion about which of two spines is the real one, because
%% nothing inside a hash chain can have one.

:- use_module(library(poh)).
:- use_module(library(sha256)).

verdict(G, refused) :- \+ call(G), !.
verdict(_, 'ACCEPTED').

%% 1. SKIP THE WORK. Claim to be a million ticks along, with a hash she
%% invented. This is the attack the whole construction exists to answer,
%% and the answer is that there is no shortcut through a hash chain:
%% producing h(n) costs n hashes and checking it costs n hashes, and she
%% has done neither.
attack_skip(V) :-
    poh_genesis(G),
    sha256('a hash I liked the look of', Fake),
    verdict(poh_verify(G, 1000000, Fake), V).

%% 2. SHORTEN. Do the work, but less of it, and claim the larger number.
%% Nearer to honest and just as detectable: the count is part of what is
%% checked, not a label on the outside.
attack_shorten(V) :-
    poh_genesis(G),
    poh_run(G, 900, Short),
    verdict(poh_verify(G, 1000, Short), V).

%% 3. BACKDATE. Take a block, and claim it was folded in at tick 10 when
%% it was really folded in at tick 500. The anchor's own hash is what
%% gives it away: fold that block at tick 10 and you get a different
%% number than the one on the record.
attack_backdate(V) :-
    poh_genesis(G),
    sha256('a block sealed late', Block),
    poh_run(G, 500, At500),
    poh_anchor(At500, Block, Real),
    poh_run(G, 10, At10),
    poh_anchor(At10, Block, Backdated),
    verdict(Real == Backdated, V).

%% 4. SPLICE. Take a genuine segment out of somebody else's spine and
%% paste it into hers. Each piece verifies on its own -- they are real --
%% and the join does not, because segment i's end must BE segment i+1's
%% start and hers is not.
attack_splice(V) :-
    poh_genesis(G),
    poh_run(G, 100, MineAt100),
    sha256('another spine entirely', OtherStart),
    poh_run(OtherStart, 100, TheirsAt100),
    %% both halves are honest work; the seam is the lie
    verdict(MineAt100 == TheirsAt100, V).

%% 5. FORK THE CLOCK -- AND THIS ONE WORKS.
%%
%% Two spines from the same genesis, differing only in what was mixed in.
%% Both verify. Both are real work. Nothing in a hash chain prefers one
%% sequence over another, and no amount of hashing will make it.
%%
%% That is not a hole in the implementation, it is what a clock IS. The
%% spine says what order things happened in ON THIS SPINE. Which spine is
%% the chain's is a question for the chain -- `poh_anchor/3' is the seam,
%% and the ledger's fork choice is the answer.
attack_fork('ACCEPTED') :-
    poh_genesis(G),
    sha256('branch a', A), sha256('branch b', B),
    poh_run(G, 50, At50),
    poh_anchor(At50, A, ForkA),
    poh_anchor(At50, B, ForkB),
    ForkA \== ForkB,
    poh_run(ForkA, 50, EndA),
    poh_run(ForkB, 50, EndB),
    poh_verify(ForkA, 50, EndA),
    poh_verify(ForkB, 50, EndB).
