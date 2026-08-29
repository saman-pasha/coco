%% The two standards, as contracts on this chain: ERC-20's shape and
%% ERC-721's, and the thefts each one's rules exist to stop.
%%
%% WHAT IS ACTUALLY BEING CHECKED. Not that the predicates answer -- that
%% they answer the way the standards require WHEN SOMEBODY IS TRYING IT
%% ON. Every "refused" line below is a theft that works against a naive
%% implementation:
%%
%%   THE SELF-TRANSFER MINT. Written as subtract-then-add against a
%%   re-read balance, `transfer(alice, alice, X)' credits alice twice and
%%   makes money out of nothing. It must be a no-op -- and it must still
%%   have been affordable, or the no-op becomes a way to skip the check.
%%
%%   THE APPROVE RACE. Overwriting a live allowance lets a spender who is
%%   watching spend the old one and the new one. Non-zero over non-zero
%%   is refused outright; zeroing first is the way.
%%
%%   THE TAKE-BACK. bob is approved for a token, buys it, sells it on --
%%   and must not be able to reclaim it with the approval he was given
%%   before. A per-token approval clears on transfer; an OPERATOR
%%   approval, which is about the owner rather than the token, does not.
%%
%% CONSERVATION IS CHECKED AFTER EVERY KIND OF MOVE, because a balance
%% sheet that only balances at rest is not one.
%%
%% EVERY SCENE IS ITS OWN PROOF. The .sh case got a fresh contract by
%% spawning a cocolog per check -- thirty processes -- and repeated the
%% mint in a shell variable to rebuild the state each time. iso/2 gives
%% each scene a fresh machine and a fresh store, so `mk/0' below is
%% setup rather than a workaround.
%%
%% SKIPs when the contracts will not load (did the u256 module build?).
%%
%% Run:  cocolog -s test/token.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

one('1000000000000000000').
k('1000000000000000000000').
maxid('115792089237316195423570985008687907853269984665640564039457584007913129639935').

%% a token, and alice holding a thousand of it
mk :- k(K), ft_create(dai, 'DAI', 18), ft_mint(dai, alice, K).
%% a collection, and alice holding token 1
nmk :- nft_create(punks, 'Punks'), nft_mint(punks, alice, '1').

main :-
    (   catch(( use_module('contracts/token/fungible.pl'),
                use_module('contracts/token/nonfungible.pl') ), _, fail)
    ->  checks
    ;   skip('(the token contracts will not load -- did the u256 module build?)')
    ).

checks :-
    one(ONE), k(K), maxid(MAXID),

    section('fungible'),
    iso('a fresh balance is zero, not missing',
        ( ft_create(dai, 'DAI', 18), ft_balance(dai, nobody, B), want(B, '0') )),
    iso('minting raises the balance',
        ( mk, ft_balance(dai, alice, B), want(B, K) )),
    iso('and the supply with it', ( mk, ft_total(dai, T), want(T, K) )),
    iso('conservation holds after minting', ( mk, ft_conservation(dai) )),
    iso('a transfer moves exactly what it says',
        ( mk, ft_transfer(dai, alice, bob, ONE), ft_balance(dai, bob, B), want(B, ONE) )),
    iso('and takes it from the sender',
        ( mk, ft_transfer(dai, alice, bob, ONE), ft_balance(dai, alice, B),
          want(B, '999000000000000000000') )),
    iso('conservation holds after a transfer',
        ( mk, ft_transfer(dai, alice, bob, ONE), ft_conservation(dai) )),
    iso('spending more than you have is refused',
        ( mk, refuses(ft_transfer(dai, alice, bob, '99999999999999999999999999')) )),
    %% THE CLASSIC BUG: a self-transfer written as subtract-then-add
    %% against a re-read balance MINTS money.
    iso('a self-transfer is a no-op, not a mint',
        ( mk, ft_transfer(dai, alice, alice, ONE), ft_balance(dai, alice, B), want(B, K) )),
    iso('and an unaffordable self-transfer is still refused',
        ( mk, refuses(ft_transfer(dai, alice, alice, '99999999999999999999999999')) )),
    iso('burning lowers balance and supply together',
        ( mk, ft_burn(dai, alice, ONE), ft_total(dai, T),
          want(T, '999000000000000000000') )),
    iso('burning more than held is refused',
        ( mk, refuses(ft_burn(dai, alice, '99999999999999999999999999')) )),

    section('allowances'),
    iso('an allowance starts at zero',
        ( mk, ft_allowance(dai, alice, bob, A), want(A, '0') )),
    iso('transfer_from spends it',
        ( mk, ft_approve(dai, alice, bob, ONE),
          ft_transfer_from(dai, bob, alice, carol, ONE),
          ft_balance(dai, carol, B), want(B, ONE) )),
    iso('and the allowance comes down by what was spent',
        ( mk, ft_approve(dai, alice, bob, K),
          ft_transfer_from(dai, bob, alice, carol, ONE),
          ft_allowance(dai, alice, bob, A), want(A, '999000000000000000000') )),
    iso('spending past the allowance is refused',
        ( mk, ft_approve(dai, alice, bob, ONE),
          refuses(ft_transfer_from(dai, bob, alice, carol, K)) )),
    iso('spending with no allowance is refused',
        ( mk, refuses(ft_transfer_from(dai, bob, alice, carol, ONE)) )),
    %% THE APPROVE RACE, closed: non-zero over non-zero is refused.
    iso('overwriting a live allowance is REFUSED (the approve race)',
        ( mk, ft_approve(dai, alice, bob, ONE),
          refuses(ft_approve(dai, alice, bob, K)) )),
    iso('zeroing it first is the way, and works',
        ( mk, ft_approve(dai, alice, bob, ONE), ft_approve(dai, alice, bob, '0'),
          ft_approve(dai, alice, bob, K), ft_allowance(dai, alice, bob, A),
          want(A, K) )),

    section('non-fungible'),
    iso('the minter owns it', ( nmk, nft_owner(punks, '1', O), want(O, alice) )),
    iso('and the balance counts it',
        ( nmk, nft_balance(punks, alice, B), want(B, '1') )),
    iso('minting the same id twice is refused',
        ( nmk, refuses(nft_mint(punks, bob, '1')) )),
    iso('a huge id is fine -- ids are u256',
        ( nft_create(punks, 'Punks'), nft_mint(punks, alice, MAXID),
          nft_owner(punks, MAXID, O), want(O, alice) )),
    iso('the owner can move it',
        ( nmk, nft_transfer_from(punks, alice, alice, bob, '1'),
          nft_owner(punks, '1', O), want(O, bob) )),
    iso('a stranger cannot',
        ( nmk, refuses(nft_transfer_from(punks, mallory, alice, mallory, '1')) )),
    iso('an approved spender can',
        ( nmk, nft_approve(punks, alice, bob, '1'),
          nft_transfer_from(punks, bob, alice, bob, '1'),
          nft_owner(punks, '1', O), want(O, bob) )),
    iso("an operator can move any of the owner's",
        ( nmk, nft_mint(punks, alice, '2'), nft_set_operator(punks, alice, market, on),
          nft_transfer_from(punks, market, alice, bob, '2'),
          nft_owner(punks, '2', O), want(O, bob) )),
    iso('and cannot once the operator is switched off',
        ( nmk, nft_set_operator(punks, alice, market, on),
          nft_set_operator(punks, alice, market, off),
          refuses(nft_transfer_from(punks, market, alice, bob, '1')) )),
    %% THE TAKE-BACK: bob is approved, buys, sells on, and must not be
    %% able to reclaim it with the approval he was given before.
    iso('an approval does not survive the transfer (the take-back)',
        ( nmk, nft_approve(punks, alice, bob, '1'),
          nft_transfer_from(punks, bob, alice, carol, '1'),
          refuses(nft_transfer_from(punks, bob, carol, bob, '1')) )),
    iso('but an operator approval does survive it',
        ( nmk, nft_mint(punks, alice, '2'), nft_set_operator(punks, alice, market, on),
          nft_transfer_from(punks, market, alice, bob, '1'),
          nft_transfer_from(punks, market, alice, bob, '2'),
          nft_owner(punks, '2', O), want(O, bob) )),
    iso('burning removes it',
        ( nmk, nft_burn(punks, '1'), refuses(nft_owner(punks, '1', _)) )),
    iso('the counts agree with the tokens actually held',
        ( nmk, nft_mint(punks, alice, '2'), nft_mint(punks, bob, '3'),
          nft_transfer_from(punks, alice, alice, bob, '1'),
          nft_conservation(punks) )),

    nl, checks_done.
