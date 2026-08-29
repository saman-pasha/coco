%% Uniswap v2 as a contract on this chain: constant-product pools, the
%% quote, and the invariant that is the only thing a pool really
%% promises.
%%
%% THE NUMBER IS NOT THIS REPOSITORY'S. 996006981039903216 is what the
%% constant-product formula with a 0.3% fee pays for one token into a
%% 1000/1000 pool, and it is quoted wherever the formula is explained.
%% The first check is the reason there is a u256 at all: cocolog's own
%% 64-bit `is/2', asked for the first product a swap computes, answers a
%% number that is simply not it -- and a pool priced that way would be
%% confidently wrong with its own checks agreeing.
%%
%% AND THE TOKENS ARE REAL, which is the second half and the one an AMM
%% written as arithmetic quietly skips. A deposit LEAVES the provider, the
%% pool HOLDS it, the LP share is a token the provider can be shown to
%% hold, the burned minimum sits where nobody can reach it, and a swap
%% pays the trader in tokens somebody actually had. `uni_backed/2' is the
%% predicate that says the pool holds what it promised; a donation leaves
%% it backed but out of step, and skim and sync are the two honest
%% answers to that.
%%
%% EVERY SCENE IS ITS OWN PROOF. The .sh rebuilt the whole pool in a shell
%% variable for each of twenty-eight checks and spawned a cocolog to run
%% it; `mint/1' below is setup, and iso/2 is what makes it enough.
%%
%% SKIPs when the contracts will not load (did the u256 module build?).
%%
%% Run:  cocolog -s test/uniswap.pl   from coco/ -- the exit code is the
%%       verdict: 0 exactly when main proved.

:- use_module('test/prelude.pl').

one('1000000000000000000').           %% one token, 18 decimals
pool('1000000000000000000000').       %% a thousand of them
quote('996006981039903216').          %% what one token buys, at 0.3%
rich('1000000000000000000000000').    %% what alice and bob start with

%% two tokens, and two people holding a million of each
toks :- rich(M),
        ft_create(dai, 'DAI', 18), ft_create(weth, 'WETH', 18),
        ft_mint(dai, alice, M), ft_mint(weth, alice, M),
        ft_mint(dai, bob, M), ft_mint(weth, bob, M).

%% ... and a pool with a thousand of each in it
mint(L) :- pool(P), toks, uni_create(dai, weth), uni_mint(dai, weth, alice, P, P, L).

main :-
    (   catch(( use_module('contracts/token/fungible.pl'),
                use_module('contracts/dex/uniswap.pl') ), _, fail)
    ->  checks
    ;   skip('(contracts/dex/uniswap.pl will not load -- did the u256 module build?)')
    ).

checks :-
    one(ONE), pool(POOL), quote(QUOTE), rich(M),

    section('the quote, and why it needs a wide integer'),
    iso("cocolog's 64-bit is/2 would get it wrong",
        ( X is 1000000000000000000 * 997, want(X, 875820019684212736) )),
    iso('one token into a 1000/1000 pool',
        ( uni_amount_out(ONE, POOL, POOL, X), want(X, QUOTE) )),
    iso('and the inverse returns the input',
        ( uni_amount_in(QUOTE, POOL, POOL, X), want(X, ONE) )),
    iso('a bigger pool moves the price less',
        ( uni_amount_out(ONE, '10000000000000000000000',
                         '10000000000000000000000', X),
          u256_cmp(X, QUOTE, C), want(C, >) )),

    section('minting a share of a pool'),
    iso('the first deposit mints sqrt(a0*a1) - 1000',
        ( mint(L), want(L, '999999999999999999000') )),
    iso('and the burned thousand is in the supply',
        ( mint(_), uni_supply(dai, weth, T), want(T, '1000000000000000000000') )),
    iso('a second, in ratio, mints its share',
        ( mint(_), uni_mint(dai, weth, alice, POOL, POOL, L2),
          want(L2, '1000000000000000000000') )),
    iso('off-ratio mints the SMALLER share',
        ( mint(_), sh_join([POOL, '0'], BIG),
          uni_mint(dai, weth, alice, POOL, BIG, L2),
          want(L2, '1000000000000000000000') )),

    section('swapping, and the invariant'),
    iso('k grows across a swap -- that is the fee',
        ( mint(_), uni_k(dai, weth, K0), uni_swap(dai, weth, bob, ONE, _),
          uni_k(dai, weth, K1), u256_cmp(K1, K0, C), want(C, >) )),
    iso('the swap pays the quoted amount',
        ( mint(_), uni_swap(dai, weth, bob, ONE, Out), want(Out, QUOTE) )),
    iso('the pair is unordered: same pool either way',
        ( toks, uni_create(dai, weth), uni_mint(weth, dai, alice, POOL, POOL, _),
          uni_reserves(dai, weth, R0, _), want(R0, POOL) )),

    section('mallory at the pool'),
    %% SHE IS ALLOWED TO TRY, and the constant product is what stops her:
    %% a swap of a million against a thousand does not drain it, it just
    %% pays terribly. The check is not that she is refused -- it is that
    %% what she got is less than the reserve.
    iso('mallory cannot drain the pool in one swap',
        ( mint(_), uni_swap(dai, weth, bob, M, _) )),
    iso('and what she got was still less than the reserve',
        ( mint(_), uni_swap(dai, weth, bob, M, Out),
          u256_cmp(Out, POOL, C), want(C, <) )),
    iso('a swap on a pool that does not exist fails',
        ( refuses(uni_swap(nosuch, token, bob, ONE, _)) )),
    iso('a zero swap is not a swap',
        ( mint(_), refuses(uni_swap(dai, weth, bob, '0', _)) )),
    iso('burning more than exists is refused',
        ( mint(_),
          refuses(uni_burn(dai, weth, alice, '99999999999999999999999999', _, _)) )),
    iso('a mint and burn round trip does not profit',
        ( mint(L), uni_burn(dai, weth, alice, L, O0, _),
          u256_cmp(O0, POOL, C), want(C, <) )),
    iso('and the pool keeps the minimum liquidity',
        ( mint(L), uni_burn(dai, weth, alice, L, _, _),
          uni_supply(dai, weth, T), want(T, '1000') )),

    section('and the tokens are real'),
    iso('the deposit actually leaves the provider',
        ( mint(_), ft_balance(dai, alice, B), u256_sub(M, B, D), want(D, POOL) )),
    iso('and the pool actually holds it',
        ( mint(_), uni_balances(dai, weth, B0, _), want(B0, POOL) )),
    iso('the LP share is a token the provider holds',
        ( mint(_), uni_lp_token(dai, weth, Lp), ft_balance(Lp, alice, B),
          want(B, '999999999999999999000') )),
    iso('and the burned minimum sits where nobody can reach it',
        ( mint(_), uni_lp_token(dai, weth, Lp), ft_balance(Lp, zero, B),
          want(B, '1000') )),
    iso('a swap pays the trader in actual tokens',
        ( mint(_), uni_swap(weth, dai, bob, ONE, _), ft_balance(dai, bob, B),
          u256_sub(B, M, D), want(D, QUOTE) )),
    iso('a swap nobody can fund is refused',
        ( mint(_), refuses(uni_swap(weth, dai, carol, ONE, _)) )),
    iso('the pool is backed: it holds what it promised',
        ( mint(_), uni_swap(weth, dai, bob, ONE, _), uni_backed(dai, weth) )),
    iso('a donation leaves the pool backed but out of step',
        ( mint(_), uni_account(dai, weth, Acct), ft_transfer(dai, bob, Acct, ONE),
          uni_reserves(dai, weth, R0, _), uni_balances(dai, weth, B0, _),
          u256_sub(B0, R0, D), want(D, ONE) )),
    iso('skim hands the difference to whoever asks',
        ( mint(_), uni_account(dai, weth, Acct), ft_transfer(dai, bob, Acct, ONE),
          uni_skim(dai, weth, carol), ft_balance(dai, carol, B), want(B, ONE) )),
    iso('sync believes the balances instead',
        ( mint(_), uni_account(dai, weth, Acct), ft_transfer(dai, bob, Acct, ONE),
          uni_sync(dai, weth), uni_reserves(dai, weth, R0, _),
          want(R0, '1001000000000000000000') )),

    nl, checks_done.
