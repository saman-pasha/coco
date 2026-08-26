%% contracts/dex/uniswap-v3 -- concentrated liquidity, and positions that
%% are non-fungible tokens.
%%
%%   v3_create(+Pool, +Token0, +Token1, +FeePips, +Tick)
%%   v3_state(+Pool, -SqrtPriceX96, -Tick, -Liquidity)
%%   v3_mint(+Pool, +Owner, +Lower, +Upper, +Liquidity, -Id, -Amount0, -Amount1)
%%   v3_position(+Id, -Pool, -Owner, -Lower, -Upper, -Liquidity)
%%   v3_burn(+Pool, +Caller, +Id, -Amount0, -Amount1)
%%   v3_quote(+Pool, +TokenIn, +AmountIn, -AmountOut, -NextSqrt)
%%   v3_swap(+Pool, +TokenIn, +AmountIn, -AmountOut)
%%   v3_in_range(+Id)
%%
%% WHAT v3 CHANGED, in one sentence: a v2 position is spread from zero to
%% infinity, and almost all of it is never used. If a pair trades between
%% 0.99 and 1.01 forever, the liquidity a v2 pool holds against a price
%% of 4000 is doing nothing but sitting there. v3 lets a provider name a
%% RANGE -- two ticks -- and put the whole of their capital inside it. The
%% same money is then many times deeper where the trading actually is,
%% which is the entire point and also the entire risk: outside the range
%% the position is idle and one-sided.
%%
%% WHICH IS WHY A POSITION IS AN NFT. In v2 every provider in a pool owns
%% the same thing, so a share is a fungible token and a balance is
%% enough. In v3 two providers in the same pool own DIFFERENT things --
%% different ranges, different fee exposure -- so a position cannot be a
%% balance. It is an object with an identity, which is what
%% contracts/token/nonfungible.pl is for, and this contract mints one per
%% position exactly as Uniswap's own periphery does.
%%
%% THE PRICE IS A SQUARE ROOT IN Q64.96, and the tick arithmetic behind
%% it is library(tickmath) -- see there for why, and for the constants,
%% which are Uniswap's own.
%%
%% WHAT THIS DOES NOT DO YET, said plainly rather than left to be
%% discovered: A SWAP MAY NOT CROSS A TICK BOUNDARY. Crossing means
%% deactivating one position's liquidity and activating another's
%% mid-swap, tracking each boundary's net liquidity, and splitting the
%% trade into per-range legs. That is the rest of v3's engine and it is
%% not here; a swap that would push the price out of the active range is
%% REFUSED rather than approximated, because a pool that quietly
%% mispriced the far side of a boundary would be worse than one that
%% said no. Fee GROWTH per position (v3's feeGrowthInside accounting) is
%% likewise absent: the fee is taken off the input, and it stays in the
%% pool as liquidity rather than being credited per position.

:- use_module(library(u256)).
:- use_module(library(tickmath)).
:- use_module(library(lists)).

:- dynamic v3_pool/4.           % v3_pool(Pool, Token0, Token1, FeePips)
:- dynamic v3_price/3.          % v3_price(Pool, SqrtPriceX96, Tick)
:- dynamic v3_pos/6.            % v3_pos(Id, Pool, Owner, Lower, Upper, Liquidity)
:- dynamic v3_next_id/2.        % v3_next_id(Pool, N)

%% Uniswap's own fee tiers, in hundredths of a basis point: 0.05%, 0.3%,
%% 1%. A pool outside these is refused, because a fee nobody else uses
%% is a pool nobody else can route through.
v3_fee_tier(500).
v3_fee_tier(3000).
v3_fee_tier(10000).
v3_fee_denominator('1000000').

%% ---- the pool --------------------------------------------------------

v3_create(Pool, Token0, Token1, FeePips, Tick) :-
    ground(Pool), ground(Token0), ground(Token1),
    Token0 @< Token1,                       % the pair is ordered, as in v2
    \+ v3_pool(Pool, _, _, _),
    v3_fee_tier(FeePips),
    tm_sqrt_ratio_at_tick(Tick, Sqrt),
    assertz(v3_pool(Pool, Token0, Token1, FeePips)),
    assertz(v3_price(Pool, Sqrt, Tick)),
    assertz(v3_next_id(Pool, 1)),
    %% the positions of this pool are a collection of their own
    nft_create(Pool, Pool).

v3_state(Pool, Sqrt, Tick, Liquidity) :-
    v3_price(Pool, Sqrt, Tick),
    v3_active_liquidity(Pool, Liquidity).

%% THE LIQUIDITY THAT COUNTS is only what is in range. A position whose
%% range does not contain the current tick contributes nothing to a
%% trade -- that is what concentrating means -- so the depth a swap sees
%% is the sum over the active ones and not the sum over all of them.
v3_active_liquidity(Pool, Total) :-
    v3_price(Pool, _, Tick),
    findall(L, ( v3_pos(_, Pool, _, Lo, Hi, L), Lo =< Tick, Tick < Hi ), Ls),
    v3_sum(Ls, '0', Total).

v3_sum([], Acc, Acc).
v3_sum([X|T], Acc, Sum) :- u256_add(Acc, X, A2), v3_sum(T, A2, Sum).

v3_in_range(Id) :-
    v3_pos(Id, Pool, _, Lo, Hi, _),
    v3_price(Pool, _, Tick),
    Lo =< Tick, Tick < Hi.

%% ---- positions -------------------------------------------------------
%%
%% What a position costs depends on WHERE THE PRICE IS relative to the
%% range, and the three cases are the whole of v3's deposit rule:
%%
%%   price below the range -- the range is entirely "expensive" ground,
%%     so the position is all token0 and no token1;
%%   price above it -- the mirror image: all token1;
%%   price inside it -- both, split at the current price, which is the
%%     only case where a provider deposits a pair.
v3_amounts(Sqrt, Tick, Lower, Upper, Liquidity, Amount0, Amount1) :-
    tm_sqrt_ratio_at_tick(Lower, SqrtLo),
    tm_sqrt_ratio_at_tick(Upper, SqrtHi),
    (   Tick < Lower
    ->  tm_amount0_delta(SqrtLo, SqrtHi, Liquidity, Amount0), Amount1 = '0'
    ;   Tick >= Upper
    ->  Amount0 = '0', tm_amount1_delta(SqrtLo, SqrtHi, Liquidity, Amount1)
    ;   tm_amount0_delta(Sqrt, SqrtHi, Liquidity, Amount0),
        tm_amount1_delta(SqrtLo, Sqrt, Liquidity, Amount1)
    ).

v3_mint(Pool, Owner, Lower, Upper, Liquidity, Id, Amount0, Amount1) :-
    v3_pool(Pool, _, _, _),
    ground(Owner),
    integer(Lower), integer(Upper),
    Lower < Upper,
    tm_min_tick(Min), tm_max_tick(Max),
    Lower >= Min, Upper =< Max,
    u256_cmp(Liquidity, '0', '>'),
    v3_price(Pool, Sqrt, Tick),
    v3_amounts(Sqrt, Tick, Lower, Upper, Liquidity, Amount0, Amount1),
    retract(v3_next_id(Pool, N)),
    N2 is N + 1,
    assertz(v3_next_id(Pool, N2)),
    u256_dec(N, Id),
    %% THE POSITION IS THE TOKEN. Minting the NFT is not bookkeeping
    %% beside the position -- it is how the position comes to exist and
    %% how it is owned, transferred and sold.
    nft_mint(Pool, Owner, Id),
    assertz(v3_pos(Id, Pool, Owner, Lower, Upper, Liquidity)).

v3_position(Id, Pool, Owner, Lower, Upper, Liquidity) :-
    v3_pos(Id, Pool, _, Lower, Upper, Liquidity),
    v3_pos(Id, Pool, _, _, _, _),
    %% the OWNER is the token's owner, not a copy kept here: a position
    %% that changed hands changed hands, and asking the collection is
    %% the only answer that cannot go stale.
    nft_owner(Pool, Id, Owner).

%% Only whoever the NFT says owns it -- or an account it has authorised
%% -- may close a position.
v3_burn(Pool, Caller, Id, Amount0, Amount1) :-
    v3_pos(Id, Pool, _, Lower, Upper, Liquidity),
    nft_may_move(Pool, Caller, Id),
    v3_price(Pool, Sqrt, Tick),
    v3_amounts(Sqrt, Tick, Lower, Upper, Liquidity, Amount0, Amount1),
    retract(v3_pos(Id, Pool, _, _, _, _)),
    nft_burn(Pool, Id).

%% ---- swapping --------------------------------------------------------
%%
%% The fee comes off the input first, exactly as v3 takes it, and what
%% is left moves the price. Then:
%%
%%   token1 in, price UP:   sqrtP' = sqrtP + amountIn * Q96 / L
%%   token0 in, price DOWN: sqrtP' = (L * Q96 * sqrtP) / (L * Q96 + amountIn * sqrtP)
%%
%% Both are exact rearrangements of the same curve, and the second is
%% written with u256_muldiv/4 because L*Q96*sqrtP is a 512-bit number
%% whose quotient is an ordinary price.
v3_quote(Pool, TokenIn, AmountIn, AmountOut, Next) :-
    v3_pool(Pool, Token0, Token1, FeePips),
    u256_cmp(AmountIn, '0', '>'),
    v3_price(Pool, Sqrt, _),
    v3_active_liquidity(Pool, L),
    u256_cmp(L, '0', '>'),
    v3_fee_denominator(Denom),
    u256_dec(FeePips, Fee),
    u256_sub(Denom, Fee, Kept),
    u256_muldiv(AmountIn, Kept, Denom, Net),
    u256_cmp(Net, '0', '>'),
    tm_q96(Q96),
    (   TokenIn == Token1
    ->  u256_muldiv(Net, Q96, L, Delta),
        u256_add(Sqrt, Delta, Next),
        tm_amount0_delta(Sqrt, Next, L, AmountOut)
    ;   TokenIn == Token0
    ->  u256_mul(L, Q96, N1),
        u256_mul(Net, Sqrt, Product),
        u256_add(N1, Product, Denominator),
        u256_muldiv(N1, Sqrt, Denominator, Next),
        tm_amount1_delta(Next, Sqrt, L, AmountOut)
    ),
    u256_cmp(AmountOut, '0', '>').

%% A swap moves the price, and the price MAY NOT LEAVE THE ACTIVE RANGE
%% -- see the header. The check is against the ends of every position
%% that is currently in range: if the new price would pass any of them,
%% liquidity would change mid-swap and this engine does not yet split
%% the trade. Refused, loudly, rather than mispriced quietly.
v3_swap(Pool, TokenIn, AmountIn, AmountOut) :-
    v3_quote(Pool, TokenIn, AmountIn, AmountOut, Next),
    v3_price(Pool, _, Tick),
    v3_within_active(Pool, Tick, Next),
    v3_tick_of(Pool, Next, NextTick),
    retract(v3_price(Pool, _, _)),
    assertz(v3_price(Pool, Next, NextTick)).

v3_within_active(Pool, Tick, Next) :-
    findall(Lo-Hi, ( v3_pos(_, Pool, _, Lo, Hi, _), Lo =< Tick, Tick < Hi ), Ranges),
    Ranges \== [],
    v3_inside_all(Ranges, Next).

v3_inside_all([], _).
v3_inside_all([Lo-Hi|T], Next) :-
    tm_sqrt_ratio_at_tick(Lo, SqrtLo),
    tm_sqrt_ratio_at_tick(Hi, SqrtHi),
    \+ u256_cmp(Next, SqrtLo, '<'),
    \+ u256_cmp(Next, SqrtHi, '>'),
    v3_inside_all(T, Next).

%% The tick a price sits in, found by walking the ends of the ranges
%% this pool actually has. A full engine keeps a bitmap of initialised
%% ticks and binary-searches it; with no tick crossing yet, the ends of
%% the live positions are the only boundaries that matter, and asking
%% them is honest about what is implemented.
v3_tick_of(Pool, Sqrt, Tick) :-
    findall(T, ( v3_pos(_, Pool, _, Lo, Hi, _), ( T = Lo ; T = Hi ) ), Ts0),
    sort(Ts0, Ts),
    v3_price(Pool, _, Current),
    v3_highest_below(Ts, Sqrt, Current, Tick).

v3_highest_below([], _, Acc, Acc).
v3_highest_below([T|Rest], Sqrt, Acc, Tick) :-
    tm_sqrt_ratio_at_tick(T, S),
    (   \+ u256_cmp(S, Sqrt, '>')
    ->  v3_highest_below(Rest, Sqrt, T, Tick)
    ;   v3_highest_below(Rest, Sqrt, Acc, Tick)
    ).
