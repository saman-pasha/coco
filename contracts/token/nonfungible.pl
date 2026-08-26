%% contracts/token/nonfungible -- the non-fungible token standard, as rules.
%%
%% ERC-721's shape. Where a fungible token is a ledger of AMOUNTS, this
%% is a ledger of OWNERS: each id belongs to exactly one account, and the
%% whole standard is that sentence plus the ways an id may change hands.
%%
%%   nft_create(+Collection, +Name)
%%   nft_mint(+Collection, +To, +Id)      nft_burn(+Collection, +Id)
%%   nft_owner(+Collection, +Id, -Owner)  nft_balance(+Collection, +Who, -Count)
%%   nft_tokens(+Collection, +Who, -Ids)  nft_exists(+Collection, +Id)
%%   nft_approve(+Collection, +Owner, +Spender, +Id)
%%   nft_approved(+Collection, +Id, -Spender)
%%   nft_set_operator(+Collection, +Owner, +Operator, +OnOff)
%%   nft_is_operator(+Collection, +Owner, +Operator)
%%   nft_transfer_from(+Collection, +Caller, +From, +To, +Id)
%%   nft_conservation(+Collection)
%%
%% THE INVARIANT IS EXACTLY ONE OWNER. Not "at most" and not "at least":
%% an id that exists is owned once, and `nft_conservation/1' says so --
%% every id has one owner, and every account's stored balance equals the
%% number of ids it actually holds. A count kept beside the ownership
%% rows is a second copy of a fact, and the second copy is the one that
%% goes stale; this checks them against each other rather than trusting
%% the increment.
%%
%% THREE WAYS TO BE ALLOWED TO MOVE ONE, which is ERC-721's real
%% structure and the part reimplementations get wrong:
%%
%%   the OWNER may always move their own;
%%   an account APPROVED FOR THAT ONE ID may move it;
%%   an account approved as an OPERATOR for the owner may move any of
%%   theirs -- the "approval for all" a marketplace asks for.
%%
%% AND THE SINGLE-ID APPROVAL IS CLEARED BY THE TRANSFER. That is a
%% rule in the standard and it matters: without it, an approval granted
%% to a buyer would survive the sale and let them take the token back
%% from its new owner. The operator approval is NOT cleared, because it
%% belongs to the owner's relationship with the marketplace and not to
%% the token.
%%
%% IDS AND COUNTS ARE u256, the type money is written in here. An
%% ERC-721 id is a uint256 and is very often a hash rather than a
%% counter, so anything narrower would collide the moment a real
%% collection used one.

:- use_module(library(u256)).
:- use_module(library(lists)).

:- dynamic nft_collection/2.    % nft_collection(Collection, Name)
:- dynamic nft_own/3.           % nft_own(Collection, Id, Owner)
:- dynamic nft_count/3.         % nft_count(Collection, Who, Count)
:- dynamic nft_appr/3.          % nft_appr(Collection, Id, Spender)
:- dynamic nft_op/3.            % nft_op(Collection, Owner, Operator)

%% ---- the collection --------------------------------------------------

nft_create(Collection, Name) :-
    ground(Collection),
    \+ nft_collection(Collection, _),
    assertz(nft_collection(Collection, Name)).

nft_exists(Collection, Id) :-
    u256_dec(Id, Key),
    nft_own(Collection, Key, _).

nft_owner(Collection, Id, Owner) :-
    u256_dec(Id, Key),
    nft_own(Collection, Key, Owner).

nft_balance(Collection, Who, Count) :-
    nft_collection(Collection, _),
    (   nft_count(Collection, Who, C) -> Count = C ; Count = '0' ).

nft_tokens(Collection, Who, Ids) :-
    findall(Id, nft_own(Collection, Id, Who), Ids).

nft_bump(Collection, Who, Delta) :-
    nft_balance(Collection, Who, C),
    (   Delta == up -> u256_add(C, '1', C2) ; u256_sub(C, '1', C2) ),
    (   retract(nft_count(Collection, Who, _)) -> true ; true ),
    assertz(nft_count(Collection, Who, C2)).

%% ---- minting and burning ---------------------------------------------
%%
%% An id may be minted ONCE. Minting one that exists is not an update,
%% it is a second owner for the same thing, which is the one state this
%% standard exists to make impossible.
nft_mint(Collection, To, Id) :-
    nft_collection(Collection, _),
    ground(To),
    u256_dec(Id, Key),
    \+ nft_own(Collection, Key, _),
    assertz(nft_own(Collection, Key, To)),
    nft_bump(Collection, To, up).

nft_burn(Collection, Id) :-
    u256_dec(Id, Key),
    nft_own(Collection, Key, Owner),
    retract(nft_own(Collection, Key, Owner)),
    (   retract(nft_appr(Collection, Key, _)) -> true ; true ),
    nft_bump(Collection, Owner, down).

%% ---- permission ------------------------------------------------------

nft_approve(Collection, Owner, Spender, Id) :-
    u256_dec(Id, Key),
    nft_own(Collection, Key, Owner),          % only the owner may grant
    (   retract(nft_appr(Collection, Key, _)) -> true ; true ),
    assertz(nft_appr(Collection, Key, Spender)).

nft_approved(Collection, Id, Spender) :-
    u256_dec(Id, Key),
    nft_appr(Collection, Key, Spender).

nft_set_operator(Collection, Owner, Operator, on) :-
    !,
    nft_collection(Collection, _),
    ground(Owner), ground(Operator),
    (   nft_op(Collection, Owner, Operator) -> true
    ;   assertz(nft_op(Collection, Owner, Operator)) ).
nft_set_operator(Collection, Owner, Operator, off) :-
    nft_collection(Collection, _),
    (   retract(nft_op(Collection, Owner, Operator)) -> true ; true ).

nft_is_operator(Collection, Owner, Operator) :-
    nft_op(Collection, Owner, Operator).

%% The three ways, in one predicate, so that a caller cannot be allowed
%% by a path nobody wrote down.
nft_may_move(Collection, Caller, Id) :-
    u256_dec(Id, Key),
    nft_own(Collection, Key, Owner),
    (   Caller == Owner
    ;   nft_appr(Collection, Key, Caller)
    ;   nft_op(Collection, Owner, Caller)
    ),
    !.

%% ---- moving ----------------------------------------------------------
%%
%% FROM must actually be the owner: a transfer that names the wrong
%% source is refused even when the caller is allowed to move the token,
%% because the standard's event -- and every indexer reading it --
%% depends on `from' being true.
nft_transfer_from(Collection, Caller, From, To, Id) :-
    u256_dec(Id, Key),
    nft_own(Collection, Key, From),
    ground(To),
    nft_may_move(Collection, Caller, Id),
    retract(nft_own(Collection, Key, From)),
    assertz(nft_own(Collection, Key, To)),
    %% THE SINGLE-ID APPROVAL DIES WITH THE TRANSFER. Without this, an
    %% approval granted to a buyer would outlive the sale and let them
    %% take the token back from its new owner. The operator approval
    %% survives, because it is the owner's arrangement with a
    %% marketplace rather than anything about this token.
    (   retract(nft_appr(Collection, Key, _)) -> true ; true ),
    (   From == To
    ->  true
    ;   nft_bump(Collection, From, down),
        nft_bump(Collection, To, up)
    ).

%% ---- the invariant, as a predicate -----------------------------------
%%
%% Every id owned exactly once -- guaranteed by nft_own being retracted
%% and asserted together -- and every stored count equal to the ids
%% actually held. The second half is the one that catches a bug: the
%% count is a cache, and this is what proves the cache.
nft_conservation(Collection) :-
    findall(W, nft_count(Collection, W, _), Ws0),
    sort(Ws0, Ws),
    nft_counts_agree(Collection, Ws).

nft_counts_agree(_, []).
nft_counts_agree(Collection, [W|T]) :-
    nft_balance(Collection, W, Stored),
    nft_tokens(Collection, W, Ids),
    length(Ids, N),
    u256_dec(N, Actual),
    u256_cmp(Stored, Actual, '='),
    nft_counts_agree(Collection, T).
