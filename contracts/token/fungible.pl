%% contracts/token/fungible -- the fungible token standard, as rules.
%%
%% ERC-20's shape, which every chain has copied because every chain
%% needed the same thing: a ledger of balances, a way to move your own,
%% and a way to let somebody else move some of yours.
%%
%%   ft_create(+Token, +Symbol, +Decimals)
%%   ft_mint(+Token, +To, +Amount)        ft_burn(+Token, +From, +Amount)
%%   ft_balance(+Token, +Who, -Amount)    ft_total(+Token, -Amount)
%%   ft_transfer(+Token, +From, +To, +Amount)
%%   ft_approve(+Token, +Owner, +Spender, +Amount)
%%   ft_allowance(+Token, +Owner, +Spender, -Amount)
%%   ft_transfer_from(+Token, +Spender, +From, +To, +Amount)
%%   ft_holders(+Token, -Holders)         ft_conservation(+Token)
%%
%% THE INVARIANT IS CONSERVATION, and it is the whole of what a token
%% promises: the balances sum to the supply, always. Every other rule
%% here is in service of it -- a transfer subtracts exactly what it adds,
%% a mint raises both sides, a burn lowers both. `ft_conservation/1' is
%% that sentence as a predicate, so it can be checked by someone who does
%% not believe the transfer code, which is the only kind of check worth
%% having. It is not called on every operation, because that would make
%% every transfer cost a walk of every holder; it is there for the suite,
%% for an auditor, and for a node that wants to prove a token before
%% trusting it.
%%
%% AMOUNTS ARE u256, the type money is written in here -- 256 bits,
%% raising rather than wrapping. That is not decoration: a token's whole
%% job is arithmetic on balances, and cocolog's own 64-bit integers wrap
%% in silence at ordinary token scale (one token is 10^18). A balance
%% that wrapped would be a lie that spends.
%%
%% WHAT ERC-20 GOT WRONG AND THIS DOES NOT REPEAT. The standard's
%% `approve' has a known race: changing an allowance from one non-zero
%% value to another lets a watching spender use the OLD allowance and
%% then the new one, taking both. The usual advice is to set it to zero
%% first, which is advice rather than a rule. Here `ft_approve/4'
%% REFUSES to overwrite a non-zero allowance with another non-zero one:
%% the caller must zero it first, and the race has nowhere to live. That
%% is a deliberate divergence from the standard, and it is the only one.
%%
%% WHAT IS NOT HERE: the transfer hooks of ERC-777, the batch operations
%% of ERC-1155, and any notion of a token contract calling back into
%% another. Those are additions to this, not corrections of it.

:- use_module(library(u256)).
:- use_module(library(lists)).

:- dynamic ft_token/3.          % ft_token(Token, Symbol, Decimals)
:- dynamic ft_bal/3.            % ft_bal(Token, Who, Amount)
:- dynamic ft_supply/2.         % ft_supply(Token, Total)
:- dynamic ft_allow/4.          % ft_allow(Token, Owner, Spender, Amount)

%% ---- the token -------------------------------------------------------

ft_create(Token, Symbol, Decimals) :-
    ground(Token),
    \+ ft_token(Token, _, _),
    integer(Decimals), Decimals >= 0, Decimals =< 77,
    assertz(ft_token(Token, Symbol, Decimals)),
    assertz(ft_supply(Token, '0')).

ft_total(Token, Total) :- ft_supply(Token, Total).

%% A balance nobody has ever held is zero, not missing -- the same
%% answer ERC-20 gives, and the one that keeps callers from having to
%% know whether an account has been seen before.
ft_balance(Token, Who, Amount) :-
    ft_token(Token, _, _),
    (   ft_bal(Token, Who, A) -> Amount = A ; Amount = '0' ).

ft_set_balance(Token, Who, Amount) :-
    (   retract(ft_bal(Token, Who, _)) -> true ; true ),
    assertz(ft_bal(Token, Who, Amount)).

ft_holders(Token, Holders) :-
    findall(W, ft_bal(Token, W, _), Ws),
    sort(Ws, Holders).

%% ---- supply ----------------------------------------------------------

ft_mint(Token, To, Amount) :-
    ft_token(Token, _, _),
    ground(To),
    u256_cmp(Amount, '0', '>'),
    ft_balance(Token, To, Bal),
    ft_supply(Token, Total),
    %% Both of these raise rather than wrap if they would pass 2^256-1,
    %% so a supply cannot be inflated by going round the top.
    u256_add(Bal, Amount, NewBal),
    u256_add(Total, Amount, NewTotal),
    ft_set_balance(Token, To, NewBal),
    retract(ft_supply(Token, _)),
    assertz(ft_supply(Token, NewTotal)).

ft_burn(Token, From, Amount) :-
    ft_token(Token, _, _),
    u256_cmp(Amount, '0', '>'),
    ft_balance(Token, From, Bal),
    \+ u256_cmp(Amount, Bal, '>'),
    ft_supply(Token, Total),
    u256_sub(Bal, Amount, NewBal),
    u256_sub(Total, Amount, NewTotal),
    ft_set_balance(Token, From, NewBal),
    retract(ft_supply(Token, _)),
    assertz(ft_supply(Token, NewTotal)).

%% ---- moving ----------------------------------------------------------
%%
%% A transfer to yourself is a no-op that must still be WELL FORMED: it
%% is allowed only if you could have afforded it, because a token where
%% `transfer(me, me, more_than_i_have)' succeeds is a token whose
%% balance check can be skipped. The subtraction and addition are done
%% against the same starting balance, so self-transfer leaves it exactly
%% where it was rather than doubling it -- the classic bug in this
%% function, and the reason it is written with an explicit case.
ft_transfer(Token, From, To, Amount) :-
    ft_token(Token, _, _),
    ground(From), ground(To),
    u256_cmp(Amount, '0', '>'),
    ft_balance(Token, From, FromBal),
    \+ u256_cmp(Amount, FromBal, '>'),
    (   From == To
    ->  true
    ;   ft_balance(Token, To, ToBal),
        u256_sub(FromBal, Amount, NewFrom),
        u256_add(ToBal, Amount, NewTo),
        ft_set_balance(Token, From, NewFrom),
        ft_set_balance(Token, To, NewTo)
    ).

%% ---- allowances ------------------------------------------------------
%%
%% See the header: overwriting a non-zero allowance with another
%% non-zero one is REFUSED, because that is where ERC-20's approve race
%% lives. Zero it first and the race has nowhere to be.
ft_approve(Token, Owner, Spender, Amount) :-
    ft_token(Token, _, _),
    ground(Owner), ground(Spender),
    ft_allowance(Token, Owner, Spender, Old),
    (   u256_cmp(Old, '0', '=')
    ->  true
    ;   u256_cmp(Amount, '0', '=')
    ),
    (   retract(ft_allow(Token, Owner, Spender, _)) -> true ; true ),
    u256_dec(Amount, Canonical),
    assertz(ft_allow(Token, Owner, Spender, Canonical)).

ft_allowance(Token, Owner, Spender, Amount) :-
    ft_token(Token, _, _),
    (   ft_allow(Token, Owner, Spender, A) -> Amount = A ; Amount = '0' ).

%% Spending someone else's, which is two rules and not one: the
%% allowance must cover it AND the balance must cover it, and the
%% allowance comes DOWN by what was spent. An allowance that survived
%% its own use would be a standing order, not a permission.
ft_transfer_from(Token, Spender, From, To, Amount) :-
    ft_allowance(Token, From, Spender, Allowed),
    \+ u256_cmp(Amount, Allowed, '>'),
    ft_transfer(Token, From, To, Amount),
    u256_sub(Allowed, Amount, Left),
    (   retract(ft_allow(Token, From, Spender, _)) -> true ; true ),
    assertz(ft_allow(Token, From, Spender, Left)).

%% ---- the invariant, as a predicate -----------------------------------
%%
%% The balances sum to the supply. Anyone can run this; nothing in the
%% token needs it to be true for its own code to work, which is exactly
%% why it is worth checking.
ft_conservation(Token) :-
    ft_supply(Token, Total),
    findall(A, ft_bal(Token, _, A), Amounts),
    ft_sum(Amounts, '0', Sum),
    u256_cmp(Sum, Total, '=').

ft_sum([], Acc, Acc).
ft_sum([A|T], Acc, Sum) :-
    u256_add(Acc, A, Acc2),
    ft_sum(T, Acc2, Sum).
