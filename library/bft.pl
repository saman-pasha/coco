%% library(bft) -- votes, quorum certificates, and the lock.
%%
%%   vote_signable(+Kind, +H, +R, +BlockHash, -Text)
%%   vote_hash(+Kind, +H, +R, +BlockHash, -Hash)
%%   cast(+PrivHex, +Kind, +H, +R, +BlockHash, -Sig)
%%   valid_vote(+vote(Kind,H,R,BlockHash,Who,Sig))
%%
%%   qc_valid(+qc(Kind,H,R,BlockHash,Votes))   the counting rule
%%   qc_stake(+Votes, -Stake)
%%   qc_voters(+Votes, -Names)
%%
%%   locked_ok(+Lock, +H, +R, +BlockHash, +Pols)   may I precommit this
%%   equivocation(+Votes, -Who, -evidence(V1,V2))
%%   culprits(+QC1, +QC2, -Names)                  who must have lied
%%
%% A QUORUM CERTIFICATE IS A COUNTING RULE, NOT A MESSAGE TYPE. There is
%% no protocol here, no rounds driven by timers, no leader announcing
%% anything: a certificate is a LIST OF SIGNATURES and a predicate that
%% says whether the list is enough. Any node holding the votes can build
%% one, any node holding a certificate can check it alone, and two nodes
%% checking the same certificate reach the same answer because the rule
%% is the same clauses on both.
%%
%% TWO PHASES, because one is not enough. A PREVOTE says "I would accept
%% this block"; a PRECOMMIT says "I am bound to it". A quorum of prevotes
%% -- a POL, a proof of lock change -- is the only thing that releases a
%% validator from a previous precommit. Without the second phase a
%% validator could be shown a quorum for a block, commit, and then see a
%% different quorum for a different block at the same height with nobody
%% having done anything provably wrong.
%%
%% WHAT MAKES IT ACCOUNTABLE. Two valid certificates for different blocks
%% at one height cannot exist unless more than a third of the stake voted
%% for both -- that is `culprits/3', and its arithmetic is in
%% library(pos). Byzantine fault tolerance here is not "the bad case
%% cannot happen"; it is "the bad case names the validators who caused
%% it", and a name is what a slashing rule needs.

:- use_module(library(sha256)).
:- use_module(library(secp256k1)).
:- use_module(library(pos)).
:- use_module(library(poa)).      % for `authority/2': whose key is whose
:- use_module(library(lists)).

%% WHAT IS SIGNED IS THE WHOLE VOTE. Kind, height, round and block hash
%% are all in the text, so a prevote cannot be replayed as a precommit, a
%% vote at one height cannot be moved to another, and a signature over
%% block A cannot be relabelled as a vote for block B. The separator is
%% the same discipline as `block_signable/5' and for the same reason.
vote_signable(Kind, H, R, BlockHash, Text) :-
    atomic_list_concat([vote, Kind, H, R, BlockHash], '|', Text).

vote_hash(Kind, H, R, BlockHash, Hash) :-
    vote_signable(Kind, H, R, BlockHash, Text),
    sha256(Text, Hash).

cast(Priv, Kind, H, R, BlockHash, Sig) :-
    vote_hash(Kind, H, R, BlockHash, Hash),
    secp256k1_sign(Priv, Hash, Sig).

%% A VOTE IS VALID WHEN THE VOTER HAS STAKE AND THE SIGNATURE IS THEIRS.
%% Stake first, because it is a row lookup and the signature check is an
%% elliptic curve operation: a vote from a stranger is refused without
%% paying for the curve.
valid_vote(vote(Kind, H, R, BlockHash, Who, Sig)) :-
    has_stake(Who),
    validator_key(Who, Pub),
    vote_hash(Kind, H, R, BlockHash, Hash),
    secp256k1_verify(Hash, Sig, Pub).

%% Keys come from the same place the ledger's do -- `authority/2', the
%% federation file. Stake says how much a validator weighs; the
%% federation says which key is theirs. Two questions, two sources, and
%% neither one answers the other.
validator_key(Who, Pub) :- authority(Who, Pub).

%% ---- the counting rule ----------------------------------------------
%%
%% Every clause below is a way a certificate can be a lie, and each is
%% checked rather than assumed:
%%
%%   1. every vote is FOR THIS CERTIFICATE -- same kind, height, round
%%      and block. A list of votes for four different blocks is not a
%%      quorum for any of them;
%%   2. every vote is VALID -- staked voter, real signature;
%%   3. NO VOTER APPEARS TWICE. Without this, one validator's vote
%%      repeated three times is a quorum, which is the cheapest attack in
%%      this rung and the one a length check alone would miss;
%%   4. the STAKE of the voters is at least the quorum -- counted by
%%      weight and never by head count, because a validator with one
%%      token and one with a thousand are not the same vote.
qc_valid(qc(Kind, H, R, BlockHash, Votes)) :-
    Votes \== [],
    forall(member(V, Votes), vote_matches(V, Kind, H, R, BlockHash)),
    forall(member(V, Votes), valid_vote(V)),
    qc_voters(Votes, Names),
    length(Votes, N),
    length(Names, N),
    qc_stake(Votes, S),
    total_stake(Total),
    quorum(Total, Q),
    S >= Q.

vote_matches(vote(K, H, R, B, _, _), K, H, R, B).

qc_voters(Votes, Names) :-
    findall(W, member(vote(_, _, _, _, W, _), Votes), Raw),
    sort(Raw, Names).

qc_stake(Votes, Stake) :-
    qc_voters(Votes, Names),
    findall(A, (member(N, Names), stake_of(N, A)), As),
    sum_list(As, Stake).

%% ---- the lock --------------------------------------------------------
%%
%% A validator that has precommitted a block at a height is BOUND to it.
%% The only thing that releases it is proof that a quorum of the stake
%% prevoted something else in a LATER round -- a POL. Without the lock,
%% two quorums at one height need nobody to have done anything provably
%% wrong; with it, they need a third of the stake to have ignored its own
%% rule, and that is the difference between a protocol that is safe and
%% one that is merely usually right.
%%
%% Lock is `none' or `lock(Height, Round, BlockHash)'; Pols is a list of
%% `pol(Height, Round, BlockHash)' this validator has actually verified.
locked_ok(none, _, _, _, _) :- !.
locked_ok(lock(LH, _, _), H, _, _, _) :- H > LH, !.
locked_ok(lock(H, _, Hash), H, _, Hash, _) :- !.
locked_ok(lock(H, LR, _), H, _, Hash, Pols) :-
    member(pol(H, PR, Hash), Pols),
    PR > LR.

%% ---- evidence --------------------------------------------------------
%%
%% EQUIVOCATION IS THE ONE FAULT THAT PROVES ITSELF. A validator who
%% signs two different blocks at the same height and round has produced,
%% with its own key, a pair of documents that nobody else could have
%% made. Finding the pair is a search over votes anyone can run, and the
%% pair is the whole of the case -- there is nothing to corroborate and
%% nobody to believe.
equivocation(Votes, Who, evidence(V1, V2)) :-
    member(V1, Votes),
    V1 = vote(K, H, R, B1, Who, _),
    member(V2, Votes),
    V2 = vote(K, H, R, B2, Who, _),
    B1 @< B2,
    valid_vote(V1),
    valid_vote(V2).

%% Two certificates for different blocks at one height: the validators in
%% both. By the 2/3 arithmetic this set cannot be empty, and its stake is
%% strictly more than the fault bound -- so the certificates do not merely
%% disagree, they NAME the validators whose keys signed both sides.
culprits(qc(_, H, _, B1, V1), qc(_, H, _, B2, V2), Names) :-
    B1 \== B2,
    qc_voters(V1, N1),
    qc_voters(V2, N2),
    findall(N, (member(N, N1), memberchk(N, N2)), Names).
