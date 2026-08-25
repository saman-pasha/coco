%% library(stake) -- proof of stake: who may vote, and how much they weigh.
%%
%%   stake_of(?Who, -Amount)       what one validator weighs
%%   stake_table(-Pairs)           Who-Amount, sorted by name
%%   validators(-Names)            everyone with a positive stake
%%   total_stake(-Total)
%%   quorum(+Total, -Q)            the smallest stake that is MORE than 2/3
%%   fault_bound(+Total, -F)       and the largest that is at most 1/3
%%   has_stake(+Who)
%%   leader(+Seed, +Height, -Who)  the draw: deterministic, stake-weighted
%%   draw_index(+Hash, +Total, -I)
%%
%% THE STAKE TABLE IS NOT HERE, exactly as the authority set is not in
%% library(poa). `stake_entry(Who, Amount)' is supplied by whoever loads
%% this -- and in this rung the loader derives it FROM THE CHAIN, by
%% reading the blocks whose payload is a stake entry. That is the whole
%% difference between rung 2 and rung 6: an authority is declared in a
%% file every node is handed, and a validator is a QUERY over rows every
%% node already has.
%%
%% Entries ACCUMULATE. A validator that stakes twice weighs the sum, so a
%% top-up is a new block rather than an edit, and nothing is ever
%% retracted -- the same append-only discipline the ledger runs on.
%%
%% WHY 2/3. A quorum must be large enough that two of them intersect in
%% more than a third of the stake, because that intersection is the set
%% of validators who voted for two different blocks at one height. With
%% Q = 2T/3 + 1, two quorums share at least 2Q - T = T/3 + 2 of the
%% stake: strictly more than the fault bound. That is not a convention,
%% it is the arithmetic the whole safety argument rests on, and
%% `culprits/3' in library(bft) is what turns it into evidence.

:- use_module(library(sha256)).
:- use_module(library(bytes)).
:- use_module(library(lists)).

:- dynamic stake_entry/2.

%% A validator's weight is the sum of everything staked to it. `findall'
%% and not a single lookup: two entries for one name is a top-up, not a
%% contradiction.
stake_of(Who, Amount) :-
    validators(Names),
    member(Who, Names),
    findall(A, stake_entry(Who, A), As),
    sum_list(As, Amount).

stake_table(Pairs) :-
    validators(Names),
    findall(N-A, (member(N, Names), stake_of(N, A)), Pairs).

validators(Names) :-
    findall(N, (stake_entry(N, A), A > 0), Raw),
    sort(Raw, Names).

total_stake(Total) :-
    findall(A, stake_entry(_, A), As),
    sum_list(As, Total).

has_stake(Who) :-
    stake_entry(Who, A),
    A > 0,
    !.

%% The smallest integer strictly greater than two thirds. Integer
%% arithmetic on purpose: a threshold that depends on a floating point
%% comparison is a threshold two nodes can disagree about.
quorum(Total, Q) :- Q is (Total * 2) // 3 + 1.

fault_bound(Total, F) :- F is Total // 3.

%% ---- the draw --------------------------------------------------------
%%
%% WHOSE TURN IT IS, AS A FUNCTION OF CHAIN STATE. The seed is something
%% every node already holds -- in this rung the head's hash -- so every
%% node computes the same leader for the same height without being told,
%% and a node that was offline computes it too, from rows alone.
%%
%% The draw is STAKE-WEIGHTED: the hash is reduced to a point in
%% [0, Total) and the sorted stake table is walked until that point is
%% passed. A validator with twice the stake occupies twice the interval
%% and is drawn twice as often. Nothing here is random; it is a fixed
%% function of two inputs, which is what makes it checkable.
%%
%% IT IS GRINDABLE, AND THAT IS AN ACCEPTED TRADE. The seed is chain
%% state, and whoever produces the block that becomes the seed can try
%% payloads until the next draw favours them. Inside a certificate-gated
%% federation -- where every validator is a named party who had to be
%% admitted -- that is a cost worth paying for a leader schedule anyone
%% can recompute from rows. Outside one it is not, and it would want a
%% VRF or an unbiasable beacon. `attack_grind' in votes/mallory.pl does
%% it, succeeds, and is in the suite as a success.
leader(Seed, Height, Who) :-
    total_stake(Total),
    Total > 0,
    atomic_list_concat([Seed, Height], '|', Text),
    sha256(Text, Hash),
    draw_index(Hash, Total, I),
    stake_table(Table),
    walk_stake(Table, I, Who).

%% Four bytes of the hash, folded big-endian, taken modulo the total.
%% Four and not thirty-two because the result is reduced modulo a small
%% number anyway and a bignum is not needed to pick a name out of a list.
draw_index(Hash, Total, I) :-
    hex_bytes(Hash, Bytes),
    Bytes = [B0, B1, B2, B3|_],
    V is ((B0 * 256 + B1) * 256 + B2) * 256 + B3,
    I is V mod Total.

walk_stake([Who-A|T], I, Winner) :-
    (   I < A
    ->  Winner = Who
    ;   J is I - A,
        walk_stake(T, J, Winner)
    ).
