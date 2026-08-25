%% A validator: read the stake off the chain, draw the leader, vote, lock,
%% and finalise.
%%
%%   stake_from_chain          who may vote, derived from blocks
%%   leader_at(+H, -Who)       whose turn it is, from chain state
%%   do_prevote(+H, +R, +Hash)
%%   do_precommit(+H, +R, +Hash)   the vote and the lock, in ONE goal
%%   learn_pol(+H, +R, +Hash)  verify a prevote quorum and record it
%%   gather(+Kind, +H, +R, +Hash, -QC)
%%   finalize(+H, +R, +Hash)   a precommit quorum makes a block FINAL
%%   final_head(-H, -Hash)     the deepest finalised block
%%   votes_report
%%
%% WHERE THIS SITS. Rung 2's ledger still orders blocks and still closes
%% forks by rule; this rung adds FINALITY on top of it. A block with a
%% precommit certificate is not a tip that fork choice might reconsider
%% later -- it is settled, and `extends_final/2' is where a longer but
%% conflicting chain stops being a candidate no matter how long it gets.
%%
%% THE VOTES ARE ROWS, like everything else here. A validator is a
%% cocolog invocation that reads the chain, casts one vote and exits;
%% there is no round timer, no leader announcement and no daemon. What
%% another validator has voted is a row it can read, which is why a
%% quorum certificate can be assembled by anyone at all.

:- use_module(library(pos)).
:- use_module(library(bft)).
:- use_module(library(poa)).
:- use_module(library(lists)).

:- dynamic vote/6.        % vote(Kind, Height, Round, BlockHash, Who, Sig)
:- dynamic lock_row/3.    % lock_row(Height, Round, BlockHash)
:- dynamic pol_row/3.     % pol_row(Height, Round, BlockHash)
:- dynamic final/2.       % final(Height, BlockHash)
:- dynamic stake_seen/1.  % the block an entry was read out of

%% ---- the stake, as a query over the chain ----------------------------
%%
%% THIS IS THE RUNG'S FIRST CLAIM. Rung 2's federation is a file handed
%% to every node; a validator set here is derived from blocks the node
%% already holds. Stake a token by sealing `stake(Name, Amount)' as an
%% ordinary payload, and every node that has the block agrees who may
%% vote -- with no roster to distribute and nothing to keep in step.
%%
%% A payload that is not a stake entry is skipped rather than refused:
%% the chain carries contracts and submissions too, and a rule that
%% choked on somebody else's payload would be a rule that only works on
%% a chain used for one thing.
%% A BLOCK IS COUNTED ONCE. Entries accumulate on purpose -- a top-up is
%% a second block, not an edit -- so nothing here can tell a genuine
%% second entry from the same entry read twice EXCEPT the block it came
%% from. Hence `stake_seen/1': the hash of the block the entry was read
%% out of. Without it, a validator that ran this twice would hold double
%% the stake and disagree with every peer about the quorum, from rows
%% that were all perfectly correct.
%%
%% Collected first and asserted second, rather than asserting inside the
%% enumeration: a write that is visible to the query still producing the
%% rows is a loop whose length depends on when the store flushes.
stake_from_chain :-
    findall(Hash-entry(Who, Amount),
            ( block(_, _, _, Payload, _, Hash),
              stake_payload(Payload, Who, Amount) ),
            Es),
    learn_stake(Es).

learn_stake([]).
learn_stake([Hash-entry(W, A)|T]) :-
    (   stake_seen(Hash)
    ->  true
    ;   assertz(stake_entry(W, A)),
        assertz(stake_seen(Hash))
    ),
    learn_stake(T).

stake_payload(Payload, Who, Amount) :-
    catch(term_to_atom(T, Payload), _, fail),
    nonvar(T),
    T = stake(Who, Amount),
    integer(Amount),
    Amount > 0.

%% ---- the draw --------------------------------------------------------
%%
%% The seed is the head's hash: chain state every node holds, so every
%% node draws the same leader for the same height without being told and
%% a node that was offline draws it too.
head_seed(Seed) :- ledger_head(head(_, Seed, _)).

leader_at(H, Who) :-
    head_seed(Seed),
    leader(Seed, H, Who).

validator_identity(Name, Priv) :-
    getenv('NODE_NAME', Name),
    getenv('NODE_KEY', Priv).

%% ---- proposing -------------------------------------------------------
%%
%% The proposal IS an ordinary ledger block. Rung 2 already seals, hashes,
%% signs and gossips; there is nothing a proposal needs that a block does
%% not already have, and inventing a second thing to carry the same
%% payload would only be a second thing to keep in step.
may_propose(H) :-
    validator_identity(Me, _),
    leader_at(H, Me).

%% AND A VOTER CHECKS THE PROPOSER, from the block itself. The seed is
%% the block's OWN parent -- not this node's current head -- so the
%% question "was this author drawn for this height" has the same answer
%% forever, on every node, including one that reads the chain a year
%% later. A rule that depended on the reader's head would give different
%% answers to different readers, which is not a rule.
proposal_ok(H, BlockHash) :-
    block(H, Prev, Author, _, _, BlockHash),
    leader(Prev, H, Author).

%% What a validator actually does with a proposal: check who made it,
%% then say it would accept it.
prevote_block(H, R, BlockHash) :-
    proposal_ok(H, BlockHash),
    do_prevote(H, R, BlockHash).

%% ---- voting ----------------------------------------------------------

do_prevote(H, R, BlockHash) :-
    validator_identity(Me, Priv),
    has_stake(Me),
    cast(Priv, prevote, H, R, BlockHash, Sig),
    assertz(vote(prevote, H, R, BlockHash, Me, Sig)).

%% THE VOTE AND THE LOCK ARE ONE GOAL, so they are one transaction. A
%% precommit visible without the lock that binds it would be a validator
%% that had voted and was still free to vote again; a lock without its
%% vote would be a validator bound to a block it never endorsed. Neither
%% is reachable, and that is a property of the store rather than of care
%% taken here -- the same guarantee `ledger_seal/1' leans on one rung
%% down.
%%
%% The lock rule is consulted BEFORE anything is written, so a validator
%% that is bound elsewhere simply fails to precommit. It does not throw:
%% being unable to vote is an ordinary answer.
do_precommit(H, R, BlockHash) :-
    validator_identity(Me, Priv),
    has_stake(Me),
    current_lock(H, Lock),
    my_pols(Pols),
    locked_ok(Lock, H, R, BlockHash, Pols),
    cast(Priv, precommit, H, R, BlockHash, Sig),
    ( assertz(vote(precommit, H, R, BlockHash, Me, Sig)),
      assertz(lock_row(H, R, BlockHash)) ).

%% The lock at a height is the one from the HIGHEST round, because a
%% released lock is replaced by a new row rather than by an edit. Nothing
%% is retracted, so what this validator was bound to and when is still on
%% the record.
current_lock(H, Lock) :-
    findall(R-B, lock_row(H, R, B), Rs),
    (   Rs == []
    ->  Lock = none
    ;   keysort(Rs, Sorted),
        last(Sorted, R2-B2),
        Lock = lock(H, R2, B2)
    ).

my_pols(Pols) :- findall(pol(H, R, B), pol_row(H, R, B), Pols).

%% A POL IS NOT TAKEN ON ANYONE'S WORD. The prevote certificate is
%% checked here, by this validator, against this validator's own view of
%% the stake -- and only then does it become a reason to change a lock.
%% A lock that could be released by an unverified claim is not a lock.
learn_pol(H, R, BlockHash) :-
    gather(prevote, H, R, BlockHash, QC),
    qc_valid(QC),
    assertz(pol_row(H, R, BlockHash)).

%% ---- certificates ----------------------------------------------------
%%
%% Assembled from whatever votes this node holds. Anyone can do this --
%% there is no aggregator role and no leader collecting signatures -- and
%% two nodes holding the same votes build the same certificate.
gather(Kind, H, R, BlockHash, qc(Kind, H, R, BlockHash, Votes)) :-
    findall(vote(Kind, H, R, BlockHash, W, S),
            vote(Kind, H, R, BlockHash, W, S), Raw),
    sort(Raw, Votes).

%% ---- finality --------------------------------------------------------
%%
%% A precommit quorum makes a block final. `final/2' is what separates
%% this rung from rung 2: a tip is a candidate fork choice may revisit,
%% and a finalised block is not -- no chain that omits it is a chain any
%% more, however long it grows.
finalize(H, R, BlockHash) :-
    gather(precommit, H, R, BlockHash, QC),
    qc_valid(QC),
    assertz(final(H, BlockHash)).

final_head(H, Hash) :-
    findall(A-B, final(A, B), Fs),
    Fs \== [],
    keysort(Fs, Sorted),
    last(Sorted, H-Hash).

%% A candidate chain is only a candidate if it CONTAINS every finalised
%% block. This is the whole of what finality buys, and it is one rule:
%% fork choice may prefer whatever it likes among chains that pass here,
%% and has nothing to say about the ones that do not.
extends_final(Hash) :-
    chain_from(Hash, Blocks),
    forall(final(FH, FHash),
           member(block(FH, _, _, _, _, FHash), Blocks)).

%% ---- gossip ----------------------------------------------------------
%%
%% The same shape as `ledger_export/0' and `ledger_sync/1' one rung down,
%% and for the same reason: a knowledge base is already readable, so the
%% wire protocol is one node reading another's rows and offering them.
%%
%% EVERY OFFERED VOTE IS RE-VERIFIED. A peer's word that a signature is
%% good is a claim; `valid_vote/1' is cheap next to believing it. A vote
%% that does not check out is skipped rather than refused, because a
%% batch containing one bad vote is not a bad batch.
%% `~q' rather than hand-written quotes, for the reason ledger_export/0
%% now carries at length: an exported term is goal text a peer reads
%% back, and an atom containing a quote has to come out with that quote
%% doubled. A block hash never contains one, so this was never wrong
%% here -- but a rule that is only right because of what its data happens
%% to look like is a rule waiting for different data.
votes_export :-
    forall(vote(K, H, R, B, W, S),
           format("vote(~q,~q,~q,~q,~q,~q).~n", [K, H, R, B, W, S])).

votes_sync([]).
votes_sync([vote(K, H, R, B, W, S)|T]) :-
    (   vote(K, H, R, B, W, S)
    ->  true                                   % already have it
    ;   valid_vote(vote(K, H, R, B, W, S))
    ->  assertz(vote(K, H, R, B, W, S))
    ;   true                                   % not verifiable: skip
    ),
    votes_sync(T).

%% ---- reporting -------------------------------------------------------

votes_report :-
    total_stake(Total),
    quorum(Total, Q),
    validators(Vs),
    length(Vs, N),
    format("validators ~w stake ~w quorum ~w~n", [N, Total, Q]).

stake_report :-
    forall(( stake_table(Pairs), member(W-A, Pairs) ),
           format("stake ~w ~w~n", [W, A])).
